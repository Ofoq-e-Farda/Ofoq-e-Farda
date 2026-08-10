-- =====================================================
-- Ofoq ERP - HRMS v1.0
-- Migration: Payroll Bonus Calculation
-- =====================================================

CREATE OR REPLACE FUNCTION public.calculate_bonus(
    p_employee_profile_id UUID,
    p_payroll_period_id UUID
)
RETURNS NUMERIC(14,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_base_salary NUMERIC(14,2);
    v_total_bonus NUMERIC(14,2);
BEGIN

    -- Base salary used for percentage-based bonuses
    v_base_salary := public.calculate_base_salary(
        p_employee_profile_id,
        p_payroll_period_id
    );

    SELECT COALESCE(
        SUM(
            CASE
                WHEN b.percentage IS NOT NULL THEN
                    COALESCE(v_base_salary, 0) * b.percentage / 100
                ELSE
                    COALESCE(b.amount, 0)
            END
        ),
        0
    )
    INTO v_total_bonus
    FROM public.bonuses b
    WHERE b.employee_profile_id = p_employee_profile_id
      AND b.payroll_period_id = p_payroll_period_id
      AND b.status = 'Approved';

    RETURN ROUND(COALESCE(v_total_bonus, 0), 2);

END;
$$;