-- =====================================================
-- Ofoq ERP v1.0
-- Shared Audit Triggers
-- =====================================================
CREATE OR REPLACE FUNCTION public.log_audit_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_record_id UUID;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_record_id := OLD.id;
    ELSE
        v_record_id := NEW.id;
    END IF;

    INSERT INTO public.audit_logs (
        table_name,
        record_id,
        operation,
        old_data,
        new_data,
        changed_by,
        changed_at,
        module_name,
        organization_id
    )
    VALUES (
        TG_TABLE_NAME,
        v_record_id,
        TG_OP,
        CASE
            WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD)
            ELSE NULL
        END,
        CASE
            WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW)
            ELSE NULL
        END,
        auth.uid(),
        now(),
        TG_TABLE_SCHEMA,
        NULL
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;
-- =====================================================
-- Payroll Audit Triggers - Phase 1
-- =====================================================

DROP TRIGGER IF EXISTS audit_salary_structures
ON public.salary_structures;

CREATE TRIGGER audit_salary_structures
AFTER INSERT OR UPDATE OR DELETE ON public.salary_structures
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


DROP TRIGGER IF EXISTS audit_employee_salaries
ON public.employee_salaries;

CREATE TRIGGER audit_employee_salaries
AFTER INSERT OR UPDATE OR DELETE ON public.employee_salaries
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


DROP TRIGGER IF EXISTS audit_allowances
ON public.allowances;

CREATE TRIGGER audit_allowances
AFTER INSERT OR UPDATE OR DELETE ON public.allowances
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


DROP TRIGGER IF EXISTS audit_deductions
ON public.deductions;

CREATE TRIGGER audit_deductions
AFTER INSERT OR UPDATE OR DELETE ON public.deductions
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


DROP TRIGGER IF EXISTS audit_payroll_periods
ON public.payroll_periods;

CREATE TRIGGER audit_payroll_periods
AFTER INSERT OR UPDATE OR DELETE ON public.payroll_periods
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


DROP TRIGGER IF EXISTS audit_payroll_runs
ON public.payroll_runs;

CREATE TRIGGER audit_payroll_runs
AFTER INSERT OR UPDATE OR DELETE ON public.payroll_runs
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


DROP TRIGGER IF EXISTS audit_payroll_details
ON public.payroll_details;

CREATE TRIGGER audit_payroll_details
AFTER INSERT OR UPDATE OR DELETE ON public.payroll_details
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();
-- =====================================================
-- Payroll Audit Triggers - Phase 2
-- =====================================================

DROP TRIGGER IF EXISTS audit_taxes
ON public.taxes;

CREATE TRIGGER audit_taxes
AFTER INSERT OR UPDATE OR DELETE ON public.taxes
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


DROP TRIGGER IF EXISTS audit_insurance_types
ON public.insurance_types;

CREATE TRIGGER audit_insurance_types
AFTER INSERT OR UPDATE OR DELETE ON public.insurance_types
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


DROP TRIGGER IF EXISTS audit_employee_insurance
ON public.employee_insurance;

CREATE TRIGGER audit_employee_insurance
AFTER INSERT OR UPDATE OR DELETE ON public.employee_insurance
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


DROP TRIGGER IF EXISTS audit_bonuses
ON public.bonuses;

CREATE TRIGGER audit_bonuses
AFTER INSERT OR UPDATE OR DELETE ON public.bonuses
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


DROP TRIGGER IF EXISTS audit_overtime_rules
ON public.overtime_rules;

CREATE TRIGGER audit_overtime_rules
AFTER INSERT OR UPDATE OR DELETE ON public.overtime_rules
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


DROP TRIGGER IF EXISTS audit_payslips
ON public.payslips;

CREATE TRIGGER audit_payslips
AFTER INSERT OR UPDATE OR DELETE ON public.payslips
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();