-- =====================================================
-- Ofoq ERP v1.0
-- Module: HRMS
-- Migration: Payroll Tax Calculation
-- Version: 1.0.0
-- =====================================================

CREATE OR REPLACE FUNCTION public.calculate_tax(
    p_employee_profile_id UUID,
    p_payroll_period_id UUID
)
RETURNS NUMERIC(14,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_period_end DATE;
    v_base_salary NUMERIC(14,2);
    v_allowances NUMERIC(14,2);
    v_taxable_amount NUMERIC(14,2);
    v_total_tax NUMERIC(14,2);
BEGIN

    -- Get payroll period end date
    SELECT end_date
    INTO v_period_end
    FROM public.payroll_periods
    WHERE id = p_payroll_period_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payroll period not found.';
    END IF;

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

    -- Current taxable amount
    v_taxable_amount :=
        COALESCE(v_base_salary, 0)
        + COALESCE(v_allowances, 0);

    -- Calculate applicable taxes
    SELECT COALESCE(
        SUM(
            CASE
                WHEN t.is_percentage = TRUE THEN
                    v_taxable_amount * t.rate / 100
                ELSE
                    t.rate
            END
        ),
        0
    )
    INTO v_total_tax
    FROM public.employee_taxes et
    JOIN public.taxes t
        ON t.id = et.tax_id
    WHERE et.employee_profile_id = p_employee_profile_id
      AND et.is_active = TRUE
      AND t.is_active = TRUE

      AND et.effective_from <= v_period_end
      AND (
            et.effective_to IS NULL
            OR et.effective_to >= v_period_end
          )

      AND t.effective_from <= v_period_end
      AND (
            t.effective_to IS NULL
            OR t.effective_to >= v_period_end
          );

    RETURN ROUND(COALESCE(v_total_tax, 0), 2);

END;
$$;