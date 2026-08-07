-- =====================================================
-- Ofoq ERP v1.0
-- Module: HRMS
-- Migration: Payroll Calculation Engine
-- Version: 1.0.0
-- =====================================================
CREATE OR REPLACE FUNCTION public.calculate_base_salary(
    p_employee_profile_id UUID,
    p_payroll_period_id UUID
)
RETURNS NUMERIC(14,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_base_salary NUMERIC(14,2);
    v_period_end DATE;
BEGIN
    -- دریافت تاریخ پایان دوره حقوق
    SELECT end_date
    INTO v_period_end
    FROM public.payroll_periods
    WHERE id = p_payroll_period_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payroll period not found.';
    END IF;

    -- دریافت حقوق پایه معتبر برای این دوره
    SELECT basic_salary
    INTO v_base_salary
    FROM public.employee_salaries
    WHERE employee_profile_id = p_employee_profile_id
      AND effective_from <= v_period_end
      AND (effective_to IS NULL OR effective_to >= v_period_end)
    ORDER BY effective_from DESC
    LIMIT 1;

    RETURN COALESCE(v_base_salary, 0);
END;
$$;
CREATE OR REPLACE FUNCTION public.calculate_allowances(
    p_employee_profile_id UUID,
    p_payroll_period_id UUID
)
RETURNS NUMERIC(14,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_allowances NUMERIC(14,2);
    v_period_end DATE;
BEGIN

    -- دریافت تاریخ پایان دوره حقوق
    SELECT end_date
    INTO v_period_end
    FROM public.payroll_periods
    WHERE id = p_payroll_period_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payroll period not found.';
    END IF;

    -- جمع مزایای فعال کارمند
    SELECT COALESCE(SUM(
        CASE
            WHEN ea.amount IS NOT NULL THEN ea.amount
            WHEN ea.percentage IS NOT NULL THEN
                public.calculate_base_salary(
                    p_employee_profile_id,
                    p_payroll_period_id
                ) * ea.percentage / 100
            ELSE
                0
        END
    ),0)
    INTO v_total_allowances
    FROM public.employee_allowances ea
    WHERE ea.employee_profile_id = p_employee_profile_id
      AND ea.is_active = TRUE
      AND ea.effective_from <= v_period_end
      AND (
            ea.effective_to IS NULL
            OR ea.effective_to >= v_period_end
          );

    RETURN v_total_allowances;

END;
$$;
CREATE OR REPLACE FUNCTION public.calculate_deductions(
    p_employee_profile_id UUID,
    p_payroll_period_id UUID
)
RETURNS NUMERIC(14,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_deductions NUMERIC(14,2);
    v_period_end DATE;
    v_base_salary NUMERIC(14,2);
BEGIN

    -- دریافت تاریخ پایان دوره حقوق
    SELECT end_date
    INTO v_period_end
    FROM public.payroll_periods
    WHERE id = p_payroll_period_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payroll period not found.';
    END IF;

    -- دریافت حقوق پایه
    v_base_salary := public.calculate_base_salary(
        p_employee_profile_id,
        p_payroll_period_id
    );

    -- محاسبه مجموع کسورات
    SELECT COALESCE(
        SUM(
            CASE
                WHEN ed.amount IS NOT NULL THEN ed.amount
                WHEN ed.percentage IS NOT NULL THEN
                    v_base_salary * ed.percentage / 100
                ELSE
                    0
            END
        ),
        0
    )
    INTO v_total_deductions
    FROM public.employee_deductions ed
    WHERE ed.employee_profile_id = p_employee_profile_id
      AND ed.is_active = TRUE
      AND ed.effective_from <= v_period_end
      AND (
            ed.effective_to IS NULL
            OR ed.effective_to >= v_period_end
          );

    RETURN v_total_deductions;

END;
$$;