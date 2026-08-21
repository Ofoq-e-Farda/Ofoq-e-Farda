-- ============================================================
-- Ofoq ERP
-- Audit + Sensitive Approval V1
-- Part 5A: Audit Hardening
-- ============================================================


-- ============================================================
-- 1. Harden central audit trigger function
-- ============================================================

CREATE OR REPLACE FUNCTION public.log_audit_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_record_id uuid;

    v_actor_user_id uuid;
    v_actor_profile_id uuid;

    v_branch_id uuid;
    v_department_id uuid;

    v_old_data jsonb;
    v_new_data jsonb;
    v_row_data jsonb;

    v_module text;
    v_severity text := 'info';

    v_headers jsonb := '{}'::jsonb;
    v_user_agent text;
BEGIN
    -- --------------------------------------------------------
    -- 1. Resolve old/new row
    -- --------------------------------------------------------

    IF TG_OP = 'DELETE' THEN
        v_old_data := to_jsonb(OLD);
        v_new_data := NULL;
        v_row_data := v_old_data;
        v_record_id := OLD.id;
    ELSE
        v_old_data :=
            CASE
                WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD)
                ELSE NULL
            END;

        v_new_data := to_jsonb(NEW);
        v_row_data := v_new_data;
        v_record_id := NEW.id;
    END IF;


    -- --------------------------------------------------------
    -- 2. Resolve actor
    --
    -- In this system profiles.id = auth.users.id.
    -- --------------------------------------------------------

    v_actor_user_id := auth.uid();
    v_actor_profile_id := v_actor_user_id;


    -- --------------------------------------------------------
    -- 3. Resolve organizational scope from affected row
    -- --------------------------------------------------------

    IF v_row_data ? 'branch_id'
       AND NULLIF(v_row_data ->> 'branch_id', '') IS NOT NULL THEN
        v_branch_id :=
            (v_row_data ->> 'branch_id')::uuid;
    END IF;

    IF v_row_data ? 'department_id'
       AND NULLIF(v_row_data ->> 'department_id', '') IS NOT NULL THEN
        v_department_id :=
            (v_row_data ->> 'department_id')::uuid;
    END IF;


    -- --------------------------------------------------------
    -- 4. Resolve module from table
    -- --------------------------------------------------------

    v_module :=
        CASE
            WHEN TG_TABLE_NAME IN (
                'user_roles',
                'role_permissions',
                'user_role_permission_scopes',
                'permission_delegations',
                'permission_suspensions',
                'permissions',
                'roles'
            )
                THEN 'security'

            WHEN TG_TABLE_NAME IN (
                'allowances',
                'bonuses',
                'deductions',
                'employee_allowances',
                'employee_deductions',
                'employee_insurance',
                'employee_overtime',
                'employee_salaries',
                'employee_taxes',
                'insurance_types',
                'overtime_rules',
                'payroll_details',
                'payroll_periods',
                'payroll_runs',
                'payslips',
                'salary_structures',
                'taxes'
            )
                THEN 'payroll'

            ELSE 'hr'
        END;


    -- --------------------------------------------------------
    -- 5. Severity
    -- --------------------------------------------------------

    IF TG_OP = 'DELETE' THEN
        v_severity := 'warning';
    END IF;

    IF TG_TABLE_NAME IN (
        'user_roles',
        'role_permissions',
        'permission_delegations',
        'permission_suspensions',
        'payroll_runs'
    ) THEN
        v_severity := 'warning';
    END IF;


    -- --------------------------------------------------------
    -- 6. Optional request metadata
    -- --------------------------------------------------------

    BEGIN
        v_headers :=
            COALESCE(
                NULLIF(
                    current_setting(
                        'request.headers',
                        true
                    ),
                    ''
                )::jsonb,
                '{}'::jsonb
            );
    EXCEPTION
        WHEN OTHERS THEN
            v_headers := '{}'::jsonb;
    END;

    v_user_agent := v_headers ->> 'user-agent';


    -- --------------------------------------------------------
    -- 7. Write immutable audit event
    -- --------------------------------------------------------

    INSERT INTO public.audit_logs (
        actor_user_id,
        actor_profile_id,
        branch_id,
        department_id,

        module,
        action,

        entity_table,
        entity_id,

        event_status,
        severity,
        source,
        description,

        old_data,
        new_data,

        metadata,
        user_agent,

        occurred_at
    )
    VALUES (
        v_actor_user_id,
        v_actor_profile_id,
        v_branch_id,
        v_department_id,

        v_module,
        lower(TG_OP),

        TG_TABLE_NAME,
        v_record_id,

        'success',
        v_severity,
        'database',

        format(
            '%s on %I.%I',
            TG_OP,
            TG_TABLE_SCHEMA,
            TG_TABLE_NAME
        ),

        v_old_data,
        v_new_data,

        jsonb_build_object(
            'schema', TG_TABLE_SCHEMA,
            'trigger', TG_NAME,
            'operation', TG_OP,
            'transaction_id', txid_current()
        ),

        v_user_agent,

        now()
    );


    -- --------------------------------------------------------
    -- 8. Return trigger row
    -- --------------------------------------------------------

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$function$;


-- ============================================================
-- 2. Protect direct execution
-- ============================================================

REVOKE ALL
ON FUNCTION public.log_audit_changes()
FROM PUBLIC;


-- ============================================================
-- 3. Security-critical audit triggers
-- ============================================================


-- ------------------------------------------------------------
-- USER ROLES
-- Covers:
-- role assignment
-- role modification
-- role revoke/delete
-- ------------------------------------------------------------

DROP TRIGGER IF EXISTS audit_user_roles
ON public.user_roles;

CREATE TRIGGER audit_user_roles
AFTER INSERT OR UPDATE OR DELETE
ON public.user_roles
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


-- ------------------------------------------------------------
-- PERMISSION DELEGATIONS
-- ------------------------------------------------------------

DROP TRIGGER IF EXISTS audit_permission_delegations
ON public.permission_delegations;

CREATE TRIGGER audit_permission_delegations
AFTER INSERT OR UPDATE OR DELETE
ON public.permission_delegations
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


-- ------------------------------------------------------------
-- PERMISSION SUSPENSIONS
-- ------------------------------------------------------------

DROP TRIGGER IF EXISTS audit_permission_suspensions
ON public.permission_suspensions;

CREATE TRIGGER audit_permission_suspensions
AFTER INSERT OR UPDATE OR DELETE
ON public.permission_suspensions
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


-- ------------------------------------------------------------
-- ROLE PERMISSIONS
-- Any modification changes authorization capabilities.
-- ------------------------------------------------------------

DROP TRIGGER IF EXISTS audit_role_permissions
ON public.role_permissions;

CREATE TRIGGER audit_role_permissions
AFTER INSERT OR UPDATE OR DELETE
ON public.role_permissions
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


-- ------------------------------------------------------------
-- EXPLICIT PERMISSION SCOPES
-- ------------------------------------------------------------

DROP TRIGGER IF EXISTS audit_user_role_permission_scopes
ON public.user_role_permission_scopes;

CREATE TRIGGER audit_user_role_permission_scopes
AFTER INSERT OR UPDATE OR DELETE
ON public.user_role_permission_scopes
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();

-- ============================================================
-- Part 5B: Sensitive Approval Workflow V1
-- ============================================================


-- ============================================================
-- 4. Sensitive permission catalog
-- ============================================================

CREATE TABLE public.sensitive_permissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    permission_id uuid NOT NULL
        REFERENCES public.permissions(id)
        ON DELETE CASCADE,

    requires_approval boolean NOT NULL DEFAULT true,

    approval_permission_code text NOT NULL
        DEFAULT 'security.user_roles.approve_sensitive',

    minimum_approvals integer NOT NULL DEFAULT 1,

    is_active boolean NOT NULL DEFAULT true,

    reason text,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT sensitive_permissions_permission_key
        UNIQUE (permission_id),

    CONSTRAINT sensitive_permissions_minimum_approvals_check
        CHECK (minimum_approvals >= 1)
);


CREATE INDEX sensitive_permissions_active_idx
ON public.sensitive_permissions (
    is_active,
    requires_approval
);


CREATE TRIGGER sensitive_permissions_set_updated_at
BEFORE UPDATE
ON public.sensitive_permissions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================
-- 5. Seed the sensitive permissions already enforced by
--    delegate_permission_v1
-- ============================================================

INSERT INTO public.sensitive_permissions (
    permission_id,
    requires_approval,
    approval_permission_code,
    minimum_approvals,
    reason
)
SELECT
    p.id,
    true,
    'security.user_roles.approve_sensitive',
    1,
    'Sensitive permission requires explicit approval in V1'
FROM public.permissions p
WHERE p.code IN (
    'security.user_roles.assign',
    'security.user_roles.revoke',
    'security.user_roles.approve_sensitive',

    'payroll.payroll.approve',
    'payroll.payroll.mark_paid',
    'payroll.payroll.cancel',

    'organization.settings.manage'
)
ON CONFLICT (permission_id)
DO UPDATE SET
    requires_approval = EXCLUDED.requires_approval,
    approval_permission_code =
        EXCLUDED.approval_permission_code,
    minimum_approvals =
        EXCLUDED.minimum_approvals,
    reason = EXCLUDED.reason,
    is_active = true,
    updated_at = now();


-- ============================================================
-- 6. Sensitive approval requests
-- ============================================================

CREATE TABLE public.sensitive_approval_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    requester_profile_id uuid NOT NULL
        REFERENCES public.profiles(id),

    permission_id uuid NOT NULL
        REFERENCES public.permissions(id),

    target_profile_id uuid
        REFERENCES public.profiles(id),

    target_role_id uuid
        REFERENCES public.roles(id),

    branch_id uuid
        REFERENCES public.branches(id),

    department_id uuid
        REFERENCES public.departments(id),

    action_type text NOT NULL,

    status text NOT NULL DEFAULT 'pending',

    request_reason text,
    request_notes text,

    payload jsonb NOT NULL DEFAULT '{}'::jsonb,

    requested_at timestamptz NOT NULL DEFAULT now(),

    decided_by_profile_id uuid
        REFERENCES public.profiles(id),

    decided_at timestamptz,

    decision_reason text,

    expires_at timestamptz,

    consumed_at timestamptz,
    consumed_by_profile_id uuid
        REFERENCES public.profiles(id),

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT sensitive_approval_requests_status_check
        CHECK (
            status IN (
                'pending',
                'approved',
                'rejected',
                'cancelled',
                'expired',
                'consumed'
            )
        ),

    CONSTRAINT sensitive_approval_requests_action_format_check
        CHECK (
            action_type ~ '^[a-z0-9_.]+$'
        ),

    CONSTRAINT sensitive_approval_requests_dates_check
        CHECK (
            expires_at IS NULL
            OR expires_at > requested_at
        ),

    CONSTRAINT sensitive_approval_requests_decision_shape_check
        CHECK (
            (
                status = 'pending'
                AND decided_at IS NULL
                AND decided_by_profile_id IS NULL
            )
            OR
            (
                status IN (
                    'approved',
                    'rejected',
                    'cancelled',
                    'expired',
                    'consumed'
                )
            )
        )
);


CREATE INDEX sensitive_approval_requests_requester_idx
ON public.sensitive_approval_requests (
    requester_profile_id,
    requested_at DESC
);


CREATE INDEX sensitive_approval_requests_permission_idx
ON public.sensitive_approval_requests (
    permission_id,
    status
);


CREATE INDEX sensitive_approval_requests_target_profile_idx
ON public.sensitive_approval_requests (
    target_profile_id
)
WHERE target_profile_id IS NOT NULL;


CREATE INDEX sensitive_approval_requests_scope_idx
ON public.sensitive_approval_requests (
    branch_id,
    department_id
);


CREATE INDEX sensitive_approval_requests_pending_idx
ON public.sensitive_approval_requests (
    requested_at
)
WHERE status = 'pending';


CREATE TRIGGER sensitive_approval_requests_set_updated_at
BEFORE UPDATE
ON public.sensitive_approval_requests
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================
-- 7. Approval decision history
-- ============================================================

CREATE TABLE public.sensitive_approval_decisions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    request_id uuid NOT NULL
        REFERENCES public.sensitive_approval_requests(id)
        ON DELETE CASCADE,

    decision text NOT NULL,

    decided_by_profile_id uuid NOT NULL
        REFERENCES public.profiles(id),

    reason text,

    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,

    decided_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT sensitive_approval_decisions_decision_check
        CHECK (
            decision IN (
                'approved',
                'rejected',
                'cancelled'
            )
        )
);


CREATE INDEX sensitive_approval_decisions_request_idx
ON public.sensitive_approval_decisions (
    request_id,
    decided_at
);


-- ============================================================
-- 8. Audit new sensitive-approval objects
-- ============================================================

CREATE TRIGGER audit_sensitive_permissions
AFTER INSERT OR UPDATE OR DELETE
ON public.sensitive_permissions
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


CREATE TRIGGER audit_sensitive_approval_requests
AFTER INSERT OR UPDATE OR DELETE
ON public.sensitive_approval_requests
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


CREATE TRIGGER audit_sensitive_approval_decisions
AFTER INSERT OR UPDATE OR DELETE
ON public.sensitive_approval_decisions
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


-- ============================================================
-- 9. REQUEST sensitive approval
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
BEGIN
    -- --------------------------------------------------------
    -- Authentication
    -- --------------------------------------------------------

    v_actor_profile_id := auth.uid();

    IF v_actor_profile_id IS NULL THEN
        RAISE EXCEPTION
            'Authentication required';
    END IF;


    -- --------------------------------------------------------
    -- Active requester
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
    -- Resolve sensitive permission
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
    -- Validate action
    -- --------------------------------------------------------

    IF p_action_type IS NULL
       OR p_action_type !~ '^[a-z0-9_.]+$' THEN
        RAISE EXCEPTION
            'Invalid action type';
    END IF;


    -- --------------------------------------------------------
    -- Validate expiry
    -- --------------------------------------------------------

    IF p_expires_at IS NOT NULL
       AND p_expires_at <= now() THEN
        RAISE EXCEPTION
            'expires_at must be in the future';
    END IF;


    -- --------------------------------------------------------
    -- Validate optional targets
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
    -- Validate requested scope
    -- --------------------------------------------------------

    IF p_department_id IS NOT NULL THEN

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

        IF NOT EXISTS (
            SELECT 1
            FROM public.branches b
            WHERE b.id = p_branch_id
              AND b.status = 'active'
        ) THEN
            RAISE EXCEPTION
                'Branch does not exist or is inactive';
        END IF;

    END IF;


    -- --------------------------------------------------------
    -- Prevent duplicate pending request
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
    -- Create request
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
-- 10. APPROVE sensitive request
-- ============================================================

CREATE OR REPLACE FUNCTION public.approve_sensitive_request_v1(
    p_request_id uuid,
    p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor_profile_id uuid;

    v_requester_profile_id uuid;

    v_permission_id uuid;
    v_approval_permission_code text;

    v_branch_id uuid;
    v_department_id uuid;
BEGIN
    -- --------------------------------------------------------
    -- Authentication
    -- --------------------------------------------------------

    v_actor_profile_id := auth.uid();

    IF v_actor_profile_id IS NULL THEN
        RAISE EXCEPTION
            'Authentication required';
    END IF;


    -- --------------------------------------------------------
    -- Active approver
    -- --------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles pr
        WHERE pr.id = v_actor_profile_id
          AND pr.is_active = true
          AND pr.suspended_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'Approver profile is inactive or suspended';
    END IF;


    -- --------------------------------------------------------
    -- Lock pending request
    -- --------------------------------------------------------

    SELECT
        sar.requester_profile_id,
        sar.permission_id,
        sar.branch_id,
        sar.department_id,
        sp.approval_permission_code
    INTO
        v_requester_profile_id,
        v_permission_id,
        v_branch_id,
        v_department_id,
        v_approval_permission_code
    FROM public.sensitive_approval_requests sar
    JOIN public.sensitive_permissions sp
      ON sp.permission_id = sar.permission_id
     AND sp.is_active = true
     AND sp.requires_approval = true
    WHERE sar.id = p_request_id
      AND sar.status = 'pending'
    FOR UPDATE OF sar;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Pending sensitive approval request does not exist';
    END IF;


    -- --------------------------------------------------------
    -- Prevent self-approval
    -- --------------------------------------------------------

    IF v_requester_profile_id =
       v_actor_profile_id THEN
        RAISE EXCEPTION
            'A requester cannot approve their own sensitive request';
    END IF;


    -- --------------------------------------------------------
    -- Approval authorization
    --
    -- Use Effective Permission Engine.
    -- --------------------------------------------------------

    IF v_department_id IS NOT NULL THEN

        IF NOT public.has_effective_permission_v1(
            v_approval_permission_code,
            'department',
            NULL,
            v_department_id,
            NULL
        ) THEN
            RAISE EXCEPTION
                'You are not authorized to approve this sensitive request';
        END IF;

    ELSIF v_branch_id IS NOT NULL THEN

        IF NOT public.has_effective_permission_v1(
            v_approval_permission_code,
            'branch',
            v_branch_id,
            NULL,
            NULL
        ) THEN
            RAISE EXCEPTION
                'You are not authorized to approve this sensitive request';
        END IF;

    ELSE

        IF NOT public.has_effective_permission_v1(
            v_approval_permission_code,
            'company',
            NULL,
            NULL,
            NULL
        ) THEN
            RAISE EXCEPTION
                'You are not authorized to approve this sensitive request';
        END IF;

    END IF;


    -- --------------------------------------------------------
    -- Approve
    -- --------------------------------------------------------

    UPDATE public.sensitive_approval_requests
    SET
        status = 'approved',
        decided_by_profile_id =
            v_actor_profile_id,
        decided_at = now(),
        decision_reason = p_reason,
        updated_at = now()
    WHERE id = p_request_id;


    INSERT INTO public.sensitive_approval_decisions (
        request_id,
        decision,
        decided_by_profile_id,
        reason
    )
    VALUES (
        p_request_id,
        'approved',
        v_actor_profile_id,
        p_reason
    );


    RETURN p_request_id;
END;
$function$;


-- ============================================================
-- 11. REJECT sensitive request
-- ============================================================

CREATE OR REPLACE FUNCTION public.reject_sensitive_request_v1(
    p_request_id uuid,
    p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor_profile_id uuid;

    v_requester_profile_id uuid;
    v_approval_permission_code text;

    v_branch_id uuid;
    v_department_id uuid;
BEGIN
    v_actor_profile_id := auth.uid();

    IF v_actor_profile_id IS NULL THEN
        RAISE EXCEPTION
            'Authentication required';
    END IF;


    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles pr
        WHERE pr.id = v_actor_profile_id
          AND pr.is_active = true
          AND pr.suspended_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'Approver profile is inactive or suspended';
    END IF;


    SELECT
        sar.requester_profile_id,
        sar.branch_id,
        sar.department_id,
        sp.approval_permission_code
    INTO
        v_requester_profile_id,
        v_branch_id,
        v_department_id,
        v_approval_permission_code
    FROM public.sensitive_approval_requests sar
    JOIN public.sensitive_permissions sp
      ON sp.permission_id = sar.permission_id
     AND sp.is_active = true
     AND sp.requires_approval = true
    WHERE sar.id = p_request_id
      AND sar.status = 'pending'
    FOR UPDATE OF sar;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Pending sensitive approval request does not exist';
    END IF;


    IF v_requester_profile_id =
       v_actor_profile_id THEN
        RAISE EXCEPTION
            'A requester cannot reject their own sensitive request';
    END IF;


    IF v_department_id IS NOT NULL THEN

        IF NOT public.has_effective_permission_v1(
            v_approval_permission_code,
            'department',
            NULL,
            v_department_id,
            NULL
        ) THEN
            RAISE EXCEPTION
                'You are not authorized to reject this sensitive request';
        END IF;

    ELSIF v_branch_id IS NOT NULL THEN

        IF NOT public.has_effective_permission_v1(
            v_approval_permission_code,
            'branch',
            v_branch_id,
            NULL,
            NULL
        ) THEN
            RAISE EXCEPTION
                'You are not authorized to reject this sensitive request';
        END IF;

    ELSE

        IF NOT public.has_effective_permission_v1(
            v_approval_permission_code,
            'company',
            NULL,
            NULL,
            NULL
        ) THEN
            RAISE EXCEPTION
                'You are not authorized to reject this sensitive request';
        END IF;

    END IF;


    UPDATE public.sensitive_approval_requests
    SET
        status = 'rejected',
        decided_by_profile_id =
            v_actor_profile_id,
        decided_at = now(),
        decision_reason = p_reason,
        updated_at = now()
    WHERE id = p_request_id;


    INSERT INTO public.sensitive_approval_decisions (
        request_id,
        decision,
        decided_by_profile_id,
        reason
    )
    VALUES (
        p_request_id,
        'rejected',
        v_actor_profile_id,
        p_reason
    );


    RETURN p_request_id;
END;
$function$;


-- ============================================================
-- 12. Function privileges
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


REVOKE ALL
ON FUNCTION public.approve_sensitive_request_v1(
    uuid,
    text
)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.approve_sensitive_request_v1(
    uuid,
    text
)
TO authenticated;


REVOKE ALL
ON FUNCTION public.reject_sensitive_request_v1(
    uuid,
    text
)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.reject_sensitive_request_v1(
    uuid,
    text
)
TO authenticated;