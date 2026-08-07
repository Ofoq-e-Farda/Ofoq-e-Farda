-- =========================================================
-- Ofoq ERP - HRMS v1.0
-- Attendance, Leave & Performance
-- =========================================================


-- =========================================================
-- 1. ATTENDANCE RECORDS
-- =========================================================

CREATE TABLE public.attendance_records (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    employee_profile_id uuid NOT NULL,

    attendance_date date NOT NULL,

    check_in_time timestamptz,

    check_out_time timestamptz,

    total_hours numeric(6,2),

    overtime_hours numeric(6,2) NOT NULL DEFAULT 0,

    attendance_status text NOT NULL DEFAULT 'present',

    remarks text,

    created_by uuid,

    updated_by uuid,

    created_at timestamptz NOT NULL DEFAULT now(),

    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT attendance_records_employee_profile_id_fkey
        FOREIGN KEY (employee_profile_id)
        REFERENCES public.employee_profiles(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT attendance_records_created_by_fkey
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON DELETE SET NULL,

    CONSTRAINT attendance_records_updated_by_fkey
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON DELETE SET NULL,

    CONSTRAINT attendance_records_employee_date_unique
        UNIQUE (employee_profile_id, attendance_date),

    CONSTRAINT attendance_records_time_check
        CHECK (
            check_out_time IS NULL
            OR check_in_time IS NULL
            OR check_out_time >= check_in_time
        ),

    CONSTRAINT attendance_records_total_hours_check
        CHECK (
            total_hours IS NULL
            OR total_hours >= 0
        ),

    CONSTRAINT attendance_records_overtime_hours_check
        CHECK (overtime_hours >= 0),

    CONSTRAINT attendance_records_status_check
        CHECK (
            attendance_status IN (
                'present',
                'absent',
                'late',
                'half_day',
                'leave',
                'holiday',
                'remote',
                'other'
            )
        )
);

ALTER TABLE public.attendance_records
ENABLE ROW LEVEL SECURITY;

CREATE INDEX attendance_records_employee_idx
ON public.attendance_records (employee_profile_id);

CREATE INDEX attendance_records_date_idx
ON public.attendance_records (attendance_date);

CREATE INDEX attendance_records_status_idx
ON public.attendance_records (attendance_status);

CREATE INDEX attendance_records_employee_date_idx
ON public.attendance_records (employee_profile_id, attendance_date);

CREATE TRIGGER attendance_records_set_updated_at
BEFORE UPDATE ON public.attendance_records
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =========================================================
-- 2. LEAVE TYPES
-- =========================================================

CREATE TABLE public.leave_types (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    code text NOT NULL UNIQUE,

    name text NOT NULL,

    name_en text,

    description text,

    is_paid boolean NOT NULL DEFAULT true,

    default_days numeric(6,2) NOT NULL DEFAULT 0,

    requires_approval boolean NOT NULL DEFAULT true,

    requires_document boolean NOT NULL DEFAULT false,

    display_order integer NOT NULL DEFAULT 0,

    is_active boolean NOT NULL DEFAULT true,

    created_by uuid,

    updated_by uuid,

    created_at timestamptz NOT NULL DEFAULT now(),

    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT leave_types_code_format_check
        CHECK (code ~ '^[A-Z0-9_]+$'),

    CONSTRAINT leave_types_default_days_check
        CHECK (default_days >= 0),

    CONSTRAINT leave_types_display_order_check
        CHECK (display_order >= 0),

    CONSTRAINT leave_types_created_by_fkey
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON DELETE SET NULL,

    CONSTRAINT leave_types_updated_by_fkey
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON DELETE SET NULL
);

ALTER TABLE public.leave_types
ENABLE ROW LEVEL SECURITY;

CREATE INDEX leave_types_active_order_idx
ON public.leave_types (is_active, display_order);

CREATE TRIGGER leave_types_set_updated_at
BEFORE UPDATE ON public.leave_types
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =========================================================
-- 3. EMPLOYEE LEAVES
-- =========================================================

CREATE TABLE public.employee_leaves (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    employee_profile_id uuid NOT NULL,

    leave_type_id uuid NOT NULL,

    start_date date NOT NULL,

    end_date date NOT NULL,

    total_days numeric(6,2) NOT NULL,

    reason text,

    status text NOT NULL DEFAULT 'pending',

    approved_by uuid,

    approved_at timestamptz,

    rejection_reason text,

    storage_bucket text,

    storage_path text,

    remarks text,

    created_by uuid,

    updated_by uuid,

    created_at timestamptz NOT NULL DEFAULT now(),

    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT employee_leaves_employee_profile_id_fkey
        FOREIGN KEY (employee_profile_id)
        REFERENCES public.employee_profiles(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT employee_leaves_leave_type_id_fkey
        FOREIGN KEY (leave_type_id)
        REFERENCES public.leave_types(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT employee_leaves_approved_by_fkey
        FOREIGN KEY (approved_by)
        REFERENCES auth.users(id)
        ON DELETE SET NULL,

    CONSTRAINT employee_leaves_created_by_fkey
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON DELETE SET NULL,

    CONSTRAINT employee_leaves_updated_by_fkey
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON DELETE SET NULL,

    CONSTRAINT employee_leaves_dates_check
        CHECK (end_date >= start_date),

    CONSTRAINT employee_leaves_total_days_check
        CHECK (total_days > 0),

    CONSTRAINT employee_leaves_status_check
        CHECK (
            status IN (
                'pending',
                'approved',
                'rejected',
                'cancelled'
            )
        ),

    CONSTRAINT employee_leaves_approval_check
        CHECK (
            status <> 'approved'
            OR (approved_by IS NOT NULL AND approved_at IS NOT NULL)
        ),

    CONSTRAINT employee_leaves_rejection_check
        CHECK (
            status <> 'rejected'
            OR rejection_reason IS NOT NULL
        ),

    CONSTRAINT employee_leaves_storage_check
        CHECK (
            (storage_bucket IS NULL AND storage_path IS NULL)
            OR
            (storage_bucket IS NOT NULL AND storage_path IS NOT NULL)
        )
);

ALTER TABLE public.employee_leaves
ENABLE ROW LEVEL SECURITY;

CREATE INDEX employee_leaves_employee_idx
ON public.employee_leaves (employee_profile_id);

CREATE INDEX employee_leaves_type_idx
ON public.employee_leaves (leave_type_id);

CREATE INDEX employee_leaves_status_idx
ON public.employee_leaves (status);

CREATE INDEX employee_leaves_dates_idx
ON public.employee_leaves (start_date, end_date);

CREATE INDEX employee_leaves_approver_idx
ON public.employee_leaves (approved_by);

CREATE TRIGGER employee_leaves_set_updated_at
BEFORE UPDATE ON public.employee_leaves
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =========================================================
-- 4. PERFORMANCE REVIEWS
-- =========================================================

CREATE TABLE public.performance_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    employee_profile_id uuid NOT NULL,

    reviewer_user_id uuid,

    review_period_start date NOT NULL,

    review_period_end date NOT NULL,

    review_date date,

    overall_score numeric(5,2),

    status text NOT NULL DEFAULT 'draft',

    strengths text,

    areas_for_improvement text,

    goals text,

    manager_comments text,

    employee_comments text,

    acknowledged_by_employee boolean NOT NULL DEFAULT false,

    acknowledged_at timestamptz,

    created_by uuid,

    updated_by uuid,

    created_at timestamptz NOT NULL DEFAULT now(),

    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT performance_reviews_employee_profile_id_fkey
        FOREIGN KEY (employee_profile_id)
        REFERENCES public.employee_profiles(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT performance_reviews_reviewer_user_id_fkey
        FOREIGN KEY (reviewer_user_id)
        REFERENCES auth.users(id)
        ON DELETE SET NULL,

    CONSTRAINT performance_reviews_created_by_fkey
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON DELETE SET NULL,

    CONSTRAINT performance_reviews_updated_by_fkey
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON DELETE SET NULL,

    CONSTRAINT performance_reviews_period_check
        CHECK (review_period_end >= review_period_start),

    CONSTRAINT performance_reviews_score_check
        CHECK (
            overall_score IS NULL
            OR (overall_score >= 0 AND overall_score <= 100)
        ),

    CONSTRAINT performance_reviews_status_check
        CHECK (
            status IN (
                'draft',
                'in_progress',
                'submitted',
                'completed',
                'cancelled'
            )
        ),

    CONSTRAINT performance_reviews_acknowledgement_check
        CHECK (
            acknowledged_by_employee = false
            OR acknowledged_at IS NOT NULL
        )
);

ALTER TABLE public.performance_reviews
ENABLE ROW LEVEL SECURITY;

CREATE INDEX performance_reviews_employee_idx
ON public.performance_reviews (employee_profile_id);

CREATE INDEX performance_reviews_reviewer_idx
ON public.performance_reviews (reviewer_user_id);

CREATE INDEX performance_reviews_status_idx
ON public.performance_reviews (status);

CREATE INDEX performance_reviews_period_idx
ON public.performance_reviews (
    review_period_start,
    review_period_end
);

CREATE TRIGGER performance_reviews_set_updated_at
BEFORE UPDATE ON public.performance_reviews
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();