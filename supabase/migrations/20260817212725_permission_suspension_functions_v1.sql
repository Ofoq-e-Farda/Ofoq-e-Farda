-- ============================================================
-- Ofoq ERP
-- Permission Suspension Functions V1
-- ============================================================


-- ============================================================
-- 1. CREATE PERMISSION SUSPENSION
-- ============================================================

CREATE OR REPLACE FUNCTION public.suspend_permission_v1(
    p_target_profile_id uuid,
    p_permission_code text,
    p_branch_id uuid DEFAULT NULL,
    p_department_id uuid DEFAULT NULL,
    p_starts_at timestamptz DEFAULT now(),
    p_ends_at timestamptz DEFAULT NULL,
    p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor_profile_id uuid;

    v_target_permission_id uuid;
    v_admin_permission_id uuid;

    v_suspension_id uuid;

    v_requested_scope_type text;
    v_department_branch_id uuid;

    v_actor_authorized boolean := false;
BEGIN
    -- --------------------------------------------------------
    -- 1. Authentication
    -- --------------------------------------------------------

    v_actor_profile_id := auth.uid();

    IF v_actor_profile_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;


    -- --------------------------------------------------------
    -- 2. Prevent self-suspension
    -- --------------------------------------------------------

    IF p_target_profile_id = v_actor_profile_id THEN
        RAISE EXCEPTION
            'You cannot suspend your own permission';
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
    -- 4. Validate actor profile
    -- --------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles pr
        WHERE pr.id = v_actor_profile_id
          AND pr.is_active = true
          AND pr.suspended_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'Actor profile is inactive or suspended';
    END IF;


    -- --------------------------------------------------------
    -- 5. Validate target profile
    -- --------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles pr
        WHERE pr.id = p_target_profile_id
          AND pr.is_active = true
          AND pr.suspended_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'Target profile is inactive or suspended';
    END IF;


    -- --------------------------------------------------------
    -- 6. Resolve target permission
    -- --------------------------------------------------------

    SELECT p.id
    INTO v_target_permission_id
    FROM public.permissions p
    WHERE p.code = p_permission_code
      AND p.is_active = true;

    IF v_target_permission_id IS NULL THEN
        RAISE EXCEPTION
            'Permission does not exist or is inactive: %',
            p_permission_code;
    END IF;


    -- --------------------------------------------------------
    -- 7. Resolve suspension-admin permission
    -- --------------------------------------------------------

    SELECT p.id
    INTO v_admin_permission_id
    FROM public.permissions p
    WHERE p.code = 'security.permission_suspensions.create'
      AND p.is_active = true;

    IF v_admin_permission_id IS NULL THEN
        RAISE EXCEPTION
            'Suspension create permission is not configured';
    END IF;


    -- --------------------------------------------------------
    -- 8. Resolve requested scope
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

        IF p_branch_id IS NOT NULL
           AND p_branch_id IS DISTINCT FROM v_department_branch_id THEN
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
    -- 9. Admin permission must allow requested scope type
    -- --------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM public.permission_scope_rules psr
        WHERE psr.permission_id = v_admin_permission_id
          AND psr.scope_type = v_requested_scope_type
    ) THEN
        RAISE EXCEPTION
            'Suspension administration is not allowed at scope type %',
            v_requested_scope_type;
    END IF;


    -- --------------------------------------------------------
    -- 10. Verify actor owns suspension-create permission
    --
    -- Explicit permission scopes override role scope.
    -- Without explicit scopes, user_role scope is inherited.
    -- Requested validity must stay inside actor validity.
    -- --------------------------------------------------------

    SELECT EXISTS (
        SELECT 1
        FROM public.user_roles ur

        JOIN public.roles r
          ON r.id = ur.role_id
         AND r.is_active = true

        JOIN public.role_permissions rp
          ON rp.role_id = ur.role_id
         AND rp.permission_id = v_admin_permission_id
         AND rp.granted = true

        WHERE ur.profile_id = v_actor_profile_id
          AND ur.is_active = true

          AND ur.starts_at <= now()
          AND (
                ur.ends_at IS NULL
                OR ur.ends_at > now()
              )

          AND p_starts_at >= ur.starts_at

          AND (
                ur.ends_at IS NULL
                OR (
                    p_ends_at IS NOT NULL
                    AND p_ends_at <= ur.ends_at
                )
              )

          AND (
              -- -----------------------------------------------
              -- Explicit permission scopes exist
              -- -----------------------------------------------
              (
                  EXISTS (
                      SELECT 1
                      FROM public.user_role_permission_scopes x
                      WHERE x.user_role_id = ur.id
                        AND x.permission_id = v_admin_permission_id
                        AND x.is_active = true
                  )

                  AND EXISTS (
                      SELECT 1
                      FROM public.user_role_permission_scopes ups
                      WHERE ups.user_role_id = ur.id
                        AND ups.permission_id = v_admin_permission_id
                        AND ups.is_active = true

                        AND ups.starts_at <= now()
                        AND (
                              ups.ends_at IS NULL
                              OR ups.ends_at > now()
                            )

                        AND p_starts_at >= ups.starts_at

                        AND (
                              ups.ends_at IS NULL
                              OR (
                                  p_ends_at IS NOT NULL
                                  AND p_ends_at <= ups.ends_at
                              )
                            )

                        AND (
                            -- Company
                            ups.scope_type = 'company'

                            OR

                            -- Branch
                            (
                                ups.scope_type = 'branch'
                                AND (
                                    (
                                        v_requested_scope_type = 'branch'
                                        AND ups.branch_id = p_branch_id
                                    )
                                    OR
                                    (
                                        v_requested_scope_type = 'department'
                                        AND ups.branch_id = v_department_branch_id
                                    )
                                )
                            )

                            OR

                            -- Department
                            (
                                ups.scope_type = 'department'
                                AND v_requested_scope_type = 'department'
                                AND ups.department_id = p_department_id
                            )
                        )
                  )
              )

              OR

              -- -----------------------------------------------
              -- No explicit scope: inherit user_role scope
              -- -----------------------------------------------
              (
                  NOT EXISTS (
                      SELECT 1
                      FROM public.user_role_permission_scopes x
                      WHERE x.user_role_id = ur.id
                        AND x.permission_id = v_admin_permission_id
                        AND x.is_active = true
                  )

                  AND (
                      -- Department role
                      (
                          ur.department_id IS NOT NULL
                          AND v_requested_scope_type = 'department'
                          AND ur.department_id = p_department_id
                      )

                      OR

                      -- Branch role
                      (
                          ur.department_id IS NULL
                          AND ur.branch_id IS NOT NULL
                          AND (
                              (
                                  v_requested_scope_type = 'branch'
                                  AND ur.branch_id = p_branch_id
                              )
                              OR
                              (
                                  v_requested_scope_type = 'department'
                                  AND ur.branch_id = v_department_branch_id
                              )
                          )
                      )

                      OR

                      -- Company role
                      (
                          ur.department_id IS NULL
                          AND ur.branch_id IS NULL
                      )
                  )
              )
          )
    )
    INTO v_actor_authorized;


    IF v_actor_authorized IS NOT TRUE THEN
        RAISE EXCEPTION
            'You are not authorized to create a suspension in the requested scope or validity period';
    END IF;


    -- --------------------------------------------------------
    -- 11. Actor's own suspension-admin permission must not
    --     currently be suspended in requested scope
    -- --------------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM public.permission_suspensions ps
        WHERE ps.profile_id = v_actor_profile_id
          AND ps.permission_id = v_admin_permission_id
          AND ps.is_active = true
          AND ps.revoked_at IS NULL
          AND ps.starts_at <= now()
          AND (
                ps.ends_at IS NULL
                OR ps.ends_at > now()
              )
          AND (
              -- Company suspension
              (
                  ps.branch_id IS NULL
                  AND ps.department_id IS NULL
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

              OR

              -- Department suspension
              (
                  ps.department_id IS NOT NULL
                  AND v_requested_scope_type = 'department'
                  AND ps.department_id = p_department_id
              )
          )
    ) THEN
        RAISE EXCEPTION
            'Your suspension administration permission is currently suspended in the requested scope';
    END IF;


    -- --------------------------------------------------------
    -- 12. Target must currently own the target permission
    --     in the requested scope through an active role
    --     or an active delegation.
    -- --------------------------------------------------------

    IF NOT (
        -- ====================================================
        -- A. Role-based ownership
        -- ====================================================
        EXISTS (
            SELECT 1
            FROM public.user_roles ur

            JOIN public.roles r
              ON r.id = ur.role_id
             AND r.is_active = true

            JOIN public.role_permissions rp
              ON rp.role_id = ur.role_id
             AND rp.permission_id = v_target_permission_id
             AND rp.granted = true

            WHERE ur.profile_id = p_target_profile_id
              AND ur.is_active = true
              AND ur.starts_at <= now()
              AND (
                    ur.ends_at IS NULL
                    OR ur.ends_at > now()
                  )

              AND (
                  -- Explicit target permission scopes exist
                  (
                      EXISTS (
                          SELECT 1
                          FROM public.user_role_permission_scopes x
                          WHERE x.user_role_id = ur.id
                            AND x.permission_id = v_target_permission_id
                            AND x.is_active = true
                      )

                      AND EXISTS (
                          SELECT 1
                          FROM public.user_role_permission_scopes ups
                          WHERE ups.user_role_id = ur.id
                            AND ups.permission_id = v_target_permission_id
                            AND ups.is_active = true
                            AND ups.starts_at <= now()
                            AND (
                                  ups.ends_at IS NULL
                                  OR ups.ends_at > now()
                                )

                            AND (
                                ups.scope_type = 'company'

                                OR

                                (
                                    ups.scope_type = 'branch'
                                    AND (
                                        (
                                            v_requested_scope_type = 'branch'
                                            AND ups.branch_id = p_branch_id
                                        )
                                        OR
                                        (
                                            v_requested_scope_type = 'department'
                                            AND ups.branch_id = v_department_branch_id
                                        )
                                    )
                                )

                                OR

                                (
                                    ups.scope_type = 'department'
                                    AND v_requested_scope_type = 'department'
                                    AND ups.department_id = p_department_id
                                )
                            )
                      )
                  )

                  OR

                  -- No explicit scope: inherit user_role scope
                  (
                      NOT EXISTS (
                          SELECT 1
                          FROM public.user_role_permission_scopes x
                          WHERE x.user_role_id = ur.id
                            AND x.permission_id = v_target_permission_id
                            AND x.is_active = true
                      )

                      AND (
                          (
                              ur.department_id IS NOT NULL
                              AND v_requested_scope_type = 'department'
                              AND ur.department_id = p_department_id
                          )

                          OR

                          (
                              ur.department_id IS NULL
                              AND ur.branch_id IS NOT NULL
                              AND (
                                  (
                                      v_requested_scope_type = 'branch'
                                      AND ur.branch_id = p_branch_id
                                  )
                                  OR
                                  (
                                      v_requested_scope_type = 'department'
                                      AND ur.branch_id = v_department_branch_id
                                  )
                              )
                          )

                          OR

                          (
                              ur.department_id IS NULL
                              AND ur.branch_id IS NULL
                          )
                      )
                  )
              )
        )

        OR

        -- ====================================================
        -- B. Delegated ownership
        -- ====================================================
        EXISTS (
            SELECT 1
            FROM public.permission_delegations pd
            WHERE pd.delegatee_profile_id = p_target_profile_id
              AND pd.permission_id = v_target_permission_id
              AND pd.is_active = true
              AND pd.revoked_at IS NULL
              AND pd.starts_at <= now()
              AND (
                    pd.ends_at IS NULL
                    OR pd.ends_at > now()
                  )

              AND (
                  -- Company delegation
                  (
                      pd.branch_id IS NULL
                      AND pd.department_id IS NULL
                  )

                  OR

                  -- Branch delegation
                  (
                      pd.department_id IS NULL
                      AND pd.branch_id IS NOT NULL
                      AND (
                          (
                              v_requested_scope_type = 'branch'
                              AND pd.branch_id = p_branch_id
                          )
                          OR
                          (
                              v_requested_scope_type = 'department'
                              AND pd.branch_id = v_department_branch_id
                          )
                      )
                  )

                  OR

                  -- Department delegation
                  (
                      pd.department_id IS NOT NULL
                      AND v_requested_scope_type = 'department'
                      AND pd.department_id = p_department_id
                  )
              )
        )
    ) THEN
        RAISE EXCEPTION
            'Target profile does not currently own this permission in the requested scope';
    END IF;


    -- --------------------------------------------------------
    -- 13. Prevent overlapping active suspension
    -- --------------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM public.permission_suspensions ps
        WHERE ps.profile_id = p_target_profile_id
          AND ps.permission_id = v_target_permission_id
          AND ps.branch_id IS NOT DISTINCT FROM p_branch_id
          AND ps.department_id IS NOT DISTINCT FROM p_department_id
          AND ps.is_active = true
          AND ps.revoked_at IS NULL

          AND ps.starts_at < COALESCE(
                p_ends_at,
                'infinity'::timestamptz
              )

          AND p_starts_at < COALESCE(
                ps.ends_at,
                'infinity'::timestamptz
              )
    ) THEN
        RAISE EXCEPTION
            'An overlapping active permission suspension already exists';
    END IF;


    -- --------------------------------------------------------
    -- 14. Create suspension
    -- --------------------------------------------------------

    INSERT INTO public.permission_suspensions (
        profile_id,
        permission_id,
        branch_id,
        department_id,
        starts_at,
        ends_at,
        is_active,
        suspension_reason,
        created_by
    )
    VALUES (
        p_target_profile_id,
        v_target_permission_id,
        p_branch_id,
        p_department_id,
        p_starts_at,
        p_ends_at,
        true,
        p_reason,
        v_actor_profile_id
    )
    RETURNING id
    INTO v_suspension_id;


    RETURN v_suspension_id;
END;
$function$;


-- ============================================================
-- 2. REVOKE PERMISSION SUSPENSION
-- ============================================================

CREATE OR REPLACE FUNCTION public.revoke_permission_suspension_v1(
    p_suspension_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor_profile_id uuid;

    v_admin_permission_id uuid;

    v_target_profile_id uuid;
    v_target_permission_id uuid;

    v_branch_id uuid;
    v_department_id uuid;
    v_department_branch_id uuid;

    v_scope_type text;

    v_actor_authorized boolean := false;
BEGIN
    -- --------------------------------------------------------
    -- 1. Authentication
    -- --------------------------------------------------------

    v_actor_profile_id := auth.uid();

    IF v_actor_profile_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;


    -- --------------------------------------------------------
    -- 2. Validate actor
    -- --------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles pr
        WHERE pr.id = v_actor_profile_id
          AND pr.is_active = true
          AND pr.suspended_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'Actor profile is inactive or suspended';
    END IF;


    -- --------------------------------------------------------
    -- 3. Resolve suspension
    -- --------------------------------------------------------

    SELECT
        ps.profile_id,
        ps.permission_id,
        ps.branch_id,
        ps.department_id
    INTO
        v_target_profile_id,
        v_target_permission_id,
        v_branch_id,
        v_department_id
    FROM public.permission_suspensions ps
    WHERE ps.id = p_suspension_id
      AND ps.is_active = true
      AND ps.revoked_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Active permission suspension does not exist';
    END IF;


    -- --------------------------------------------------------
    -- 4. Resolve scope
    -- --------------------------------------------------------

    IF v_department_id IS NOT NULL THEN
        v_scope_type := 'department';

        SELECT d.branch_id
        INTO v_department_branch_id
        FROM public.departments d
        WHERE d.id = v_department_id;

    ELSIF v_branch_id IS NOT NULL THEN
        v_scope_type := 'branch';

    ELSE
        v_scope_type := 'company';
    END IF;


    -- --------------------------------------------------------
    -- 5. Resolve revoke admin permission
    -- --------------------------------------------------------

    SELECT p.id
    INTO v_admin_permission_id
    FROM public.permissions p
    WHERE p.code = 'security.permission_suspensions.revoke'
      AND p.is_active = true;

    IF v_admin_permission_id IS NULL THEN
        RAISE EXCEPTION
            'Suspension revoke permission is not configured';
    END IF;


    -- --------------------------------------------------------
    -- 6. Verify actor owns revoke permission in this scope
    -- --------------------------------------------------------

    SELECT EXISTS (
        SELECT 1
        FROM public.user_roles ur

        JOIN public.roles r
          ON r.id = ur.role_id
         AND r.is_active = true

        JOIN public.role_permissions rp
          ON rp.role_id = ur.role_id
         AND rp.permission_id = v_admin_permission_id
         AND rp.granted = true

        WHERE ur.profile_id = v_actor_profile_id
          AND ur.is_active = true

          AND ur.starts_at <= now()
          AND (
                ur.ends_at IS NULL
                OR ur.ends_at > now()
              )

          AND (
              -- Explicit scopes
              (
                  EXISTS (
                      SELECT 1
                      FROM public.user_role_permission_scopes x
                      WHERE x.user_role_id = ur.id
                        AND x.permission_id = v_admin_permission_id
                        AND x.is_active = true
                  )

                  AND EXISTS (
                      SELECT 1
                      FROM public.user_role_permission_scopes ups
                      WHERE ups.user_role_id = ur.id
                        AND ups.permission_id = v_admin_permission_id
                        AND ups.is_active = true

                        AND ups.starts_at <= now()
                        AND (
                              ups.ends_at IS NULL
                              OR ups.ends_at > now()
                            )

                        AND (
                            ups.scope_type = 'company'

                            OR

                            (
                                ups.scope_type = 'branch'
                                AND (
                                    (
                                        v_scope_type = 'branch'
                                        AND ups.branch_id = v_branch_id
                                    )
                                    OR
                                    (
                                        v_scope_type = 'department'
                                        AND ups.branch_id = v_department_branch_id
                                    )
                                )
                            )

                            OR

                            (
                                ups.scope_type = 'department'
                                AND v_scope_type = 'department'
                                AND ups.department_id = v_department_id
                            )
                        )
                  )
              )

              OR

              -- Role scope fallback
              (
                  NOT EXISTS (
                      SELECT 1
                      FROM public.user_role_permission_scopes x
                      WHERE x.user_role_id = ur.id
                        AND x.permission_id = v_admin_permission_id
                        AND x.is_active = true
                  )

                  AND (
                      (
                          ur.department_id IS NOT NULL
                          AND v_scope_type = 'department'
                          AND ur.department_id = v_department_id
                      )

                      OR

                      (
                          ur.department_id IS NULL
                          AND ur.branch_id IS NOT NULL
                          AND (
                              (
                                  v_scope_type = 'branch'
                                  AND ur.branch_id = v_branch_id
                              )
                              OR
                              (
                                  v_scope_type = 'department'
                                  AND ur.branch_id = v_department_branch_id
                              )
                          )
                      )

                      OR

                      (
                          ur.department_id IS NULL
                          AND ur.branch_id IS NULL
                      )
                  )
              )
          )
    )
    INTO v_actor_authorized;


    IF v_actor_authorized IS NOT TRUE THEN
        RAISE EXCEPTION
            'You are not authorized to revoke this suspension';
    END IF;


    -- --------------------------------------------------------
    -- 7. Actor revoke permission must not be suspended
    -- --------------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM public.permission_suspensions ps
        WHERE ps.profile_id = v_actor_profile_id
          AND ps.permission_id = v_admin_permission_id
          AND ps.is_active = true
          AND ps.revoked_at IS NULL
          AND ps.starts_at <= now()
          AND (
                ps.ends_at IS NULL
                OR ps.ends_at > now()
              )
          AND (
              (
                  ps.branch_id IS NULL
                  AND ps.department_id IS NULL
              )

              OR

              (
                  ps.department_id IS NULL
                  AND ps.branch_id IS NOT NULL
                  AND (
                      (
                          v_scope_type = 'branch'
                          AND ps.branch_id = v_branch_id
                      )
                      OR
                      (
                          v_scope_type = 'department'
                          AND ps.branch_id = v_department_branch_id
                      )
                  )
              )

              OR

              (
                  ps.department_id IS NOT NULL
                  AND v_scope_type = 'department'
                  AND ps.department_id = v_department_id
              )
          )
    ) THEN
        RAISE EXCEPTION
            'Your suspension revoke permission is currently suspended in this scope';
    END IF;


    -- --------------------------------------------------------
    -- 8. Revoke suspension
    -- --------------------------------------------------------

    UPDATE public.permission_suspensions
    SET
        revoked_at = now(),
        revoked_by = v_actor_profile_id,
        is_active = false,
        updated_at = now()
    WHERE id = p_suspension_id;


    RETURN p_suspension_id;
END;
$function$;


-- ============================================================
-- 3. EXECUTE PRIVILEGES
-- ============================================================

REVOKE ALL
ON FUNCTION public.suspend_permission_v1(
    uuid,
    text,
    uuid,
    uuid,
    timestamptz,
    timestamptz,
    text
)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.suspend_permission_v1(
    uuid,
    text,
    uuid,
    uuid,
    timestamptz,
    timestamptz,
    text
)
TO authenticated;


REVOKE ALL
ON FUNCTION public.revoke_permission_suspension_v1(uuid)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.revoke_permission_suspension_v1(uuid)
TO authenticated;