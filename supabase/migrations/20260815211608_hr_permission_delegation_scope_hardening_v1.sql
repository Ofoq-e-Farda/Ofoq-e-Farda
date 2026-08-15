-- ============================================================
-- Ofoq ERP
-- HR RBAC V1 - Permission Delegation Scope Hardening
-- ============================================================
-- Hardens delegate_permission_v1() against:
--   1. permission-scope rule violations
--   2. scope escalation
--   3. explicit permission-scope bypass
--   4. role / permission-scope validity overflow
--   5. department / branch mismatch
-- ============================================================

CREATE OR REPLACE FUNCTION public.delegate_permission_v1(
    p_delegatee_profile_id uuid,
    p_permission_code text,
    p_branch_id uuid DEFAULT NULL,
    p_department_id uuid DEFAULT NULL,
    p_starts_at timestamptz DEFAULT now(),
    p_ends_at timestamptz DEFAULT NULL,
    p_reason text DEFAULT NULL,
    p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor_profile_id uuid;
    v_permission_id uuid;
    v_delegation_id uuid;

    v_requested_scope_type text;
    v_department_branch_id uuid;

    v_permission_owned boolean := false;
BEGIN
    -- --------------------------------------------------------
    -- 1. Authenticated caller
    -- --------------------------------------------------------

    v_actor_profile_id := auth.uid();

    IF v_actor_profile_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;


    -- --------------------------------------------------------
    -- 2. Prevent self-delegation
    -- --------------------------------------------------------

    IF p_delegatee_profile_id = v_actor_profile_id THEN
        RAISE EXCEPTION
            'A permission cannot be delegated to yourself';
    END IF;


    -- --------------------------------------------------------
    -- 3. Validate dates
    -- --------------------------------------------------------

    IF p_starts_at IS NULL THEN
        RAISE EXCEPTION 'starts_at is required';
    END IF;

    IF p_ends_at IS NOT NULL
       AND p_ends_at <= p_starts_at THEN
        RAISE EXCEPTION
            'ends_at must be later than starts_at';
    END IF;


    -- --------------------------------------------------------
    -- 4. Validate profiles
    -- --------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles pr
        WHERE pr.id = v_actor_profile_id
          AND pr.is_active = true
          AND pr.suspended_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'Delegator profile is inactive or suspended';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles pr
        WHERE pr.id = p_delegatee_profile_id
          AND pr.is_active = true
          AND pr.suspended_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'Delegatee profile is inactive or suspended';
    END IF;


    -- --------------------------------------------------------
    -- 5. Resolve active permission
    -- --------------------------------------------------------

    SELECT p.id
    INTO v_permission_id
    FROM public.permissions p
    WHERE p.code = p_permission_code
      AND p.is_active = true;

    IF v_permission_id IS NULL THEN
        RAISE EXCEPTION
            'Permission does not exist or is inactive: %',
            p_permission_code;
    END IF;


    -- --------------------------------------------------------
    -- 6. Sensitive permissions require approval workflow
    -- --------------------------------------------------------

    IF p_permission_code = ANY (
        ARRAY[
            'security.user_roles.assign',
            'security.user_roles.revoke',
            'security.user_roles.approve_sensitive',
            'payroll.payroll.approve',
            'payroll.payroll.mark_paid',
            'payroll.payroll.cancel',
            'organization.settings.manage'
        ]::text[]
    ) THEN
        RAISE EXCEPTION
            'Sensitive permission requires approval workflow: %',
            p_permission_code;
    END IF;


    -- --------------------------------------------------------
    -- 7. Resolve requested organizational scope
    -- --------------------------------------------------------

    IF p_department_id IS NOT NULL THEN
        v_requested_scope_type := 'department';

        SELECT d.branch_id
        INTO v_department_branch_id
        FROM public.departments d
        WHERE d.id = p_department_id
          AND d.is_active = true;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Department does not exist or is inactive';
        END IF;

        -- If caller supplied branch_id together with department_id,
        -- they must describe the same organizational hierarchy.
        IF p_branch_id IS NOT NULL
           AND v_department_branch_id IS DISTINCT FROM p_branch_id THEN
            RAISE EXCEPTION
                'Department does not belong to the requested branch';
        END IF;

    ELSIF p_branch_id IS NOT NULL THEN
        v_requested_scope_type := 'branch';

        IF NOT EXISTS (
            SELECT 1
            FROM public.branches b
            WHERE b.id = p_branch_id
              AND b.status = 'active'
        ) THEN
            RAISE EXCEPTION
                'Branch does not exist or is inactive';
        END IF;

    ELSE
        v_requested_scope_type := 'company';
    END IF;


    -- --------------------------------------------------------
    -- 8. Permission must allow this type of scope
    -- --------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM public.permission_scope_rules psr
        WHERE psr.permission_id = v_permission_id
          AND psr.scope_type = v_requested_scope_type
    ) THEN
        RAISE EXCEPTION
            'Scope type % is not allowed for permission %',
            v_requested_scope_type,
            p_permission_code;
    END IF;


    -- --------------------------------------------------------
    -- 9. Verify effective ownership of permission
    --
    -- Rule:
    --   If explicit permission scopes exist for a user-role /
    --   permission pair, ONLY those explicit scopes apply.
    --
    --   If no explicit permission scope exists, inherit the
    --   organizational scope of user_roles for compatibility.
    -- --------------------------------------------------------

    SELECT EXISTS (
        SELECT 1
        FROM public.user_roles ur

        JOIN public.roles r
          ON r.id = ur.role_id
         AND r.is_active = true

        JOIN public.role_permissions rp
          ON rp.role_id = ur.role_id
         AND rp.permission_id = v_permission_id
         AND rp.granted = true

        WHERE ur.profile_id = v_actor_profile_id
          AND ur.is_active = true

          -- Delegator must currently hold the role.
          AND ur.starts_at <= now()
          AND (
                ur.ends_at IS NULL
                OR ur.ends_at > now()
              )

          -- Delegation cannot begin before role validity.
          AND p_starts_at >= ur.starts_at

          -- Delegation cannot outlive role assignment.
          AND (
                ur.ends_at IS NULL
                OR (
                    p_ends_at IS NOT NULL
                    AND p_ends_at <= ur.ends_at
                )
              )

          AND (
              -- =================================================
              -- A. Explicit permission scopes exist:
              --    requested scope must fit at least one of them.
              -- =================================================
              (
                  EXISTS (
                      SELECT 1
                      FROM public.user_role_permission_scopes x
                      WHERE x.user_role_id = ur.id
                        AND x.permission_id = v_permission_id
                        AND x.is_active = true
                  )

                  AND EXISTS (
                      SELECT 1
                      FROM public.user_role_permission_scopes ups
                      WHERE ups.user_role_id = ur.id
                        AND ups.permission_id = v_permission_id
                        AND ups.is_active = true

                        -- Explicit scope must currently be valid.
                        AND ups.starts_at <= now()
                        AND (
                              ups.ends_at IS NULL
                              OR ups.ends_at > now()
                            )

                        -- Requested delegation must stay inside
                        -- explicit permission validity.
                        AND p_starts_at >= ups.starts_at
                        AND (
                              ups.ends_at IS NULL
                              OR (
                                  p_ends_at IS NOT NULL
                                  AND p_ends_at <= ups.ends_at
                              )
                            )

                        -- Requested organizational scope must be
                        -- equal to or narrower than explicit scope.
                        AND (
                            -- Explicit COMPANY:
                            ups.scope_type = 'company'

                            OR

                            -- Explicit BRANCH:
                            (
                                ups.scope_type = 'branch'
                                AND (
                                    (
                                        v_requested_scope_type = 'branch'
                                        AND p_branch_id = ups.branch_id
                                    )
                                    OR
                                    (
                                        v_requested_scope_type = 'department'
                                        AND v_department_branch_id = ups.branch_id
                                    )
                                )
                            )

                            OR

                            -- Explicit DEPARTMENT:
                            (
                                ups.scope_type = 'department'
                                AND v_requested_scope_type = 'department'
                                AND p_department_id = ups.department_id
                            )
                        )
                  )
              )

              OR

              -- =================================================
              -- B. No explicit permission scopes:
              --    inherit organizational scope from user_roles.
              -- =================================================
              (
                  NOT EXISTS (
                      SELECT 1
                      FROM public.user_role_permission_scopes x
                      WHERE x.user_role_id = ur.id
                        AND x.permission_id = v_permission_id
                        AND x.is_active = true
                  )

                  AND (
                      -- Department-scoped role
                      (
                          ur.department_id IS NOT NULL
                          AND v_requested_scope_type = 'department'
                          AND p_department_id = ur.department_id
                      )

                      OR

                      -- Branch-scoped role
                      (
                          ur.department_id IS NULL
                          AND ur.branch_id IS NOT NULL
                          AND (
                              (
                                  v_requested_scope_type = 'branch'
                                  AND p_branch_id = ur.branch_id
                              )
                              OR
                              (
                                  v_requested_scope_type = 'department'
                                  AND v_department_branch_id = ur.branch_id
                              )
                          )
                      )

                      OR

                      -- Company-scoped role
                      (
                          ur.department_id IS NULL
                          AND ur.branch_id IS NULL
                      )
                  )
              )
          )
    )
    INTO v_permission_owned;


    IF v_permission_owned IS NOT TRUE THEN
        RAISE EXCEPTION
            'You do not own this permission in the requested scope or validity period';
    END IF;


    -- --------------------------------------------------------
    -- 10. Do not bypass own permission suspension
    --
    -- Company-level suspension blocks every scope.
    -- Branch suspension blocks that branch and its departments.
    -- Department suspension blocks that department.
    -- --------------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM public.permission_suspensions ps
        WHERE ps.profile_id = v_actor_profile_id
          AND ps.permission_id = v_permission_id
          AND ps.is_active = true
          AND ps.revoked_at IS NULL
          AND ps.starts_at <= now()
          AND (
                ps.ends_at IS NULL
                OR ps.ends_at > now()
              )
          AND (
              -- Company-wide suspension
              (
                  ps.branch_id IS NULL
                  AND ps.department_id IS NULL
              )

              OR

              -- Department suspension
              (
                  ps.department_id IS NOT NULL
                  AND v_requested_scope_type = 'department'
                  AND ps.department_id = p_department_id
              )

              OR

              -- Branch suspension
              (
                  ps.department_id IS NULL
                  AND ps.branch_id IS NOT NULL
                  AND (
                      (
                          v_requested_scope_type = 'branch'
                          AND ps.branch_id = p_branch_id
                      )
                      OR
                      (
                          v_requested_scope_type = 'department'
                          AND ps.branch_id = v_department_branch_id
                      )
                  )
              )
          )
    ) THEN
        RAISE EXCEPTION
            'This permission is currently suspended for the delegator in the requested scope';
    END IF;


    -- --------------------------------------------------------
    -- 11. Prevent overlapping duplicate active delegations
    -- --------------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM public.permission_delegations pd
        WHERE pd.delegator_profile_id = v_actor_profile_id
          AND pd.delegatee_profile_id = p_delegatee_profile_id
          AND pd.permission_id = v_permission_id
          AND pd.branch_id IS NOT DISTINCT FROM p_branch_id
          AND pd.department_id IS NOT DISTINCT FROM p_department_id
          AND pd.is_active = true
          AND pd.revoked_at IS NULL
          AND pd.starts_at < COALESCE(
                p_ends_at,
                'infinity'::timestamptz
              )
          AND p_starts_at < COALESCE(
                pd.ends_at,
                'infinity'::timestamptz
              )
    ) THEN
        RAISE EXCEPTION
            'An overlapping active delegation already exists';
    END IF;


    -- --------------------------------------------------------
    -- 12. Create delegation
    -- --------------------------------------------------------

    INSERT INTO public.permission_delegations (
        delegator_profile_id,
        delegatee_profile_id,
        permission_id,
        branch_id,
        department_id,
        starts_at,
        ends_at,
        is_active,
        delegation_reason,
        notes
    )
    VALUES (
        v_actor_profile_id,
        p_delegatee_profile_id,
        v_permission_id,
        p_branch_id,
        p_department_id,
        p_starts_at,
        p_ends_at,
        true,
        p_reason,
        p_notes
    )
    RETURNING id
    INTO v_delegation_id;


    RETURN v_delegation_id;
END;
$function$;