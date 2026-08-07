-- =====================================================
-- Ofoq ERP - HRMS v1.0
-- Migration: Payroll Database Indexes
-- =====================================================
-- =====================================================
-- salary_structures
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_salary_structures_title
ON public.salary_structures(title);

CREATE INDEX IF NOT EXISTS idx_salary_structures_active
ON public.salary_structures(is_active);

-- =====================================================
-- employee_salaries
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_employee_salaries_employee
ON public.employee_salaries(employee_profile_id);

CREATE INDEX IF NOT EXISTS idx_employee_salaries_structure
ON public.employee_salaries(salary_structure_id);


-- =====================================================
-- payroll_periods
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_payroll_periods_dates
ON public.payroll_periods(start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_payroll_periods_status
ON public.payroll_periods(status);


-- =====================================================
-- payroll_runs
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_payroll_runs_period
ON public.payroll_runs(payroll_period_id);

CREATE INDEX IF NOT EXISTS idx_payroll_runs_status
ON public.payroll_runs(status);
-- =====================================================
-- payroll_details
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_payroll_details_run
ON public.payroll_details(payroll_run_id);

CREATE INDEX IF NOT EXISTS idx_payroll_details_employee
ON public.payroll_details(employee_profile_id);

CREATE INDEX IF NOT EXISTS idx_payroll_details_payment_status
ON public.payroll_details(payment_status);


-- =====================================================
-- taxes
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_taxes_country
ON public.taxes(country_code);

CREATE INDEX IF NOT EXISTS idx_taxes_active_dates
ON public.taxes(is_active, effective_from, effective_to);


-- =====================================================
-- insurance_types
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_insurance_types_country
ON public.insurance_types(country_code);

CREATE INDEX IF NOT EXISTS idx_insurance_types_active
ON public.insurance_types(is_active);


-- =====================================================
-- employee_insurance
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_employee_insurance_employee
ON public.employee_insurance(employee_profile_id);

CREATE INDEX IF NOT EXISTS idx_employee_insurance_type
ON public.employee_insurance(insurance_type_id);

CREATE INDEX IF NOT EXISTS idx_employee_insurance_active
ON public.employee_insurance(is_active);


-- =====================================================
-- bonuses
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_bonuses_employee
ON public.bonuses(employee_profile_id);

CREATE INDEX IF NOT EXISTS idx_bonuses_period
ON public.bonuses(payroll_period_id);

CREATE INDEX IF NOT EXISTS idx_bonuses_status
ON public.bonuses(status);


-- =====================================================
-- overtime_rules
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_overtime_rules_country
ON public.overtime_rules(country_code);

CREATE INDEX IF NOT EXISTS idx_overtime_rules_active_dates
ON public.overtime_rules(is_active, effective_from, effective_to);


-- =====================================================
-- payslips
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_payslips_employee
ON public.payslips(employee_profile_id);

CREATE INDEX IF NOT EXISTS idx_payslips_period
ON public.payslips(payroll_period_id);

CREATE INDEX IF NOT EXISTS idx_payslips_payment_status
ON public.payslips(payment_status);