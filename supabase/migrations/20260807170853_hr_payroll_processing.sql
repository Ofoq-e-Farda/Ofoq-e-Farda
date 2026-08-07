-- =====================================================
-- Ofoq ERP - HRMS v1.0
-- Migration: Payroll Processing
-- =====================================================
CREATE TABLE IF NOT EXISTS public.payroll_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name TEXT NOT NULL,

    start_date DATE NOT NULL,

    end_date DATE NOT NULL,

    payment_date DATE,

    status TEXT NOT NULL DEFAULT 'Draft',

    notes TEXT,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT payroll_periods_date_check
        CHECK (end_date >= start_date),

    CONSTRAINT payroll_periods_status_check
        CHECK (status IN ('Draft', 'Open', 'Processing', 'Closed'))
);
CREATE TABLE IF NOT EXISTS public.payroll_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    payroll_period_id UUID NOT NULL
        REFERENCES public.payroll_periods(id)
        ON DELETE RESTRICT,

    run_number INTEGER NOT NULL DEFAULT 1,

    status TEXT NOT NULL DEFAULT 'Draft',

    processed_at TIMESTAMPTZ,

    approved_at TIMESTAMPTZ,

    notes TEXT,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT payroll_runs_status_check
        CHECK (status IN ('Draft', 'Processing', 'Completed', 'Approved', 'Cancelled')),

    CONSTRAINT payroll_runs_period_run_unique
        UNIQUE (payroll_period_id, run_number)
);
CREATE TABLE IF NOT EXISTS public.payroll_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    payroll_run_id UUID NOT NULL
        REFERENCES public.payroll_runs(id)
        ON DELETE CASCADE,

    employee_profile_id UUID NOT NULL
        REFERENCES public.employee_profiles(id)
        ON DELETE RESTRICT,

    employee_salary_id UUID
        REFERENCES public.employee_salaries(id)
        ON DELETE SET NULL,

    basic_salary NUMERIC(14,2) NOT NULL DEFAULT 0,

    total_allowances NUMERIC(14,2) NOT NULL DEFAULT 0,

    total_deductions NUMERIC(14,2) NOT NULL DEFAULT 0,

    overtime_amount NUMERIC(14,2) NOT NULL DEFAULT 0,

    bonus_amount NUMERIC(14,2) NOT NULL DEFAULT 0,

    tax_amount NUMERIC(14,2) NOT NULL DEFAULT 0,

    insurance_amount NUMERIC(14,2) NOT NULL DEFAULT 0,

    gross_salary NUMERIC(14,2) NOT NULL DEFAULT 0,

    net_salary NUMERIC(14,2) NOT NULL DEFAULT 0,

    payment_status TEXT NOT NULL DEFAULT 'Pending',

    notes TEXT,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT payroll_details_payment_status_check
        CHECK (payment_status IN ('Pending', 'Approved', 'Paid', 'Cancelled')),

    CONSTRAINT payroll_details_employee_run_unique
        UNIQUE (payroll_run_id, employee_profile_id)
);