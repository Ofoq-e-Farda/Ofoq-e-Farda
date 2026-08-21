-- ============================================================
-- Ofoq ERP
-- Sensitive Approval Request Authorization Hardening V1
-- ============================================================

CREATE OR REPLACE FUNCTION public.request_sensitive_approval_v1(
    p_permission_code text,
    p_action_type text,

    p_target_profile_id uuid DEFAULT NULL,
    p_target_role_id uuid DEFAULT NULL,

    p_branch_id uuid DEFAULT NULL,
    p_department_id uuid DEFAULT NULL,

    p_reason text DEFAULT NULL,
    p_notes text DEFAULT NULL,

    p_payload jsonb DEFAULT '{}'::jsonb,

    p_expires_at timestamptz DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor_profile_id uuid;
    v_permission_id uuid;
    v_request_id uuid;

    v_scope_type text;
    v_has_permission boolean := false;
BEGIN
    -- --------------------------------------------------------
    -- 1. Authentication
    -- --------------------------------------------------------

    v_actor_profile_id := auth.uid();

    IF v_actor_profile_id IS NULL THEN
        RAISE EXCEPTION
            'Authentication required';
    END IF;


    -- --------------------------------------------------------
    -- 2. Active requester
    -- --------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles pr
        WHERE pr.id = v_actor_profile_id
          AND pr.is_active = true
          AND pr.suspended_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'Requester profile is inactive or suspended';
    END IF;


    -- --------------------------------------------------------
    -- 3. Resolve sensitive permission
    -- --------------------------------------------------------

    SELECT p.id
    INTO v_permission_id
    FROM public.permissions p
    JOIN public.sensitive_permissions sp
      ON sp.permission_id = p.id
     AND sp.is_active = true
     AND sp.requires_approval = true
    WHERE p.code = p_permission_code
      AND p.is_active = true;

    IF v_permission_id IS NULL THEN
        RAISE EXCEPTION
            'Permission is not configured as sensitive: %',
            p_permission_code;
    END IF;


    -- --------------------------------------------------------
    -- 4. Validate action type
    -- --------------------------------------------------------

    IF p_action_type IS NULL
       OR p_action_type !~ '^[a-z0-9_.]+$' THEN
        RAISE EXCEPTION
            'Invalid action type';
    END IF;


    -- --------------------------------------------------------
    -- 5. Validate expiry
    -- --------------------------------------------------------

    IF p_expires_at IS NOT NULL
       AND p_expires_at <= now() THEN
        RAISE EXCEPTION
            'expires_at must be in the future';
    END IF;


    -- --------------------------------------------------------
    -- 6. Validate optional target profile
    -- --------------------------------------------------------

    IF p_target_profile_id IS NOT NULL
       AND NOT EXISTS (
            SELECT 1
            FROM public.profiles pr
            WHERE pr.id = p_target_profile_id
       ) THEN
        RAISE EXCEPTION
            'Target profile does not exist';
    END IF;


    -- --------------------------------------------------------
    -- 7. Validate optional target role
    -- --------------------------------------------------------

    IF p_target_role_id IS NOT NULL
       AND NOT EXISTS (
            SELECT 1
            FROM public.roles r
            WHERE r.id = p_target_role_id
              AND r.is_active = true
       ) THEN
        RAISE EXCEPTION
            'Target role does not exist or is inactive';
    END IF;


    -- --------------------------------------------------------
    -- 8. Validate scope and resolve scope type
    -- --------------------------------------------------------

    IF p_department_id IS NOT NULL THEN

        v_scope_type := 'department';

        IF NOT EXISTS (
            SELECT 1
            FROM public.departments d
            WHERE d.id = p_department_id
              AND d.is_active = true
              AND (
                    p_branch_id IS NULL
                    OR d.branch_id = p_branch_id
                  )
        ) THEN
            RAISE EXCEPTION
                'Department does not exist or does not belong to requested branch';
        END IF;

    ELSIF p_branch_id IS NOT NULL THEN

        v_scope_type := 'branch';

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

        v_scope_type := 'company';

    END IF;


    -- --------------------------------------------------------
    -- 9. NEW SECURITY HARDENING
    --
    -- Requester must already hold the sensitive permission
    -- effectively in the requested organizational scope.
    -- --------------------------------------------------------

    IF v_scope_type = 'department' THEN

        v_has_permission :=
            public.has_effective_permission_v1(
                p_permission_code,
                'department',
                NULL,
                p_department_id,
                NULL
            );

    ELSIF v_scope_type = 'branch' THEN

        v_has_permission :=
            public.has_effective_permission_v1(
                p_permission_code,
                'branch',
                p_branch_id,
                NULL,
                NULL
            );

    ELSE

        v_has_permission :=
            public.has_effective_permission_v1(
                p_permission_code,
                'company',
                NULL,
                NULL,
                NULL
            );

    END IF;


    IF NOT COALESCE(v_has_permission, false) THEN
        RAISE EXCEPTION
            'You are not authorized to request this sensitive operation';
    END IF;


    -- --------------------------------------------------------
    -- 10. Prevent duplicate pending request
    -- --------------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM public.sensitive_approval_requests sar
        WHERE sar.requester_profile_id =
                  v_actor_profile_id

          AND sar.permission_id =
                  v_permission_id

          AND sar.target_profile_id
                  IS NOT DISTINCT FROM
                  p_target_profile_id

          AND sar.target_role_id
                  IS NOT DISTINCT FROM
                  p_target_role_id

          AND sar.branch_id
                  IS NOT DISTINCT FROM
                  p_branch_id

          AND sar.department_id
                  IS NOT DISTINCT FROM
                  p_department_id

          AND sar.action_type =
                  p_action_type

          AND sar.status = 'pending'
    ) THEN
        RAISE EXCEPTION
            'An equivalent pending approval request already exists';
    END IF;


    -- --------------------------------------------------------
    -- 11. Create request
    -- --------------------------------------------------------

    INSERT INTO public.sensitive_approval_requests (
        requester_profile_id,
        permission_id,

        target_profile_id,
        target_role_id,

        branch_id,
        department_id,

        action_type,
        status,

        request_reason,
        request_notes,

        payload,
        expires_at
    )
    VALUES (
        v_actor_profile_id,
        v_permission_id,

        p_target_profile_id,
        p_target_role_id,

        p_branch_id,
        p_department_id,

        p_action_type,
        'pending',

        p_reason,
        p_notes,

        COALESCE(
            p_payload,
            '{}'::jsonb
        ),

        p_expires_at
    )
    RETURNING id
    INTO v_request_id;


    RETURN v_request_id;
END;
$function$;


-- ============================================================
-- Function privilege remains authenticated-only
-- ============================================================

REVOKE ALL
ON FUNCTION public.request_sensitive_approval_v1(
    text,
    text,
    uuid,
    uuid,
    uuid,
    uuid,
    text,
    text,
    jsonb,
    timestamptz
)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.request_sensitive_approval_v1(
    text,
    text,
    uuid,
    uuid,
    uuid,
    uuid,
    text,
    text,
    jsonb,
    timestamptz
)
TO authenticated;