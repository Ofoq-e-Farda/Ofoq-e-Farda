-- ============================================================
-- Ofoq ERP
-- Revoke Permission Delegation V1
-- ============================================================

CREATE OR REPLACE FUNCTION public.revoke_permission_delegation_v1(
    p_delegation_id uuid,
    p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor_profile_id uuid;
    v_delegator_profile_id uuid;
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
    -- 2. Active actor
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
    -- 3. Lock active delegation
    -- --------------------------------------------------------

    SELECT
        pd.delegator_profile_id
    INTO
        v_delegator_profile_id
    FROM public.permission_delegations pd
    WHERE pd.id = p_delegation_id
      AND pd.is_active = true
      AND pd.revoked_at IS NULL
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Active permission delegation does not exist';
    END IF;


    -- --------------------------------------------------------
    -- 4. Authorization
    --
    -- V1 rule:
    -- Only the original delegator may revoke the delegation.
    -- --------------------------------------------------------

    IF v_actor_profile_id <> v_delegator_profile_id THEN
        RAISE EXCEPTION
            'Only the original delegator may revoke this delegation';
    END IF;


    -- --------------------------------------------------------
    -- 5. Revoke
    -- --------------------------------------------------------

    UPDATE public.permission_delegations
    SET
        is_active = false,
        revoked_at = now(),
        revoked_by = v_actor_profile_id,
        revocation_reason = p_reason,
        updated_at = now()
    WHERE id = p_delegation_id;


    RETURN p_delegation_id;
END;
$function$;


-- ============================================================
-- Function privileges
-- ============================================================

REVOKE ALL
ON FUNCTION public.revoke_permission_delegation_v1(
    uuid,
    text
)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.revoke_permission_delegation_v1(
    uuid,
    text
)
TO authenticated;