-- =====================================================
-- Ofoq ERP - HRMS v1.0
-- Migration: Payroll Overtime Calculation
-- Phase 1: Employee Overtime Records
-- =====================================================

CREATE TABLE IF NOT EXISTS public.employee_overtime (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    employee_profile_id UUID NOT NULL
        REFERENCES public.employee_profiles(id)
        ON DELETE CASCADE,

    payroll_period_id UUID
        REFERENCES public.payroll_periods(id)
        ON DELETE SET NULL,

    overtime_rule_id UUID NOT NULL
        REFERENCES public.overtime_rules(id)
        ON DELETE RESTRICT,

    overtime_date DATE NOT NULL,

    minutes INTEGER NOT NULL,

    -- Snapshot values used for this overtime transaction
    hourly_rate NUMERIC(14,4),

    multiplier_applied NUMERIC(8,4),

    calculated_amount NUMERIC(14,2) NOT NULL DEFAULT 0,

    currency_id UUID
        REFERENCES public.currencies(id)
        ON DELETE RESTRICT,

    status TEXT NOT NULL DEFAULT 'Pending',

    approved_by UUID
        REFERENCES public.employee_profiles(id)
        ON DELETE SET NULL,

    approved_at TIMESTAMPTZ,

    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT employee_overtime_minutes_check
        CHECK (minutes > 0),

    CONSTRAINT employee_overtime_hourly_rate_check
        CHECK (
            hourly_rate IS NULL
            OR hourly_rate >= 0
        ),

    CONSTRAINT employee_overtime_multiplier_check
        CHECK (
            multiplier_applied IS NULL
            OR multiplier_applied >= 0
        ),

    CONSTRAINT employee_overtime_amount_check
        CHECK (calculated_amount >= 0),

    CONSTRAINT employee_overtime_status_check
        CHECK (
            status IN (
                'Pending',
                'Approved',
                'Rejected',
                'Paid',
                'Cancelled'
            )
        )
);
-- =====================================================
-- Indexes: employee_overtime
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_employee_overtime_employee
    ON public.employee_overtime(employee_profile_id);

CREATE INDEX IF NOT EXISTS idx_employee_overtime_period
    ON public.employee_overtime(payroll_period_id);

CREATE INDEX IF NOT EXISTS idx_employee_overtime_rule
    ON public.employee_overtime(overtime_rule_id);

CREATE INDEX IF NOT EXISTS idx_employee_overtime_status
    ON public.employee_overtime(status);

CREATE INDEX IF NOT EXISTS idx_employee_overtime_date
    ON public.employee_overtime(overtime_date);
    -- =====================================================
-- Updated At Trigger: employee_overtime
-- =====================================================

DROP TRIGGER IF EXISTS set_updated_at_employee_overtime
ON public.employee_overtime;

CREATE TRIGGER set_updated_at_employee_overtime
BEFORE UPDATE ON public.employee_overtime
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();
-- =====================================================
-- Audit Trigger: employee_overtime
-- =====================================================

DROP TRIGGER IF EXISTS audit_employee_overtime
ON public.employee_overtime;

CREATE TRIGGER audit_employee_overtime
AFTER INSERT OR UPDATE OR DELETE ON public.employee_overtime
FOR EACH ROW
EXECUTE FUNCTION public.log_audit_changes();