-- ============================================================
-- Ofoq ERP
-- Effective Permission Engine V1
-- ============================================================
-- Central authorization predicate.
--
-- Sources of access:
--   1. Active role permission
--   2. Active valid delegation
--
-- Restrictions:
--   - active profile
--   - active permission
--   - permission scope rules
--   - explicit permission scopes
--   - inherited role scopes
--   - delegation scope / validity
--   - delegation source authority
--   - permission suspensions
--
-- Scope hierarchy:
--   company
--      ↓
--   branch
--      ↓
--   department
--      ↓
--   self
-- ============================================================


CREATE OR REPLACE FUNCTION public.has_effective_permission_v1(
    p_permission_code text,
    p_scope_type text,
    p_branch_id uuid DEFAULT NULL,
    p_department_id uuid DEFAULT NULL,
    p_target_profile_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor_profile_id uuid;
    v_permission_id uuid;

    v_requested_department_branch_id uuid;

    v_role_access boolean := false;
    v_delegated_access boolean := false;
BEGIN
    -- ========================================================
    -- 1. Resolve authenticated actor
    -- ========================================================

    v_actor_profile_id := auth.uid();

    IF v_actor_profile_id IS NULL THEN
        RETURN false;
    END IF;


    -- ========================================================
    -- 2. Actor profile must be active
    -- ========================================================

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles pr
        WHERE pr.id = v_actor_profile_id
          AND pr.is_active = true
          AND pr.suspended_at IS NULL
    ) THEN
        RETURN false;
    END IF;


    -- ========================================================
    -- 3. Validate requested scope shape
    -- ========================================================

    IF p_scope_type NOT IN (
        'company',
        'branch',
        'department',
        'self'
    ) THEN
        RETURN false;
    END IF;


    -- --------------------------------------------------------
    -- SELF
    -- --------------------------------------------------------

    IF p_scope_type = 'self' THEN

        IF p_branch_id IS NOT NULL
           OR p_department_id IS NOT NULL THEN
            RETURN false;
        END IF;

        IF p_target_profile_id IS NULL
           OR p_target_profile_id IS DISTINCT FROM v_actor_profile_id THEN
            RETURN false;
        END IF;


    -- --------------------------------------------------------
    -- COMPANY
    -- --------------------------------------------------------

    ELSIF p_scope_type = 'company' THEN

        IF p_branch_id IS NOT NULL
           OR p_department_id IS NOT NULL THEN
            RETURN false;
        END IF;


    -- --------------------------------------------------------
    -- BRANCH
    -- --------------------------------------------------------

    ELSIF p_scope_type = 'branch' THEN

        IF p_branch_id IS NULL
           OR p_department_id IS NOT NULL THEN
            RETURN false;
        END IF;

        IF NOT EXISTS (
            SELECT 1
            FROM public.branches b
            WHERE b.id = p_branch_id
              AND b.status = 'active'
        ) THEN
            RETURN false;
        END IF;


    -- --------------------------------------------------------
    -- DEPARTMENT
    -- --------------------------------------------------------

    ELSIF p_scope_type = 'department' THEN

        IF p_branch_id IS NOT NULL
           OR p_department_id IS NULL THEN
            RETURN false;
        END IF;

        SELECT d.branch_id
        INTO v_requested_department_branch_id
        FROM public.departments d
        WHERE d.id = p_department_id
          AND d.is_active = true;

        IF NOT FOUND THEN
            RETURN false;
        END IF;

    END IF;


    -- ========================================================
    -- 4. Resolve active permission
    -- ========================================================

    SELECT p.id
    INTO v_permission_id
    FROM public.permissions p
    WHERE p.code = p_permission_code
      AND p.is_active = true;

    IF v_permission_id IS NULL THEN
        RETURN false;
    END IF;


    -- ========================================================
    -- 5. Permission must semantically allow requested scope
    -- ========================================================

    IF NOT EXISTS (
        SELECT 1
        FROM public.permission_scope_rules psr
        WHERE psr.permission_id = v_permission_id
          AND psr.scope_type = p_scope_type
    ) THEN
        RETURN false;
    END IF;


    -- ========================================================
    -- 6. ROLE-BASED ACCESS
    -- ========================================================

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

          AND ur.starts_at <= now()
          AND (
                ur.ends_at IS NULL
                OR ur.ends_at > now()
              )

          AND (
              -- =================================================
              -- A. Explicit permission scopes exist
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

                        AND ups.starts_at <= now()
                        AND (
                              ups.ends_at IS NULL
                              OR ups.ends_at > now()
                            )

                        AND (
                            -- -----------------------------------
                            -- Explicit COMPANY covers every
                            -- semantically allowed narrower scope
                            -- -----------------------------------
                            ups.scope_type = 'company'

                            OR

                            -- -----------------------------------
                            -- Explicit BRANCH
                            -- -----------------------------------
                            (
                                ups.scope_type = 'branch'
                                AND (
                                    p_scope_type = 'self'

                                    OR

                                    (
                                        p_scope_type = 'branch'
                                        AND ups.branch_id = p_branch_id
                                    )

                                    OR

                                    (
                                        p_scope_type = 'department'
                                        AND ups.branch_id =
                                            v_requested_department_branch_id
                                    )
                                )
                            )

                            OR

                            -- -----------------------------------
                            -- Explicit DEPARTMENT
                            -- -----------------------------------
                            (
                                ups.scope_type = 'department'
                                AND (
                                    p_scope_type = 'self'

                                    OR

                                    (
                                        p_scope_type = 'department'
                                        AND ups.department_id =
                                            p_department_id
                                    )
                                )
                            )

                            OR

                            -- -----------------------------------
                            -- Explicit SELF
                            -- -----------------------------------
                            (
                                ups.scope_type = 'self'
                                AND p_scope_type = 'self'
                            )
                        )
                  )
              )

              OR

              -- =================================================
              -- B. No explicit permission scope:
              --    inherit user_role organizational scope
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
                      -- ------------------------------------------
                      -- Department-scoped role
                      -- ------------------------------------------
                      (
                          ur.department_id IS NOT NULL
                          AND (
                              p_scope_type = 'self'

                              OR

                              (
                                  p_scope_type = 'department'
                                  AND ur.department_id =
                                      p_department_id
                              )
                          )
                      )

                      OR

                      -- ------------------------------------------
                      -- Branch-scoped role
                      -- ------------------------------------------
                      (
                          ur.department_id IS NULL
                          AND ur.branch_id IS NOT NULL
                          AND (
                              p_scope_type = 'self'

                              OR

                              (
                                  p_scope_type = 'branch'
                                  AND ur.branch_id =
                                      p_branch_id
                              )

                              OR

                              (
                                  p_scope_type = 'department'
                                  AND ur.branch_id =
                                      v_requested_department_branch_id
                              )
                          )
                      )

                      OR

                      -- ------------------------------------------
                      -- Company-scoped role
                      -- ------------------------------------------
                      (
                          ur.department_id IS NULL
                          AND ur.branch_id IS NULL
                      )
                  )
              )
          )
    )
    INTO v_role_access;


    -- ========================================================
    -- 7. DELEGATED ACCESS
    --
    -- A delegation remains effective only while:
    --   - delegation itself is active/current
    --   - delegator profile is active
    --   - delegator still owns the original permission
    --   - delegator's source permission is not suspended
    -- ========================================================

    SELECT EXISTS (
        SELECT 1
        FROM public.permission_delegations pd

        JOIN public.profiles delegator_profile
          ON delegator_profile.id = pd.delegator_profile_id
         AND delegator_profile.is_active = true
         AND delegator_profile.suspended_at IS NULL

        WHERE pd.delegatee_profile_id = v_actor_profile_id
          AND pd.permission_id = v_permission_id

          AND pd.is_active = true
          AND pd.revoked_at IS NULL

          AND pd.starts_at <= now()
          AND (
                pd.ends_at IS NULL
                OR pd.ends_at > now()
              )

          -- ===================================================
          -- 7A. Delegation covers requested scope
          -- ===================================================
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
                      p_scope_type = 'self'

                      OR

                      (
                          p_scope_type = 'branch'
                          AND pd.branch_id = p_branch_id
                      )

                      OR

                      (
                          p_scope_type = 'department'
                          AND pd.branch_id =
                              v_requested_department_branch_id
                      )
                  )
              )

              OR

              -- Department delegation
              (
                  pd.department_id IS NOT NULL
                  AND (
                      p_scope_type = 'self'

                      OR

                      (
                          p_scope_type = 'department'
                          AND pd.department_id =
                              p_department_id
                      )
                  )
              )
          )


          -- ===================================================
          -- 7B. Delegator must STILL own permission
          --     through an active role.
          -- ===================================================
          AND EXISTS (
              SELECT 1
              FROM public.user_roles dur

              JOIN public.roles dr
                ON dr.id = dur.role_id
               AND dr.is_active = true

              JOIN public.role_permissions drp
                ON drp.role_id = dur.role_id
               AND drp.permission_id = v_permission_id
               AND drp.granted = true

              WHERE dur.profile_id = pd.delegator_profile_id
                AND dur.is_active = true

                AND dur.starts_at <= now()
                AND (
                      dur.ends_at IS NULL
                      OR dur.ends_at > now()
                    )

                AND (
                    -- =========================================
                    -- Explicit delegator permission scopes
                    -- =========================================
                    (
                        EXISTS (
                            SELECT 1
                            FROM public.user_role_permission_scopes dx
                            WHERE dx.user_role_id = dur.id
                              AND dx.permission_id =
                                  v_permission_id
                              AND dx.is_active = true
                        )

                        AND EXISTS (
                            SELECT 1
                            FROM public.user_role_permission_scopes dups
                            WHERE dups.user_role_id = dur.id
                              AND dups.permission_id =
                                  v_permission_id
                              AND dups.is_active = true

                              AND dups.starts_at <= now()
                              AND (
                                    dups.ends_at IS NULL
                                    OR dups.ends_at > now()
                                  )

                              AND (
                                  -- Delegation is company-wide
                                  (
                                      pd.branch_id IS NULL
                                      AND pd.department_id IS NULL
                                      AND dups.scope_type = 'company'
                                  )

                                  OR

                                  -- Delegation is branch-wide
                                  (
                                      pd.department_id IS NULL
                                      AND pd.branch_id IS NOT NULL
                                      AND (
                                          dups.scope_type = 'company'

                                          OR

                                          (
                                              dups.scope_type = 'branch'
                                              AND dups.branch_id =
                                                  pd.branch_id
                                          )
                                      )
                                  )

                                  OR

                                  -- Delegation is department
                                  (
                                      pd.department_id IS NOT NULL
                                      AND (
                                          dups.scope_type = 'company'

                                          OR

                                          (
                                              dups.scope_type = 'department'
                                              AND dups.department_id =
                                                  pd.department_id
                                          )

                                          OR

                                          (
                                              dups.scope_type = 'branch'
                                              AND EXISTS (
                                                  SELECT 1
                                                  FROM public.departments dd
                                                  WHERE dd.id =
                                                      pd.department_id
                                                    AND dd.is_active = true
                                                    AND dd.branch_id =
                                                        dups.branch_id
                                              )
                                          )
                                      )
                                  )
                              )
                        )
                    )

                    OR

                    -- =========================================
                    -- Delegator role-scope fallback
                    -- =========================================
                    (
                        NOT EXISTS (
                            SELECT 1
                            FROM public.user_role_permission_scopes dx
                            WHERE dx.user_role_id = dur.id
                              AND dx.permission_id =
                                  v_permission_id
                              AND dx.is_active = true
                        )

                        AND (
                            -- Company role
                            (
                                dur.department_id IS NULL
                                AND dur.branch_id IS NULL
                            )

                            OR

                            -- Branch role
                            (
                                dur.department_id IS NULL
                                AND dur.branch_id IS NOT NULL
                                AND (
                                    (
                                        pd.department_id IS NULL
                                        AND pd.branch_id =
                                            dur.branch_id
                                    )

                                    OR

                                    (
                                        pd.department_id IS NOT NULL
                                        AND EXISTS (
                                            SELECT 1
                                            FROM public.departments dd
                                            WHERE dd.id =
                                                pd.department_id
                                              AND dd.is_active = true
                                              AND dd.branch_id =
                                                  dur.branch_id
                                        )
                                    )
                                )
                            )

                            OR

                            -- Department role
                            (
                                dur.department_id IS NOT NULL
                                AND pd.department_id =
                                    dur.department_id
                            )
                        )
                    )
                )
          )


          -- ===================================================
          -- 7C. Delegator source permission must not currently
          --     be suspended in the delegation scope.
          -- ===================================================
          AND NOT EXISTS (
              SELECT 1
              FROM public.permission_suspensions dps
              WHERE dps.profile_id = pd.delegator_profile_id
                AND dps.permission_id = v_permission_id
                AND dps.is_active = true
                AND dps.revoked_at IS NULL

                AND dps.starts_at <= now()
                AND (
                      dps.ends_at IS NULL
                      OR dps.ends_at > now()
                    )

                AND (
                    -- Company suspension blocks everything
                    (
                        dps.branch_id IS NULL
                        AND dps.department_id IS NULL
                    )

                    OR

                    -- Branch suspension
                    (
                        dps.department_id IS NULL
                        AND dps.branch_id IS NOT NULL
                        AND (
                            (
                                pd.department_id IS NULL
                                AND pd.branch_id =
                                    dps.branch_id
                            )

                            OR

                            (
                                pd.department_id IS NOT NULL
                                AND EXISTS (
                                    SELECT 1
                                    FROM public.departments dd
                                    WHERE dd.id =
                                        pd.department_id
                                      AND dd.branch_id =
                                          dps.branch_id
                                )
                            )
                        )
                    )

                    OR

                    -- Department suspension
                    (
                        dps.department_id IS NOT NULL
                        AND pd.department_id =
                            dps.department_id
                    )
                )
          )
    )
    INTO v_delegated_access;


    -- ========================================================
    -- 8. No source = no access
    -- ========================================================

    IF v_role_access IS NOT TRUE
       AND v_delegated_access IS NOT TRUE THEN
        RETURN false;
    END IF;


    -- ========================================================
    -- 9. Actor's target permission must not be suspended
    --    in the requested scope.
    --
    -- Company suspension blocks every organizational scope.
    -- Branch suspension blocks branch + its departments.
    -- Department suspension blocks that department.
    -- ========================================================

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

              -- Branch suspension
              (
                  ps.department_id IS NULL
                  AND ps.branch_id IS NOT NULL
                  AND (
                      (
                          p_scope_type = 'branch'
                          AND ps.branch_id =
                              p_branch_id
                      )

                      OR

                      (
                          p_scope_type = 'department'
                          AND ps.branch_id =
                              v_requested_department_branch_id
                      )
                  )
              )

              OR

              -- Department suspension
              (
                  ps.department_id IS NOT NULL
                  AND p_scope_type = 'department'
                  AND ps.department_id =
                      p_department_id
              )
          )
    ) THEN
        RETURN false;
    END IF;


    -- ========================================================
    -- 10. Effective permission granted
    -- ========================================================

    RETURN true;
END;
$function$;


-- ============================================================
-- EXECUTE PRIVILEGES
-- ============================================================

REVOKE ALL
ON FUNCTION public.has_effective_permission_v1(
    text,
    text,
    uuid,
    uuid,
    uuid
)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.has_effective_permission_v1(
    text,
    text,
    uuid,
    uuid,
    uuid
)
TO authenticated;