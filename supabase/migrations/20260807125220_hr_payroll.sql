-- =====================================================
-- Ofoq ERP - HRMS v1.0
-- Migration: Payroll
-- =====================================================

CREATE TABLE IF NOT EXISTS public.salary_structures (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    title TEXT NOT NULL,

    description TEXT,

    basic_salary NUMERIC(14,2) NOT NULL,

    currency_id UUID
        REFERENCES public.currencies(id)
        ON DELETE RESTRICT,

    is_active BOOLEAN DEFAULT true,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now()

);
CREATE TABLE IF NOT EXISTS public.employee_salaries (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    employee_profile_id UUID NOT NULL
        REFERENCES public.employee_profiles(id)
        ON DELETE CASCADE,

    salary_structure_id UUID
        REFERENCES public.salary_structures(id)
        ON DELETE SET NULL,

    basic_salary NUMERIC(14,2) NOT NULL,

    effective_from DATE NOT NULL,

    effective_to DATE,

    is_current BOOLEAN DEFAULT true,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now()

);
CREATE TABLE IF NOT EXISTS public.allowances (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name TEXT NOT NULL,

    description TEXT,

    default_amount NUMERIC(14,2) DEFAULT 0,

    is_taxable BOOLEAN DEFAULT true,

    is_active BOOLEAN DEFAULT true,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now()

);
CREATE TABLE IF NOT EXISTS public.deductions (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name TEXT NOT NULL,

    description TEXT,

    default_amount NUMERIC(14,2) DEFAULT 0,

    is_percentage BOOLEAN DEFAULT false,

    is_active BOOLEAN DEFAULT true,

    created_at TIMESTAMPTZ DEFAULT now(),

    updated_at TIMESTAMPTZ DEFAULT now()

);