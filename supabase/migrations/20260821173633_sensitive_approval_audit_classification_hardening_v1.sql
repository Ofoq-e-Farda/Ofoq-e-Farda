-- ============================================================
-- Ofoq ERP
-- Sensitive Approval Audit Classification Hardening V1
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
    -- --------------------------------------------------------

    v_actor_user_id := auth.uid();
    v_actor_profile_id := v_actor_user_id;


    -- --------------------------------------------------------
    -- 3. Resolve organizational scope
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
                'roles',

                -- Sensitive Approval V1
                'sensitive_permissions',
                'sensitive_approval_requests',
                'sensitive_approval_decisions'
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
    -- 5. Resolve severity
    -- --------------------------------------------------------

    IF TG_OP = 'DELETE' THEN
        v_severity := 'warning';
    END IF;


    IF TG_TABLE_NAME IN (
        'user_roles',
        'role_permissions',
        'permission_delegations',
        'permission_suspensions',
        'payroll_runs',

        -- Sensitive Approval V1
        'sensitive_permissions',
        'sensitive_approval_requests',
        'sensitive_approval_decisions'
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


    v_user_agent :=
        v_headers ->> 'user-agent';


    -- --------------------------------------------------------
    -- 7. Write audit event
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
-- Keep trigger function private from direct execution
-- ============================================================

REVOKE ALL
ON FUNCTION public.log_audit_changes()
FROM PUBLIC;