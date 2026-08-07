-- =====================================================
-- Ofoq ERP - HRMS v1.0
-- Migration: Payroll Tax & Insurance
-- =====================================================
CREATE TABLE IF NOT EXISTS public.taxes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name TEXT NOT NULL,

    code TEXT UNIQUE,

    country_code TEXT,

    description TEXT,

    tax_type TEXT NOT NULL,

    rate NUMERIC(8,4) NOT NULL DEFAULT 0,

    is_percentage BOOLEAN DEFAULT true,

    is_active BOOLEAN DEFAULT true,

    effective_from DATE NOT NULL,

    effective_to DATE,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT taxes_type_check
        CHECK (tax_type IN (
            'Income Tax',
            'Payroll Tax',
            'Corporate Tax',
            'Other'
        ))
);
CREATE TABLE IF NOT EXISTS public.insurance_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name TEXT NOT NULL,

    code TEXT UNIQUE,

    country_code TEXT,

    description TEXT,

    employee_rate NUMERIC(8,4) NOT NULL DEFAULT 0,

    employer_rate NUMERIC(8,4) NOT NULL DEFAULT 0,

    is_percentage BOOLEAN DEFAULT true,

    is_active BOOLEAN DEFAULT true,

    effective_from DATE NOT NULL,

    effective_to DATE,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.employee_insurance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    employee_profile_id UUID NOT NULL
        REFERENCES public.employee_profiles(id)
        ON DELETE CASCADE,

    insurance_type_id UUID NOT NULL
        REFERENCES public.insurance_types(id)
        ON DELETE RESTRICT,

    policy_number TEXT,

    employee_rate NUMERIC(8,4),

    employer_rate NUMERIC(8,4),

    effective_from DATE NOT NULL,

    effective_to DATE,

    is_active BOOLEAN DEFAULT true,

    notes TEXT,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT employee_insurance_date_check
        CHECK (
            effective_to IS NULL
            OR effective_to >= effective_from
        )
);