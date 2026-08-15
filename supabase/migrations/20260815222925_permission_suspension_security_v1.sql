-- ============================================================
-- Ofoq ERP
-- Permission Suspension Security V1
-- ============================================================
-- Adds dedicated permissions for:
--   1. creating permission suspensions
--   2. revoking permission suspensions
--   3. viewing permission suspensions
--
-- Initial grants:
--   company_president
--   system_admin
-- ============================================================


-- ------------------------------------------------------------
-- 1. Create dedicated security permissions
-- ------------------------------------------------------------

INSERT INTO public.permissions (
    module,
    resource,
    action,
    code,
    name,
    name_en,
    description,
    is_system_permission,
    is_active
)
SELECT
    v.module,
    v.resource,
    v.action,
    v.code,
    v.name,
    v.name_en,
    v.description,
    true,
    true
FROM (
    VALUES
        (
            'security',
            'permission_suspensions',
            'create',
            'security.permission_suspensions.create',
            'تعلیق صلاحیت کاربر',
            'Create Permission Suspension',
            'Temporarily suspend a permission for a user within an authorized scope.'
        ),
        (
            'security',
            'permission_suspensions',
            'revoke',
            'security.permission_suspensions.revoke',
            'لغو تعلیق صلاحیت',
            'Revoke Permission Suspension',
            'Revoke an existing permission suspension within an authorized scope.'
        ),
        (
            'security',
            'permission_suspensions',
            'view',
            'security.permission_suspensions.view',
            'مشاهده تعلیق صلاحیت‌ها',
            'View Permission Suspensions',
            'View permission suspensions within an authorized scope.'
        )
) AS v(
    module,
    resource,
    action,
    code,
    name,
    name_en,
    description
)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.permissions p
    WHERE p.code = v.code
);


-- ------------------------------------------------------------
-- 2. Permission scope rules
--
-- Suspension administration is organizational.
-- SELF is deliberately not permitted.
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
    'security.permission_suspensions.create',
    'security.permission_suspensions.revoke',
    'security.permission_suspensions.view'
)
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------
-- 3. Initial role grants
--
-- V1:
--   company_president
--   system_admin
-- ------------------------------------------------------------

INSERT INTO public.role_permissions (
    role_id,
    permission_id,
    granted
)
SELECT
    r.id,
    p.id,
    true
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.code IN (
    'company_president',
    'system_admin'
)
  AND r.is_active = true
  AND p.code IN (
      'security.permission_suspensions.create',
      'security.permission_suspensions.revoke',
      'security.permission_suspensions.view'
  )
  AND p.is_active = true
  AND NOT EXISTS (
      SELECT 1
      FROM public.role_permissions rp
      WHERE rp.role_id = r.id
        AND rp.permission_id = p.id
  );