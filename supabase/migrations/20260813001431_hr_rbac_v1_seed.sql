-- =========================================================
-- HR RBAC V1 - Base Roles Seed
-- Ofoq-e-Farda
-- =========================================================

INSERT INTO public.roles (
    code,
    name,
    name_en,
    description,
    hierarchy_level,
    is_system_role,
    is_active
)
VALUES
    (
        'company_president',
        'رئیس شرکت',
        'Company President',
        'Highest company-level business authority for HR and organizational approvals.',
        10,
        true,
        true
    ),
    (
        'company_vice_president',
        'معاون شرکت',
        'Company Vice President',
        'Deputy company authority with delegated business and approval responsibilities.',
        20,
        true,
        true
    ),
    (
        'hr_director',
        'رئیس منابع بشری',
        'HR Director',
        'Senior authority responsible for HR governance, policy and high-level approvals.',
        30,
        true,
        true
    ),
    (
        'hr_manager',
        'مدیر منابع بشری',
        'HR Manager',
        'Manages day-to-day HR operations and staff administration.',
        40,
        true,
        true
    ),
    (
        'payroll_manager',
        'مدیر معاشات',
        'Payroll Manager',
        'Responsible for payroll oversight, validation and approvals.',
        50,
        true,
        true
    ),
    (
        'hr_officer',
        'آفیسر منابع بشری',
        'HR Officer',
        'Performs operational HR tasks based on assigned permissions and scope.',
        60,
        true,
        true
    ),
    (
        'payroll_officer',
        'آفیسر معاشات',
        'Payroll Officer',
        'Performs payroll preparation and processing tasks without unrestricted final authority.',
        70,
        true,
        true
    ),
    (
        'department_manager',
        'مدیر بخش',
        'Department Manager',
        'Manages employees and approvals within an assigned department scope.',
        80,
        true,
        true
    ),
    (
        'employee',
        'کارمند',
        'Employee',
        'Default employee self-service role with access limited to own authorized records.',
        100,
        true,
        true
    )
ON CONFLICT (code) DO UPDATE
SET
    name = EXCLUDED.name,
    name_en = EXCLUDED.name_en,
    description = EXCLUDED.description,
    hierarchy_level = EXCLUDED.hierarchy_level,
    is_system_role = EXCLUDED.is_system_role,
    is_active = EXCLUDED.is_active,
    updated_at = now();
    -- =========================================================
-- HR RBAC V1 - Permissions Seed
-- =========================================================

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
VALUES

    -- =====================================================
    -- EMPLOYEE
    -- =====================================================
    (
        'hr',
        'employee',
        'view_self',
        'hr.employee.view_self',
        'مشاهده پروفایل خود',
        'View Own Employee Profile',
        'Allows an employee to view their own authorized employee profile.',
        true,
        true
    ),
    (
        'hr',
        'employee',
        'view_team',
        'hr.employee.view_team',
        'مشاهده کارمندان تیم',
        'View Team Employees',
        'Allows scoped viewing of employees within an assigned team or department.',
        true,
        true
    ),
    (
        'hr',
        'employee',
        'view_all',
        'hr.employee.view_all',
        'مشاهده تمام کارمندان',
        'View All Employees',
        'Allows viewing employee records within authorized organizational scope.',
        true,
        true
    ),
    (
        'hr',
        'employee',
        'create',
        'hr.employee.create',
        'ایجاد کارمند',
        'Create Employee',
        'Allows creation of employee records.',
        true,
        true
    ),
    (
        'hr',
        'employee',
        'update',
        'hr.employee.update',
        'ویرایش معلومات کارمند',
        'Update Employee',
        'Allows updating employee records within authorized scope.',
        true,
        true
    ),
    (
        'hr',
        'employee',
        'deactivate',
        'hr.employee.deactivate',
        'غیرفعال‌سازی کارمند',
        'Deactivate Employee',
        'Allows deactivation of an employee without deleting historical records.',
        true,
        true
    ),

    -- =====================================================
    -- ATTENDANCE
    -- =====================================================
    (
        'hr',
        'attendance',
        'view_self',
        'hr.attendance.view_self',
        'مشاهده حاضری خود',
        'View Own Attendance',
        'Allows an employee to view their own attendance records.',
        true,
        true
    ),
    (
        'hr',
        'attendance',
        'view_team',
        'hr.attendance.view_team',
        'مشاهده حاضری تیم',
        'View Team Attendance',
        'Allows managers to view attendance within authorized team scope.',
        true,
        true
    ),
    (
        'hr',
        'attendance',
        'view_all',
        'hr.attendance.view_all',
        'مشاهده تمام حاضری‌ها',
        'View All Attendance',
        'Allows HR users to view attendance within authorized organizational scope.',
        true,
        true
    ),
    (
        'hr',
        'attendance',
        'manage',
        'hr.attendance.manage',
        'مدیریت حاضری',
        'Manage Attendance',
        'Allows authorized HR staff to create or correct attendance records.',
        true,
        true
    ),
    (
        'hr',
        'attendance',
        'approve',
        'hr.attendance.approve',
        'تأیید اصلاحات حاضری',
        'Approve Attendance Adjustments',
        'Allows approval of attendance corrections or adjustments.',
        true,
        true
    ),

    -- =====================================================
    -- LEAVE
    -- =====================================================
    (
        'hr',
        'leave',
        'request',
        'hr.leave.request',
        'درخواست رخصتی',
        'Request Leave',
        'Allows an employee to submit leave requests.',
        true,
        true
    ),
    (
        'hr',
        'leave',
        'view_self',
        'hr.leave.view_self',
        'مشاهده رخصتی خود',
        'View Own Leave',
        'Allows an employee to view their own leave records and balances.',
        true,
        true
    ),
    (
        'hr',
        'leave',
        'view_team',
        'hr.leave.view_team',
        'مشاهده رخصتی تیم',
        'View Team Leave',
        'Allows managers to view leave requests within assigned team scope.',
        true,
        true
    ),
    (
        'hr',
        'leave',
        'approve_team',
        'hr.leave.approve_team',
        'تأیید رخصتی تیم',
        'Approve Team Leave',
        'Allows authorized managers to approve leave requests for their team.',
        true,
        true
    ),
    (
        'hr',
        'leave',
        'manage',
        'hr.leave.manage',
        'مدیریت رخصتی',
        'Manage Leave',
        'Allows HR staff to manage leave policies, balances, and records.',
        true,
        true
    ),
    (
        'hr',
        'leave',
        'approve_final',
        'hr.leave.approve_final',
        'تأیید نهایی رخصتی',
        'Final Leave Approval',
        'Allows final approval of leave when a higher-level workflow requires it.',
        true,
        true
    ),

    -- =====================================================
    -- PAYROLL
    -- =====================================================
    (
        'payroll',
        'payroll',
        'view',
        'payroll.payroll.view',
        'مشاهده معاشات',
        'View Payroll',
        'Allows viewing payroll information within authorized scope.',
        true,
        true
    ),
    (
        'payroll',
        'payroll',
        'prepare',
        'payroll.payroll.prepare',
        'آماده‌سازی معاشات',
        'Prepare Payroll',
        'Allows creation and preparation of payroll runs before processing.',
        true,
        true
    ),
    (
        'payroll',
        'payroll',
        'process',
        'payroll.payroll.process',
        'پردازش معاشات',
        'Process Payroll',
        'Allows execution of payroll calculation and processing.',
        true,
        true
    ),
    (
        'payroll',
        'payroll',
        'review',
        'payroll.payroll.review',
        'بازبینی معاشات',
        'Review Payroll',
        'Allows formal review of processed payroll before approval.',
        true,
        true
    ),
    (
        'payroll',
        'payroll',
        'approve',
        'payroll.payroll.approve',
        'تأیید معاشات',
        'Approve Payroll',
        'Allows payroll approval after processing and review.',
        true,
        true
    ),
    (
        'payroll',
        'payroll',
        'mark_paid',
        'payroll.payroll.mark_paid',
        'ثبت پرداخت معاش',
        'Mark Payroll Paid',
        'Allows authorized users to mark approved payroll payments as paid.',
        true,
        true
    ),
    (
        'payroll',
        'payroll',
        'cancel',
        'payroll.payroll.cancel',
        'لغو معاشات',
        'Cancel Payroll',
        'Allows cancellation of a payroll run according to approval rules.',
        true,
        true
    ),

    -- =====================================================
    -- PAYSLIP
    -- =====================================================
    (
        'payroll',
        'payslip',
        'view_self',
        'payroll.payslip.view_self',
        'مشاهده فیش معاش خود',
        'View Own Payslip',
        'Allows an employee to view only their own authorized payslips.',
        true,
        true
    ),
    (
        'payroll',
        'payslip',
        'view_all',
        'payroll.payslip.view_all',
        'مشاهده فیش‌های معاش',
        'View Payslips',
        'Allows authorized payroll or HR users to view payslips within scope.',
        true,
        true
    ),
    (
        'payroll',
        'payslip',
        'generate',
        'payroll.payslip.generate',
        'ایجاد فیش معاش',
        'Generate Payslip',
        'Allows generation of payslips for eligible paid payroll records.',
        true,
        true
    ),
    (
        'payroll',
        'payslip',
        'deliver',
        'payroll.payslip.deliver',
        'تحویل فیش معاش',
        'Deliver Payslip',
        'Allows marking or managing payslip delivery to employees.',
        true,
        true
    ),

    -- =====================================================
    -- REPORTS
    -- =====================================================
    (
        'reports',
        'hr_reports',
        'view',
        'reports.hr_reports.view',
        'مشاهده گزارش‌های منابع بشری',
        'View HR Reports',
        'Allows viewing authorized HR reports and dashboards.',
        true,
        true
    ),
    (
        'reports',
        'payroll_reports',
        'view',
        'reports.payroll_reports.view',
        'مشاهده گزارش‌های معاشات',
        'View Payroll Reports',
        'Allows viewing authorized payroll reports and summaries.',
        true,
        true
    ),
    (
        'reports',
        'executive_reports',
        'view',
        'reports.executive_reports.view',
        'مشاهده گزارش‌های مدیریتی',
        'View Executive Reports',
        'Allows viewing high-level executive HR and payroll reports.',
        true,
        true
    ),
    (
        'reports',
        'exports',
        'export',
        'reports.exports.export',
        'خروجی گزارش',
        'Export Reports',
        'Allows exporting authorized reports to approved formats.',
        true,
        true
    ),

    -- =====================================================
    -- USER ROLES / SECURITY
    -- =====================================================
    (
        'security',
        'user_roles',
        'view',
        'security.user_roles.view',
        'مشاهده نقش‌های کاربران',
        'View User Roles',
        'Allows viewing role assignments within authorized scope.',
        true,
        true
    ),
    (
        'security',
        'user_roles',
        'assign',
        'security.user_roles.assign',
        'تفویض نقش',
        'Assign User Role',
        'Allows role assignment subject to scope, authority and approval rules.',
        true,
        true
    ),
    (
        'security',
        'user_roles',
        'revoke',
        'security.user_roles.revoke',
        'لغو نقش',
        'Revoke User Role',
        'Allows revoking an assigned role subject to authorization controls.',
        true,
        true
    ),
    (
        'security',
        'user_roles',
        'approve_sensitive',
        'security.user_roles.approve_sensitive',
        'تأیید نقش حساس',
        'Approve Sensitive Role Assignment',
        'Allows approval of sensitive role assignments.',
        true,
        true
    ),

    -- =====================================================
    -- ORGANIZATION
    -- =====================================================
    (
        'organization',
        'structure',
        'view',
        'organization.structure.view',
        'مشاهده ساختار سازمانی',
        'View Organization Structure',
        'Allows viewing branches, departments, positions and related structure.',
        true,
        true
    ),
    (
        'organization',
        'structure',
        'manage',
        'organization.structure.manage',
        'مدیریت ساختار سازمانی',
        'Manage Organization Structure',
        'Allows authorized management of branches, departments and positions.',
        true,
        true
    ),
    (
        'organization',
        'settings',
        'manage',
        'organization.settings.manage',
        'مدیریت تنظیمات سازمان',
        'Manage Organization Settings',
        'Allows authorized management of organization-level HR settings.',
        true,
        true
    ),

    -- =====================================================
    -- AUDIT
    -- =====================================================
    (
        'security',
        'audit',
        'view_hr',
        'security.audit.view_hr',
        'مشاهده رویدادهای HR',
        'View HR Audit',
        'Allows viewing HR-related audit events within authorized scope.',
        true,
        true
    ),
    (
        'security',
        'audit',
        'view_payroll',
        'security.audit.view_payroll',
        'مشاهده رویدادهای معاشات',
        'View Payroll Audit',
        'Allows viewing payroll-related audit events.',
        true,
        true
    ),
    (
        'security',
        'audit',
        'view_all',
        'security.audit.view_all',
        'مشاهده کامل Audit',
        'View Full Audit',
        'Allows viewing the full authorized audit trail.',
        true,
        true
    )

ON CONFLICT (code) DO UPDATE
SET
    module = EXCLUDED.module,
    resource = EXCLUDED.resource,
    action = EXCLUDED.action,
    name = EXCLUDED.name,
    name_en = EXCLUDED.name_en,
    description = EXCLUDED.description,
    is_system_permission = EXCLUDED.is_system_permission,
    is_active = EXCLUDED.is_active,
    updated_at = now();
-- =========================================================
-- PLATFORM SYSTEM ADMIN ROLE
-- Separate from company/business authority
-- =========================================================

INSERT INTO public.roles (
    code,
    name,
    name_en,
    description,
    hierarchy_level,
    is_system_role,
    is_active
)
VALUES (
    'system_admin',
    'مدیر سیستم',
    'System Administrator',
    'Technical platform administrator. This role is separate from company business authority and is intended for system administration, security and technical operations.',
    1,
    true,
    true
)
ON CONFLICT (code) DO UPDATE
SET
    name = EXCLUDED.name,
    name_en = EXCLUDED.name_en,
    description = EXCLUDED.description,
    hierarchy_level = EXCLUDED.hierarchy_level,
    is_system_role = EXCLUDED.is_system_role,
    is_active = EXCLUDED.is_active,
    updated_at = now();

    -- =========================================================
-- RBAC V1 ROLE-PERMISSION MATRIX
-- Least Privilege + Separation of Duties
-- =========================================================
-- =========================================================
-- EMPLOYEE
-- Self-service only
-- =========================================================

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
JOIN public.permissions p
    ON p.code IN (
        'hr.employee.view_self',
        'hr.attendance.view_self',
        'hr.leave.request',
        'hr.leave.view_self',
        'payroll.payslip.view_self',
        'organization.structure.view'
    )
WHERE r.code = 'employee'
ON CONFLICT (role_id, permission_id)
DO UPDATE SET
    granted = EXCLUDED.granted;


-- =========================================================
-- DEPARTMENT MANAGER
-- Department/team scoped authority
-- =========================================================

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
JOIN public.permissions p
    ON p.code IN (
        -- Own records
        'hr.employee.view_self',
        'hr.attendance.view_self',
        'hr.leave.request',
        'hr.leave.view_self',
        'payroll.payslip.view_self',

        -- Team / department
        'hr.employee.view_team',
        'hr.attendance.view_team',
        'hr.leave.view_team',
        'hr.leave.approve_team',

        -- Organization / reporting
        'organization.structure.view',
        'reports.hr_reports.view'
    )
WHERE r.code = 'department_manager'
ON CONFLICT (role_id, permission_id)
DO UPDATE SET
    granted = EXCLUDED.granted;

    -- =========================================================
-- HR OFFICER
-- Operational HR permissions within authorized scope
-- =========================================================

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
JOIN public.permissions p
    ON p.code IN (
        -- Own access
        'hr.employee.view_self',
        'hr.attendance.view_self',
        'hr.leave.request',
        'hr.leave.view_self',
        'payroll.payslip.view_self',

        -- HR operational access
        'hr.employee.view_all',
        'hr.employee.create',
        'hr.employee.update',
        'hr.attendance.view_all',
        'hr.attendance.manage',
        'hr.leave.view_team',
        'hr.leave.manage',

        -- Reports / organization
        'reports.hr_reports.view',
        'organization.structure.view',

        -- Limited audit
        'security.audit.view_hr'
    )
WHERE r.code = 'hr_officer'
ON CONFLICT (role_id, permission_id)
DO UPDATE SET
    granted = EXCLUDED.granted;


-- =========================================================
-- PAYROLL OFFICER
-- Payroll preparation and processing without final approval
-- =========================================================

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
JOIN public.permissions p
    ON p.code IN (
        -- Own access
        'hr.employee.view_self',
        'hr.attendance.view_self',
        'hr.leave.request',
        'hr.leave.view_self',
        'payroll.payslip.view_self',

        -- Required employee / attendance / leave visibility
        'hr.employee.view_all',
        'hr.attendance.view_all',
        'hr.leave.view_team',

        -- Payroll operations
        'payroll.payroll.view',
        'payroll.payroll.prepare',
        'payroll.payroll.process',
        'payroll.payroll.review',

        -- Payslip operations
        'payroll.payslip.view_all',
        'payroll.payslip.generate',
        'payroll.payslip.deliver',

        -- Reports
        'reports.payroll_reports.view',

        -- Organization / audit
        'organization.structure.view',
        'security.audit.view_payroll'
    )
WHERE r.code = 'payroll_officer'
ON CONFLICT (role_id, permission_id)
DO UPDATE SET
    granted = EXCLUDED.granted;

    -- =========================================================
-- HR MANAGER
-- HR management and approval authority within scope
-- =========================================================

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
JOIN public.permissions p
    ON p.code IN (
        -- Own access
        'hr.employee.view_self',
        'hr.attendance.view_self',
        'hr.leave.request',
        'hr.leave.view_self',
        'payroll.payslip.view_self',

        -- HR management
        'hr.employee.view_all',
        'hr.employee.create',
        'hr.employee.update',
        'hr.employee.deactivate',

        'hr.attendance.view_all',
        'hr.attendance.manage',
        'hr.attendance.approve',

        'hr.leave.view_team',
        'hr.leave.approve_team',
        'hr.leave.manage',
        'hr.leave.approve_final',

        -- Reports
        'reports.hr_reports.view',
        'reports.exports.export',

        -- Organization
        'organization.structure.view',

        -- Security visibility
        'security.user_roles.view',

        -- Audit
        'security.audit.view_hr'
    )
WHERE r.code = 'hr_manager'
ON CONFLICT (role_id, permission_id)
DO UPDATE SET
    granted = EXCLUDED.granted;


-- =========================================================
-- PAYROLL MANAGER
-- Payroll control, review and approval authority
-- =========================================================

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
JOIN public.permissions p
    ON p.code IN (
        -- Own access
        'hr.employee.view_self',
        'hr.attendance.view_self',
        'hr.leave.request',
        'hr.leave.view_self',
        'payroll.payslip.view_self',

        -- Required data visibility
        'hr.employee.view_all',
        'hr.attendance.view_all',
        'hr.leave.view_team',

        -- Payroll management
        'payroll.payroll.view',
        'payroll.payroll.prepare',
        'payroll.payroll.process',
        'payroll.payroll.review',
        'payroll.payroll.approve',
        'payroll.payroll.mark_paid',
        'payroll.payroll.cancel',

        -- Payslips
        'payroll.payslip.view_all',
        'payroll.payslip.generate',
        'payroll.payslip.deliver',

        -- Reports
        'reports.payroll_reports.view',
        'reports.exports.export',

        -- Organization / security visibility
        'organization.structure.view',
        'security.user_roles.view',

        -- Audit
        'security.audit.view_payroll'
    )
WHERE r.code = 'payroll_manager'
ON CONFLICT (role_id, permission_id)
DO UPDATE SET
    granted = EXCLUDED.granted;

    -- =========================================================
-- HR DIRECTOR
-- Senior HR governance and high-level approval authority
-- =========================================================

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
JOIN public.permissions p
    ON p.code IN (
        -- Own access
        'hr.employee.view_self',
        'hr.attendance.view_self',
        'hr.leave.request',
        'hr.leave.view_self',
        'payroll.payslip.view_self',

        -- Full HR authority
        'hr.employee.view_all',
        'hr.employee.create',
        'hr.employee.update',
        'hr.employee.deactivate',

        'hr.attendance.view_all',
        'hr.attendance.manage',
        'hr.attendance.approve',

        'hr.leave.view_team',
        'hr.leave.approve_team',
        'hr.leave.manage',
        'hr.leave.approve_final',

        -- Reporting
        'reports.hr_reports.view',
        'reports.executive_reports.view',
        'reports.exports.export',

        -- Organization
        'organization.structure.view',
        'organization.structure.manage',
        'organization.settings.manage',

        -- Role governance
        'security.user_roles.view',
        'security.user_roles.assign',
        'security.user_roles.revoke',

        -- Audit
        'security.audit.view_hr'
    )
WHERE r.code = 'hr_director'
ON CONFLICT (role_id, permission_id)
DO UPDATE SET
    granted = EXCLUDED.granted;

    -- =========================================================
-- COMPANY VICE PRESIDENT
-- Senior delegated business authority
-- =========================================================

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
JOIN public.permissions p
    ON p.code IN (
        -- Own access
        'hr.employee.view_self',
        'hr.attendance.view_self',
        'hr.leave.request',
        'hr.leave.view_self',
        'payroll.payslip.view_self',

        -- Executive visibility
        'hr.employee.view_all',
        'hr.attendance.view_all',
        'hr.leave.view_team',

        -- Payroll oversight
        'payroll.payroll.view',
        'payroll.payroll.review',
        'payroll.payroll.approve',

        -- Payslips / reports
        'payroll.payslip.view_all',
        'reports.hr_reports.view',
        'reports.payroll_reports.view',
        'reports.executive_reports.view',
        'reports.exports.export',

        -- Organization
        'organization.structure.view',

        -- Security visibility
        'security.user_roles.view',

        -- Audit
        'security.audit.view_hr',
        'security.audit.view_payroll'
    )
WHERE r.code = 'company_vice_president'
ON CONFLICT (role_id, permission_id)
DO UPDATE SET
    granted = EXCLUDED.granted;


-- =========================================================
-- COMPANY PRESIDENT
-- Highest company-level business authority
-- =========================================================

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
JOIN public.permissions p
    ON p.code IN (
        -- Own access
        'hr.employee.view_self',
        'hr.attendance.view_self',
        'hr.leave.request',
        'hr.leave.view_self',
        'payroll.payslip.view_self',

        -- Executive HR visibility / authority
        'hr.employee.view_all',
        'hr.employee.create',
        'hr.employee.update',
        'hr.employee.deactivate',

        'hr.attendance.view_all',
        'hr.attendance.approve',

        'hr.leave.view_team',
        'hr.leave.approve_team',
        'hr.leave.approve_final',

        -- Payroll executive authority
        'payroll.payroll.view',
        'payroll.payroll.review',
        'payroll.payroll.approve',
        'payroll.payroll.mark_paid',
        'payroll.payroll.cancel',

        -- Payslips / reports
        'payroll.payslip.view_all',
        'reports.hr_reports.view',
        'reports.payroll_reports.view',
        'reports.executive_reports.view',
        'reports.exports.export',

        -- Organization
        'organization.structure.view',
        'organization.structure.manage',
        'organization.settings.manage',

        -- Role governance
        'security.user_roles.view',
        'security.user_roles.assign',
        'security.user_roles.revoke',
        'security.user_roles.approve_sensitive',

        -- Audit
        'security.audit.view_hr',
        'security.audit.view_payroll',
        'security.audit.view_all'
    )
WHERE r.code = 'company_president'
ON CONFLICT (role_id, permission_id)
DO UPDATE SET
    granted = EXCLUDED.granted;

    -- =========================================================
-- SYSTEM ADMIN
-- Technical platform administration
-- Separate from company business authority
-- =========================================================

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
JOIN public.permissions p
    ON p.code IN (
        -- Security / access administration
        'security.user_roles.view',
        'security.user_roles.assign',
        'security.user_roles.revoke',

        -- Organization technical visibility
        'organization.structure.view',

        -- Audit
        'security.audit.view_all'
    )
WHERE r.code = 'system_admin'
ON CONFLICT (role_id, permission_id)
DO UPDATE SET
    granted = EXCLUDED.granted;