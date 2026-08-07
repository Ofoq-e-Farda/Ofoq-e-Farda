-- =====================================================
-- Ofoq ERP v1.0
-- Shared Database Infrastructure
-- Common Functions, Triggers & Audit
-- =====================================================
CREATE TABLE IF NOT EXISTS public.audit_logs (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    table_name TEXT NOT NULL,

    record_id UUID,

    operation TEXT NOT NULL,

    old_data JSONB,

    new_data JSONB,

    changed_by UUID,

    changed_at TIMESTAMPTZ DEFAULT now(),

    ip_address TEXT,

    user_agent TEXT,

    module_name TEXT,

    organization_id UUID,

    CONSTRAINT audit_logs_operation_check
        CHECK (
            operation IN (
                'INSERT',
                'UPDATE',
                'DELETE'
            )
        )
);
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;
-- =====================================================
-- Payroll updated_at triggers - Phase 1
-- =====================================================

DROP TRIGGER IF EXISTS salary_structures_set_updated_at
ON public.salary_structures;

CREATE TRIGGER salary_structures_set_updated_at
BEFORE UPDATE ON public.salary_structures
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS employee_salaries_set_updated_at
ON public.employee_salaries;

CREATE TRIGGER employee_salaries_set_updated_at
BEFORE UPDATE ON public.employee_salaries
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS allowances_set_updated_at
ON public.allowances;

CREATE TRIGGER allowances_set_updated_at
BEFORE UPDATE ON public.allowances
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS deductions_set_updated_at
ON public.deductions;

CREATE TRIGGER deductions_set_updated_at
BEFORE UPDATE ON public.deductions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();
-- =====================================================
-- Payroll updated_at triggers - Phase 2
-- =====================================================

DROP TRIGGER IF EXISTS payroll_periods_set_updated_at
ON public.payroll_periods;

CREATE TRIGGER payroll_periods_set_updated_at
BEFORE UPDATE ON public.payroll_periods
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS payroll_runs_set_updated_at
ON public.payroll_runs;

CREATE TRIGGER payroll_runs_set_updated_at
BEFORE UPDATE ON public.payroll_runs
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS payroll_details_set_updated_at
ON public.payroll_details;

CREATE TRIGGER payroll_details_set_updated_at
BEFORE UPDATE ON public.payroll_details
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();
-- =====================================================
-- Payroll updated_at triggers - Phase 3
-- =====================================================

DROP TRIGGER IF EXISTS taxes_set_updated_at
ON public.taxes;

CREATE TRIGGER taxes_set_updated_at
BEFORE UPDATE ON public.taxes
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS insurance_types_set_updated_at
ON public.insurance_types;

CREATE TRIGGER insurance_types_set_updated_at
BEFORE UPDATE ON public.insurance_types
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS employee_insurance_set_updated_at
ON public.employee_insurance;

CREATE TRIGGER employee_insurance_set_updated_at
BEFORE UPDATE ON public.employee_insurance
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS bonuses_set_updated_at
ON public.bonuses;

CREATE TRIGGER bonuses_set_updated_at
BEFORE UPDATE ON public.bonuses
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS overtime_rules_set_updated_at
ON public.overtime_rules;

CREATE TRIGGER overtime_rules_set_updated_at
BEFORE UPDATE ON public.overtime_rules
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS payslips_set_updated_at
ON public.payslips;

CREATE TRIGGER payslips_set_updated_at
BEFORE UPDATE ON public.payslips
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();