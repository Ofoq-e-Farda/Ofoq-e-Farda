-- ============================================================
-- Ofoq ERP
-- Permission Scope Rules V1
-- ============================================================
-- Defines which scope types are semantically valid
-- for each permission.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Permission scope rule table
-- ------------------------------------------------------------

CREATE TABLE public.permission_scope_rules (
    permission_id uuid NOT NULL,
    scope_type text NOT NULL,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT permission_scope_rules_pkey
        PRIMARY KEY (permission_id, scope_type),

    CONSTRAINT permission_scope_rules_permission_id_fkey
        FOREIGN KEY (permission_id)
        REFERENCES public.permissions(id)
        ON DELETE CASCADE,

    CONSTRAINT permission_scope_rules_scope_type_check
        CHECK (
            scope_type IN (
                'self',
                'department',
                'branch',
                'company'
            )
        )
);


-- ------------------------------------------------------------
-- 2. Seed SELF-only permissions
-- ------------------------------------------------------------

INSERT INTO public.permission_scope_rules (
    permission_id,
    scope_type
)
SELECT p.id, 'self'
FROM public.permissions p
WHERE p.code IN (
    'hr.attendance.view_self',
    'hr.employee.view_self',
    'hr.leave.view_self',
    'hr.leave.request',
    'payroll.payslip.view_self'
)
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------
-- 3. Seed TEAM / DEPARTMENT permissions
-- ------------------------------------------------------------

INSERT INTO public.permission_scope_rules (
    permission_id,
    scope_type
)
SELECT p.id, 'department'
FROM public.permissions p
WHERE p.code IN (
    'hr.attendance.view_team',
    'hr.employee.view_team',
    'hr.leave.view_team',
    'hr.leave.approve_team'
)
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------
-- 4. HR operational permissions
--    May be delegated at department, branch, or company level
-- ------------------------------------------------------------

INSERT INTO public.permission_scope_rules (
    permission_id,
    scope_type
)
SELECT
    p.id,
    s.scope_type
FROM public.permissions p
CROSS JOIN (
    VALUES
        ('department'),
        ('branch'),
        ('company')
) AS s(scope_type)
WHERE p.code IN (
    'hr.attendance.approve',
    'hr.attendance.manage',
    'hr.attendance.view_all',

    'hr.employee.create',
    'hr.employee.update',
    'hr.employee.deactivate',
    'hr.employee.view_all',

    'hr.leave.approve_final',
    'hr.leave.manage'
)
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------
-- 5. Organization structure VIEW
-- ------------------------------------------------------------

INSERT INTO public.permission_scope_rules (
    permission_id,
    scope_type
)
SELECT
    p.id,
    s.scope_type
FROM public.permissions p
CROSS JOIN (
    VALUES
        ('department'),
        ('branch'),
        ('company')
) AS s(scope_type)
WHERE p.code = 'organization.structure.view'
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------
-- 6. Organization management
--    Company only
-- ------------------------------------------------------------

INSERT INTO public.permission_scope_rules (
    permission_id,
    scope_type
)
SELECT p.id, 'company'
FROM public.permissions p
WHERE p.code IN (
    'organization.settings.manage',
    'organization.structure.manage'
)
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------
-- 7. Payroll operational permissions
--    Branch or company
-- ------------------------------------------------------------

INSERT INTO public.permission_scope_rules (
    permission_id,
    scope_type
)
SELECT
    p.id,
    s.scope_type
FROM public.permissions p
CROSS JOIN (
    VALUES
        ('branch'),
        ('company')
) AS s(scope_type)
WHERE p.code IN (
    'payroll.payroll.approve',
    'payroll.payroll.cancel',
    'payroll.payroll.mark_paid',
    'payroll.payroll.prepare',
    'payroll.payroll.process',
    'payroll.payroll.review',
    'payroll.payroll.view',

    'payroll.payslip.deliver',
    'payroll.payslip.generate',
    'payroll.payslip.view_all'
)
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------
-- 8. HR reports
-- ------------------------------------------------------------

INSERT INTO public.permission_scope_rules (
    permission_id,
    scope_type
)
SELECT
    p.id,
    s.scope_type
FROM public.permissions p
CROSS JOIN (
    VALUES
        ('department'),
        ('branch'),
        ('company')
) AS s(scope_type)
WHERE p.code IN (
    'reports.hr_reports.view',
    'reports.exports.export'
)
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------
-- 9. Payroll / executive reports
-- ------------------------------------------------------------

INSERT INTO public.permission_scope_rules (
    permission_id,
    scope_type
)
SELECT
    p.id,
    s.scope_type
FROM public.permissions p
CROSS JOIN (
    VALUES
        ('branch'),
        ('company')
) AS s(scope_type)
WHERE p.code = 'reports.payroll_reports.view'
ON CONFLICT DO NOTHING;


INSERT INTO public.permission_scope_rules (
    permission_id,
    scope_type
)
SELECT p.id, 'company'
FROM public.permissions p
WHERE p.code = 'reports.executive_reports.view'
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------
-- 10. Audit permissions
-- ------------------------------------------------------------

INSERT INTO public.permission_scope_rules (
    permission_id,
    scope_type
)
SELECT
    p.id,
    s.scope_type
FROM public.permissions p
CROSS JOIN (
    VALUES
        ('department'),
        ('branch'),
        ('company')
) AS s(scope_type)
WHERE p.code = 'security.audit.view_hr'
ON CONFLICT DO NOTHING;


INSERT INTO public.permission_scope_rules (
    permission_id,
    scope_type
)
SELECT
    p.id,
    s.scope_type
FROM public.permissions p
CROSS JOIN (
    VALUES
        ('branch'),
        ('company')
) AS s(scope_type)
WHERE p.code = 'security.audit.view_payroll'
ON CONFLICT DO NOTHING;


INSERT INTO public.permission_scope_rules (
    permission_id,
    scope_type
)
SELECT p.id, 'company'
FROM public.permissions p
WHERE p.code = 'security.audit.view_all'
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------
-- 11. User-role security permissions
--     Company only
-- ------------------------------------------------------------

INSERT INTO public.permission_scope_rules (
    permission_id,
    scope_type
)
SELECT p.id, 'company'
FROM public.permissions p
WHERE p.code IN (
    'security.user_roles.assign',
    'security.user_roles.revoke',
    'security.user_roles.approve_sensitive',
    'security.user_roles.view'
)
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------
-- 12. Validation function
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.validate_permission_scope_rule_v1()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.permission_scope_rules psr
        WHERE psr.permission_id = NEW.permission_id
          AND psr.scope_type = NEW.scope_type
    ) THEN
        RAISE EXCEPTION
            'Scope type % is not allowed for permission %',
            NEW.scope_type,
            NEW.permission_id;
    END IF;

    RETURN NEW;
END;
$$;


-- ------------------------------------------------------------
-- 13. Validation trigger
-- ------------------------------------------------------------

CREATE TRIGGER user_role_permission_scopes_rule_validate
BEFORE INSERT OR UPDATE OF permission_id, scope_type
ON public.user_role_permission_scopes
FOR EACH ROW
EXECUTE FUNCTION public.validate_permission_scope_rule_v1();


-- ------------------------------------------------------------
-- 14. RLS
-- ------------------------------------------------------------

ALTER TABLE public.permission_scope_rules
ENABLE ROW LEVEL SECURITY;