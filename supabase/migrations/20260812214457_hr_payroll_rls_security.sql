-- ============================================================
-- Ofoq-e-Farda
-- HR Payroll - Row Level Security
-- ============================================================

-- Required privileges for authenticated users
GRANT SELECT ON public.profiles TO authenticated;
GRANT SELECT ON public.employee_profiles TO authenticated;
GRANT SELECT ON public.payslips TO authenticated;


-- ============================================================
-- Profiles: authenticated user can read only own active profile
-- ============================================================

DROP POLICY IF EXISTS profiles_select_own
ON public.profiles;

CREATE POLICY profiles_select_own
ON public.profiles
FOR SELECT
TO authenticated
USING (
    id = auth.uid()
    AND is_active = true
);


-- ============================================================
-- Employee Profiles: user can read own active employee profile
-- ============================================================

DROP POLICY IF EXISTS employee_profiles_select_own
ON public.employee_profiles;

CREATE POLICY employee_profiles_select_own
ON public.employee_profiles
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles pr
        WHERE pr.id = auth.uid()
          AND pr.person_id = employee_profiles.person_id
          AND pr.is_active = true
    )
    AND is_active = true
);


-- ============================================================
-- Payslips: employee can read only own payslips
-- ============================================================

DROP POLICY IF EXISTS payslips_select_own
ON public.payslips;

CREATE POLICY payslips_select_own
ON public.payslips
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles pr
        JOIN public.employee_profiles ep
          ON ep.person_id = pr.person_id
        WHERE pr.id = auth.uid()
          AND ep.id = payslips.employee_profile_id
          AND pr.is_active = true
          AND ep.is_active = true
    )
);