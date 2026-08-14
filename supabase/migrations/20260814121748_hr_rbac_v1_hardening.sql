-- ============================================================
-- HR RBAC V1 - Security Hardening
-- ============================================================
-- 1. payroll_officer must not review payroll.
-- 2. payroll_manager must not mark payroll as paid.
-- ============================================================

UPDATE public.role_permissions rp
SET granted = false
FROM public.roles r,
     public.permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND (
        (r.code = 'payroll_officer'
         AND p.code = 'payroll.payroll.review')
        OR
        (r.code = 'payroll_manager'
         AND p.code = 'payroll.payroll.mark_paid')
      );

      -- ============================================================
-- HR RBAC V1 - Security Hardening
-- ============================================================
-- 1. payroll_officer must not review payroll.
-- 2. payroll_manager must not mark payroll as paid.
-- ============================================================

UPDATE public.role_permissions rp
SET granted = false
FROM public.roles r,
     public.permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND (
        (r.code = 'payroll_officer'
         AND p.code = 'payroll.payroll.review')
        OR
        (r.code = 'payroll_manager'
         AND p.code = 'payroll.payroll.mark_paid')
      );