-- =====================================================
-- Ofoq ERP v1.0
-- Module: HRMS
-- Migration: Employee Taxes
-- Version: 1.0.0
-- =====================================================

CREATE TABLE IF NOT EXISTS public.employee_taxes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    employee_profile_id UUID NOT NULL
        REFERENCES public.employee_profiles(id)
        ON DELETE CASCADE,

    tax_id UUID NOT NULL
        REFERENCES public.taxes(id)
        ON DELETE RESTRICT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    effective_from DATE NOT NULL,
    effective_to DATE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT employee_taxes_valid_dates
        CHECK (
            effective_to IS NULL
            OR effective_to >= effective_from
        ),

    CONSTRAINT employee_taxes_unique_assignment
        UNIQUE (
            employee_profile_id,
            tax_id,
            effective_from
        )
);
-- =====================================================
-- Indexes: employee_taxes
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_employee_taxes_employee
ON public.employee_taxes(employee_profile_id);

CREATE INDEX IF NOT EXISTS idx_employee_taxes_tax
ON public.employee_taxes(tax_id);

CREATE INDEX IF NOT EXISTS idx_employee_taxes_active_dates
ON public.employee_taxes(is_active, effective_from, effective_to);
-- =====================================================
-- Audit Trigger: employee_taxes
-- =====================================================

DROP TRIGGER IF EXISTS audit_employee_taxes
ON public.employee_taxes;

CREATE TRIGGER audit_employee_taxes
AFTER INSERT OR UPDATE OR DELETE ON public.employee_taxes
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();


-- =====================================================
-- Updated At Trigger: employee_taxes
-- =====================================================

DROP TRIGGER IF EXISTS set_updated_at_employee_taxes
ON public.employee_taxes;

CREATE TRIGGER set_updated_at_employee_taxes
BEFORE UPDATE ON public.employee_taxes
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();