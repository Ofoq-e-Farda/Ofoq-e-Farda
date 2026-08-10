-- =====================================================
-- Ofoq ERP - HRMS v1.0
-- Migration: Payroll Gross Salary Calculation
-- =====================================================

CREATE OR REPLACE FUNCTION public.calculate_gross_salary(
    p_employee_profile_id UUID,
    p_payroll_period_id UUID
)
RETURNS NUMERIC(14,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_base_salary NUMERIC(14,2);
    v_allowances NUMERIC(14,2);
    v_gross_salary NUMERIC(14,2);
BEGIN

    -- Base salary
    v_base_salary := public.calculate_base_salary(
        p_employee_profile_id,
        p_payroll_period_id
    );

    -- Allowances
    v_allowances := public.calculate_allowances(
        p_employee_profile_id,
        p_payroll_period_id
    );

    -- Gross salary - current core calculation
    v_gross_salary :=
        COALESCE(v_base_salary, 0)
        + COALESCE(v_allowances, 0);

    RETURN ROUND(COALESCE(v_gross_salary, 0), 2);

END;
$$;