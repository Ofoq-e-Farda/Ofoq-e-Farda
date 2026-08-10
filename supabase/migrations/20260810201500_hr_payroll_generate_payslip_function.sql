-- =====================================================
-- Ofoq ERP - HRMS v1.0
-- Migration: Payroll Generate Payslip Function
-- =====================================================

CREATE OR REPLACE FUNCTION public.generate_payslip(
    p_payroll_detail_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing_payslip_id UUID;
    v_payslip_id UUID;
    v_employee_profile_id UUID;
    v_payroll_period_id UUID;
    v_payment_status TEXT;
    v_gross_salary NUMERIC(14,2);
    v_total_deductions NUMERIC(14,2);
    v_tax_amount NUMERIC(14,2);
    v_insurance_amount NUMERIC(14,2);
    v_net_salary NUMERIC(14,2);
    v_payslip_number TEXT;
BEGIN
    -- اگر Payslip قبلاً ساخته شده، همان ID را برگردان
    SELECT ps.id
    INTO v_existing_payslip_id
    FROM public.payslips ps
    WHERE ps.payroll_detail_id = p_payroll_detail_id
    LIMIT 1;

    IF v_existing_payslip_id IS NOT NULL THEN
        RETURN v_existing_payslip_id;
    END IF;

    -- اطلاعات Payroll Detail
    SELECT
        pd.employee_profile_id,
        pr.payroll_period_id,
        pd.payment_status,
        pd.gross_salary,
        pd.total_deductions,
        pd.tax_amount,
        pd.insurance_amount,
        pd.net_salary
    INTO
        v_employee_profile_id,
        v_payroll_period_id,
        v_payment_status,
        v_gross_salary,
        v_total_deductions,
        v_tax_amount,
        v_insurance_amount,
        v_net_salary
    FROM public.payroll_details pd
    JOIN public.payroll_runs pr
        ON pr.id = pd.payroll_run_id
    WHERE pd.id = p_payroll_detail_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Payroll detail not found: %',
            p_payroll_detail_id;
    END IF;

    -- فقط Payroll پرداخت‌شده اجازه ساخت Payslip دارد
    IF v_payment_status <> 'Paid' THEN
        RAISE EXCEPTION
            'Payslip can only be generated for Paid payroll details. Current status: %',
            v_payment_status;
    END IF;

    -- شماره Payslip
    v_payslip_number :=
        'PS-' ||
        TO_CHAR(CURRENT_DATE, 'YYYYMM') ||
        '-' ||
        LPAD(
            (
                SELECT (COUNT(*) + 1)::TEXT
                FROM public.payslips
                WHERE issue_date >= DATE_TRUNC('month', CURRENT_DATE)::DATE
                  AND issue_date < (
                      DATE_TRUNC('month', CURRENT_DATE)
                      + INTERVAL '1 month'
                  )::DATE
            ),
            6,
            '0'
        );

    INSERT INTO public.payslips (
        payroll_detail_id,
        employee_profile_id,
        payroll_period_id,
        payslip_number,
        issue_date,
        payment_date,
        gross_salary,
        total_deductions,
        tax_amount,
        insurance_amount,
        net_salary,
        payment_status,
        delivery_status,
        notes
    )
    VALUES (
        p_payroll_detail_id,
        v_employee_profile_id,
        v_payroll_period_id,
        v_payslip_number,
        CURRENT_DATE,
        CURRENT_DATE,
        COALESCE(v_gross_salary, 0),
        COALESCE(v_total_deductions, 0),
        COALESCE(v_tax_amount, 0),
        COALESCE(v_insurance_amount, 0),
        COALESCE(v_net_salary, 0),
        'Paid',
        'Generated',
        'Generated automatically by public.generate_payslip()'
    )
    RETURNING id
    INTO v_payslip_id;

    RETURN v_payslip_id;
END;
$$;