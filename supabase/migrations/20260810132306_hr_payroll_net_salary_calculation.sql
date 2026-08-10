-- =====================================================
-- Ofoq ERP - HRMS v1.0
-- Migration: Payroll Net Salary Calculation
-- =====================================================

CREATE OR REPLACE FUNCTION public.calculate_net_salary(
    p_employee_profile_id UUID,
    p_payroll_period_id UUID
)
RETURNS NUMERIC(14,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_gross_salary      NUMERIC(14,2) := 0;
    v_tax_amount        NUMERIC(14,2) := 0;
    v_insurance_amount  NUMERIC(14,2) := 0;
    v_other_deductions  NUMERIC(14,2) := 0;
    v_net_salary        NUMERIC(14,2) := 0;
BEGIN

    -- Gross salary
    v_gross_salary := COALESCE(
        public.calculate_gross_salary(
            p_employee_profile_id,
            p_payroll_period_id
        ),
        0
    );

    -- Tax
    v_tax_amount := COALESCE(
        public.calculate_tax(
            p_employee_profile_id,
            p_payroll_period_id
        ),
        0
    );

    -- Insurance
    v_insurance_amount := COALESCE(
        public.calculate_employee_insurance(
            p_employee_profile_id,
            p_payroll_period_id
        ),
        0
    );

    -- Other deductions
    v_other_deductions := COALESCE(
        public.calculate_deductions(
            p_employee_profile_id,
            p_payroll_period_id
        ),
        0
    );

    -- Final net salary
    v_net_salary :=
          COALESCE(v_gross_salary, 0)
        - COALESCE(v_tax_amount, 0)
        - COALESCE(v_insurance_amount, 0)
        - COALESCE(v_other_deductions, 0);

    -- Net salary must not become negative
    v_net_salary := GREATEST(v_net_salary, 0);

    RETURN ROUND(COALESCE(v_net_salary, 0), 2);

END;
$$;