-- =====================================================
-- Ofoq ERP - HRMS v1.0
-- Migration: Payroll Overtime Function
-- =====================================================

CREATE OR REPLACE FUNCTION public.calculate_overtime(
    p_employee_profile_id UUID,
    p_payroll_period_id UUID
)
RETURNS NUMERIC(14,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_overtime NUMERIC(14,2);
BEGIN

    -- Validate payroll period
    IF NOT EXISTS (
        SELECT 1
        FROM public.payroll_periods
        WHERE id = p_payroll_period_id
    ) THEN
        RAISE EXCEPTION 'Payroll period not found.';
    END IF;

    -- Calculate payable overtime
    SELECT COALESCE(
        SUM(COALESCE(eo.calculated_amount, 0)),
        0
    )
    INTO v_total_overtime
    FROM public.employee_overtime eo
    WHERE eo.employee_profile_id = p_employee_profile_id
      AND eo.payroll_period_id = p_payroll_period_id
      AND eo.status IN ('Approved', 'Paid');

    RETURN ROUND(COALESCE(v_total_overtime, 0), 2);

END;
$$;