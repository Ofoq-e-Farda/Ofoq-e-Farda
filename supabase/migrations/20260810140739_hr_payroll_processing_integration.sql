-- =====================================================
-- Ofoq ERP - HRMS
-- Migration: Payroll Processing Integration
-- =====================================================

-- =====================================================
-- Process payroll for one employee
-- =====================================================

CREATE OR REPLACE FUNCTION public.process_payroll_employee(
    p_payroll_run_id UUID,
    p_employee_profile_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_payroll_period_id UUID;
    v_period_end DATE;

    v_employee_salary_id UUID;

    v_basic_salary NUMERIC(14,2) := 0;
    v_total_allowances NUMERIC(14,2) := 0;
    v_total_deductions NUMERIC(14,2) := 0;
    v_overtime_amount NUMERIC(14,2) := 0;
    v_bonus_amount NUMERIC(14,2) := 0;
    v_tax_amount NUMERIC(14,2) := 0;
    v_insurance_amount NUMERIC(14,2) := 0;
    v_gross_salary NUMERIC(14,2) := 0;
    v_net_salary NUMERIC(14,2) := 0;

    v_payroll_detail_id UUID;
BEGIN

    -- Get payroll period
    SELECT
        pr.payroll_period_id,
        pp.end_date
    INTO
        v_payroll_period_id,
        v_period_end
    FROM public.payroll_runs pr
    JOIN public.payroll_periods pp
        ON pp.id = pr.payroll_period_id
    WHERE pr.id = p_payroll_run_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payroll run not found.';
    END IF;

    -- Get salary record used for this payroll period
    SELECT es.id
    INTO v_employee_salary_id
    FROM public.employee_salaries es
    WHERE es.employee_profile_id = p_employee_profile_id
      AND es.effective_from <= v_period_end
      AND (
            es.effective_to IS NULL
            OR es.effective_to >= v_period_end
          )
    ORDER BY es.effective_from DESC
    LIMIT 1;

    -- Calculate payroll components
    v_basic_salary := COALESCE(
        public.calculate_base_salary(
            p_employee_profile_id,
            v_payroll_period_id
        ),
        0
    );

    v_total_allowances := COALESCE(
        public.calculate_allowances(
            p_employee_profile_id,
            v_payroll_period_id
        ),
        0
    );

    v_total_deductions := COALESCE(
        public.calculate_deductions(
            p_employee_profile_id,
            v_payroll_period_id
        ),
        0
    );

    v_overtime_amount := COALESCE(
        public.calculate_overtime(
            p_employee_profile_id,
            v_payroll_period_id
        ),
        0
    );

    v_bonus_amount := COALESCE(
        public.calculate_bonus(
            p_employee_profile_id,
            v_payroll_period_id
        ),
        0
    );

    v_tax_amount := COALESCE(
        public.calculate_tax(
            p_employee_profile_id,
            v_payroll_period_id
        ),
        0
    );

    v_insurance_amount := COALESCE(
        public.calculate_employee_insurance(
            p_employee_profile_id,
            v_payroll_period_id
        ),
        0
    );

    v_gross_salary := COALESCE(
        public.calculate_gross_salary(
            p_employee_profile_id,
            v_payroll_period_id
        ),
        0
    );

    v_net_salary := COALESCE(
        public.calculate_net_salary(
            p_employee_profile_id,
            v_payroll_period_id
        ),
        0
    );

    -- Insert or refresh payroll detail
    INSERT INTO public.payroll_details (
        payroll_run_id,
        employee_profile_id,
        employee_salary_id,
        basic_salary,
        total_allowances,
        total_deductions,
        overtime_amount,
        bonus_amount,
        tax_amount,
        insurance_amount,
        gross_salary,
        net_salary,
        payment_status
    )
    VALUES (
        p_payroll_run_id,
        p_employee_profile_id,
        v_employee_salary_id,
        v_basic_salary,
        v_total_allowances,
        v_total_deductions,
        v_overtime_amount,
        v_bonus_amount,
        v_tax_amount,
        v_insurance_amount,
        v_gross_salary,
        v_net_salary,
        'Pending'
    )
    ON CONFLICT (payroll_run_id, employee_profile_id)
    DO UPDATE SET
        employee_salary_id = EXCLUDED.employee_salary_id,
        basic_salary = EXCLUDED.basic_salary,
        total_allowances = EXCLUDED.total_allowances,
        total_deductions = EXCLUDED.total_deductions,
        overtime_amount = EXCLUDED.overtime_amount,
        bonus_amount = EXCLUDED.bonus_amount,
        tax_amount = EXCLUDED.tax_amount,
        insurance_amount = EXCLUDED.insurance_amount,
        gross_salary = EXCLUDED.gross_salary,
        net_salary = EXCLUDED.net_salary,
        updated_at = NOW()
    RETURNING id
    INTO v_payroll_detail_id;

    RETURN v_payroll_detail_id;

END;
$$;


-- =====================================================
-- Process complete payroll run
-- =====================================================

CREATE OR REPLACE FUNCTION public.process_payroll_run(
    p_payroll_run_id UUID
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_payroll_period_id UUID;
    v_period_end DATE;
    v_employee RECORD;
    v_processed_count INTEGER := 0;
BEGIN

    -- Get payroll run and period
    SELECT
        pr.payroll_period_id,
        pp.end_date
    INTO
        v_payroll_period_id,
        v_period_end
    FROM public.payroll_runs pr
    JOIN public.payroll_periods pp
        ON pp.id = pr.payroll_period_id
    WHERE pr.id = p_payroll_run_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payroll run not found.';
    END IF;

    -- Mark run as processing
    UPDATE public.payroll_runs
    SET
        status = 'Processing',
        updated_at = NOW()
    WHERE id = p_payroll_run_id;

    -- Process employees having an effective salary
    FOR v_employee IN
        SELECT DISTINCT es.employee_profile_id
        FROM public.employee_salaries es
        WHERE es.effective_from <= v_period_end
          AND (
                es.effective_to IS NULL
                OR es.effective_to >= v_period_end
              )
    LOOP

        PERFORM public.process_payroll_employee(
            p_payroll_run_id,
            v_employee.employee_profile_id
        );

        v_processed_count := v_processed_count + 1;

    END LOOP;

    -- Mark run as completed
    UPDATE public.payroll_runs
    SET
        status = 'Completed',
        processed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_payroll_run_id;

    RETURN v_processed_count;

END;
$$;