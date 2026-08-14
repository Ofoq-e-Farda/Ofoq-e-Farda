-- ============================================================
-- HR Permission Delegation Functions V1
-- Secure controlled delegation
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
AS $$
DECLARE
    v_actor_profile_id uuid;
    v_permission_id uuid;
    v_delegation_id uuid;
BEGIN
    -- --------------------------------------------------------
    -- 1. Authenticated caller
    -- profiles.id = auth.users.id in this system
    -- --------------------------------------------------------

    v_actor_profile_id := auth.uid();

    IF v_actor_profile_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;


    -- --------------------------------------------------------
    -- 2. Prevent self-delegation
    -- --------------------------------------------------------

    IF p_delegatee_profile_id = v_actor_profile_id THEN
        RAISE EXCEPTION 'A permission cannot be delegated to yourself';
    END IF;


    -- --------------------------------------------------------
    -- 3. Validate dates
    -- --------------------------------------------------------

    IF p_starts_at IS NULL THEN
        RAISE EXCEPTION 'starts_at is required';
    END IF;

    IF p_ends_at IS NOT NULL
       AND p_ends_at <= p_starts_at THEN
        RAISE EXCEPTION 'ends_at must be later than starts_at';
    END IF;


    -- --------------------------------------------------------
    -- 4. Validate delegator profile
    -- --------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles pr
        WHERE pr.id = v_actor_profile_id
          AND pr.is_active = true
          AND pr.suspended_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Delegator profile is inactive or suspended';
    END IF;


    -- --------------------------------------------------------
    -- 5. Validate delegatee profile
    -- --------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles pr
        WHERE pr.id = p_delegatee_profile_id
          AND pr.is_active = true
          AND pr.suspended_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Delegatee profile is inactive or suspended';
    END IF;


    -- --------------------------------------------------------
    -- 6. Resolve active permission
    -- --------------------------------------------------------

    SELECT p.id
    INTO v_permission_id
    FROM public.permissions p
    WHERE p.code = p_permission_code
      AND p.is_active = true;

    IF v_permission_id IS NULL THEN
        RAISE EXCEPTION 'Permission does not exist or is inactive: %',
            p_permission_code;
    END IF;


    -- --------------------------------------------------------
    -- 7. Sensitive permissions require separate approval flow
    -- They cannot be delegated directly in V1.
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
    -- 8. Verify caller owns permission through an active role
    -- and cannot delegate beyond their own organizational scope.
    --
    -- A NULL role scope means organization-wide.
    -- --------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM public.user_roles ur
        JOIN public.roles r
          ON r.id = ur.role_id
         AND r.is_active = true
        JOIN public.role_permissions rp
          ON rp.role_id = r.id
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
                (
                    p_branch_id IS NULL
                    AND ur.branch_id IS NULL
                )
                OR
                (
                    p_branch_id IS NOT NULL
                    AND (
                        ur.branch_id IS NULL
                        OR ur.branch_id = p_branch_id
                    )
                )
              )

          AND (
                (
                    p_department_id IS NULL
                    AND ur.department_id IS NULL
                )
                OR
                (
                    p_department_id IS NOT NULL
                    AND (
                        ur.department_id IS NULL
                        OR ur.department_id = p_department_id
                    )
                )
              )
    ) THEN
        RAISE EXCEPTION
            'You do not own this permission in the requested scope';
    END IF;


    -- --------------------------------------------------------
    -- 9. Do not allow a user to bypass their own suspension
    -- by delegating the suspended permission to someone else.
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
    ) THEN
        RAISE EXCEPTION
            'This permission is currently suspended for the delegator';
    END IF;


    -- --------------------------------------------------------
    -- 10. Prevent overlapping duplicate active delegations
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
    -- 11. Create delegation
    -- Non-sensitive permissions become active immediately.
    -- Sensitive permissions were blocked above.
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
    RETURNING id INTO v_delegation_id;

    RETURN v_delegation_id;
END;
$$;


-- ============================================================
-- Function execution security
-- ============================================================

REVOKE ALL
ON FUNCTION public.delegate_permission_v1(
    uuid,
    text,
    uuid,
    uuid,
    timestamptz,
    timestamptz,
    text,
    text
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.delegate_permission_v1(
    uuid,
    text,
    uuid,
    uuid,
    timestamptz,
    timestamptz,
    text,
    text
)
FROM anon;

GRANT EXECUTE
ON FUNCTION public.delegate_permission_v1(
    uuid,
    text,
    uuid,
    uuid,
    timestamptz,
    timestamptz,
    text,
    text
)
TO authenticated;