-- =====================================================
-- Ofoq ERP - HRMS v1.0
-- Migration: Payroll Bonus, Overtime & Payslip
-- =====================================================
CREATE TABLE IF NOT EXISTS public.bonuses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    employee_profile_id UUID NOT NULL
        REFERENCES public.employee_profiles(id)
        ON DELETE CASCADE,

    payroll_period_id UUID
        REFERENCES public.payroll_periods(id)
        ON DELETE SET NULL,

    bonus_type TEXT NOT NULL DEFAULT 'Other',

    title TEXT NOT NULL,

    description TEXT,

    amount NUMERIC(14,2) NOT NULL DEFAULT 0,

    percentage NUMERIC(8,4),

    calculation_base TEXT,

    currency_id UUID
        REFERENCES public.currencies(id)
        ON DELETE RESTRICT,

    country_code TEXT,

    effective_date DATE NOT NULL,

    status TEXT NOT NULL DEFAULT 'Pending',

    approved_by UUID
        REFERENCES public.employee_profiles(id)
        ON DELETE SET NULL,

    approved_at TIMESTAMPTZ,

    policy_reference TEXT,

    notes TEXT,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT bonuses_type_check
        CHECK (
            bonus_type IN (
                'Performance',
                'Annual',
                'Project',
                'Holiday',
                'Commission',
                'Retention',
                'Other'
            )
        ),

    CONSTRAINT bonuses_status_check
        CHECK (
            status IN (
                'Pending',
                'Approved',
                'Rejected',
                'Paid',
                'Cancelled'
            )
        ),

    CONSTRAINT bonuses_amount_check
        CHECK (amount >= 0),

    CONSTRAINT bonuses_percentage_check
        CHECK (
            percentage IS NULL
            OR percentage >= 0
        )
);
CREATE TABLE IF NOT EXISTS public.overtime_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name TEXT NOT NULL,

    code TEXT UNIQUE,

    country_code TEXT,

    description TEXT,

    overtime_type TEXT NOT NULL DEFAULT 'Regular',

    multiplier NUMERIC(8,4) NOT NULL DEFAULT 1.00,

    minimum_minutes INTEGER DEFAULT 0,

    maximum_hours_per_day NUMERIC(5,2),

    maximum_hours_per_week NUMERIC(5,2),

    applies_on_weekends BOOLEAN DEFAULT false,

    applies_on_public_holidays BOOLEAN DEFAULT false,

    is_active BOOLEAN DEFAULT true,

    effective_from DATE NOT NULL,

    effective_to DATE,

    policy_reference TEXT,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT overtime_rules_type_check
        CHECK (
            overtime_type IN (
                'Regular',
                'Weekend',
                'Holiday',
                'Night',
                'Special'
            )
        ),

    CONSTRAINT overtime_rules_multiplier_check
        CHECK (multiplier >= 0),

    CONSTRAINT overtime_rules_date_check
        CHECK (
            effective_to IS NULL
            OR effective_to >= effective_from
        )
);
CREATE TABLE IF NOT EXISTS public.payslips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    payroll_detail_id UUID NOT NULL
        REFERENCES public.payroll_details(id)
        ON DELETE CASCADE,

    employee_profile_id UUID NOT NULL
        REFERENCES public.employee_profiles(id)
        ON DELETE RESTRICT,

    payroll_period_id UUID NOT NULL
        REFERENCES public.payroll_periods(id)
        ON DELETE RESTRICT,

    payslip_number TEXT NOT NULL UNIQUE,

    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,

    payment_date DATE,

    gross_salary NUMERIC(14,2) NOT NULL DEFAULT 0,

    total_deductions NUMERIC(14,2) NOT NULL DEFAULT 0,

    tax_amount NUMERIC(14,2) NOT NULL DEFAULT 0,

    insurance_amount NUMERIC(14,2) NOT NULL DEFAULT 0,

    net_salary NUMERIC(14,2) NOT NULL DEFAULT 0,

    currency_id UUID
        REFERENCES public.currencies(id)
        ON DELETE RESTRICT,

    payment_status TEXT NOT NULL DEFAULT 'Pending',

    delivery_status TEXT NOT NULL DEFAULT 'Generated',

    file_path TEXT,

    notes TEXT,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT payslips_payment_status_check
        CHECK (
            payment_status IN (
                'Pending',
                'Approved',
                'Paid',
                'Cancelled'
            )
        ),

    CONSTRAINT payslips_delivery_status_check
        CHECK (
            delivery_status IN (
                'Generated',
                'Delivered',
                'Viewed',
                'Archived'
            )
        ),

    CONSTRAINT payslips_amounts_check
        CHECK (
            gross_salary >= 0
            AND total_deductions >= 0
            AND tax_amount >= 0
            AND insurance_amount >= 0
            AND net_salary >= 0
        ),

    CONSTRAINT payslips_employee_period_unique
        UNIQUE (employee_profile_id, payroll_period_id)
);