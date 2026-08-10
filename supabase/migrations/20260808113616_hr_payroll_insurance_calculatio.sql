-- =====================================================
-- Ofoq ERP - HRMS v1.0
-- Migration: Payroll Insurance Calculation
-- =====================================================

CREATE OR REPLACE FUNCTION public.calculate_employee_insurance(
    p_employee_profile_id UUID,
    p_payroll_period_id UUID
)
RETURNS NUMERIC(14,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_period_end DATE;
    v_base_salary NUMERIC(14,2);
    v_total_insurance NUMERIC(14,2);
BEGIN
    -- دریافت تاریخ پایان دوره حقوق
    SELECT end_date
    INTO v_period_end
    FROM public.payroll_periods
    WHERE id = p_payroll_period_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payroll period not found.';
    END IF;

    -- دریافت حقوق پایه کارمند
    v_base_salary := public.calculate_base_salary(
        p_employee_profile_id,
        p_payroll_period_id
    );

    -- محاسبه سهم بیمه کارمند
    SELECT COALESCE(
        SUM(
            CASE
                -- نرخ اختصاصی کارمند اولویت دارد
                WHEN ei.employee_rate IS NOT NULL THEN
                    v_base_salary * ei.employee_rate / 100

                -- در غیر آن از نرخ پیش‌فرض نوع بیمه استفاده شود
                WHEN it.is_percentage = TRUE THEN
                    v_base_salary * it.employee_rate / 100

                -- اگر نرخ درصدی نباشد، مقدار به‌صورت ثابت در نظر گرفته می‌شود
                ELSE
                    it.employee_rate
            END
        ),
        0
    )
    INTO v_total_insurance
    FROM public.employee_insurance ei
    JOIN public.insurance_types it
        ON it.id = ei.insurance_type_id
    WHERE ei.employee_profile_id = p_employee_profile_id
      AND ei.is_active = TRUE
      AND it.is_active = TRUE
      AND ei.effective_from <= v_period_end
      AND (
            ei.effective_to IS NULL
            OR ei.effective_to >= v_period_end
          )
      AND it.effective_from <= v_period_end
      AND (
            it.effective_to IS NULL
            OR it.effective_to >= v_period_end
          );

    RETURN ROUND(COALESCE(v_total_insurance, 0), 2);
END;
$$;