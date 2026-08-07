-- =====================================================
-- Ofoq ERP v1.0
-- Module: HRMS
-- Migration: Employee Payroll Components
-- Version: 1.0.0
-- =====================================================
CREATE TABLE IF NOT EXISTS public.employee_allowances (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    employee_profile_id UUID NOT NULL
        REFERENCES public.employee_profiles(id) ON DELETE CASCADE,

    allowance_id UUID NOT NULL
        REFERENCES public.allowances(id) ON DELETE CASCADE,

    amount NUMERIC(14,2),

    percentage NUMERIC(8,2),

    effective_from DATE NOT NULL,

    effective_to DATE,

    is_active BOOLEAN DEFAULT TRUE,

    notes TEXT,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT employee_allowance_unique
    UNIQUE(employee_profile_id, allowance_id, effective_from)
);
CREATE TABLE IF NOT EXISTS public.employee_deductions (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    employee_profile_id UUID NOT NULL
        REFERENCES public.employee_profiles(id) ON DELETE CASCADE,

    deduction_id UUID NOT NULL
        REFERENCES public.deductions(id) ON DELETE CASCADE,

    amount NUMERIC(14,2),

    percentage NUMERIC(8,2),

    effective_from DATE NOT NULL,

    effective_to DATE,

    is_active BOOLEAN DEFAULT TRUE,

    notes TEXT,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT employee_deduction_unique
    UNIQUE(employee_profile_id, deduction_id, effective_from)
);
-- =====================================================
-- Employee Payroll Components - updated_at triggers
-- =====================================================

DROP TRIGGER IF EXISTS employee_allowances_set_updated_at
ON public.employee_allowances;

CREATE TRIGGER employee_allowances_set_updated_at
BEFORE UPDATE ON public.employee_allowances
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS employee_deductions_set_updated_at
ON public.employee_deductions;

CREATE TRIGGER employee_deductions_set_updated_at
BEFORE UPDATE ON public.employee_deductions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =====================================================
-- Employee Payroll Components - audit triggers
-- =====================================================

DROP TRIGGER IF EXISTS audit_employee_allowances
ON public.employee_allowances;

CREATE TRIGGER audit_employee_allowances
AFTER INSERT OR UPDATE OR DELETE ON public.employee_allowances
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


DROP TRIGGER IF EXISTS audit_employee_deductions
ON public.employee_deductions;

CREATE TRIGGER audit_employee_deductions
AFTER INSERT OR UPDATE OR DELETE ON public.employee_deductions
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();
-- =====================================================
-- Employee Payroll Components - Indexes
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_employee_allowances_employee
ON public.employee_allowances(employee_profile_id);

CREATE INDEX IF NOT EXISTS idx_employee_allowances_allowance
ON public.employee_allowances(allowance_id);

CREATE INDEX IF NOT EXISTS idx_employee_allowances_active
ON public.employee_allowances(is_active);


CREATE INDEX IF NOT EXISTS idx_employee_deductions_employee
ON public.employee_deductions(employee_profile_id);

CREATE INDEX IF NOT EXISTS idx_employee_deductions_deduction
ON public.employee_deductions(deduction_id);

CREATE INDEX IF NOT EXISTS idx_employee_deductions_active
ON public.employee_deductions(is_active);