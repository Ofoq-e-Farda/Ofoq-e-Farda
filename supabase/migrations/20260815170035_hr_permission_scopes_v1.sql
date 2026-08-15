-- ============================================================
-- Ofoq ERP
-- HR RBAC V1 - Explicit Permission Scopes
-- ============================================================

CREATE TABLE public.user_role_permission_scopes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    -- The concrete role assignment of the user
    user_role_id uuid NOT NULL
        REFERENCES public.user_roles(id)
        ON DELETE CASCADE,

    -- Permission being scoped
    permission_id uuid NOT NULL
        REFERENCES public.permissions(id)
        ON DELETE CASCADE,

    -- Explicit organizational scope
    scope_type text NOT NULL,

    branch_id uuid NULL
        REFERENCES public.branches(id),

    department_id uuid NULL
        REFERENCES public.departments(id),

    -- Optional validity window
    starts_at timestamptz NOT NULL DEFAULT now(),
    ends_at timestamptz NULL,

    is_active boolean NOT NULL DEFAULT true,

    -- Audit information
    granted_by uuid NULL
        REFERENCES auth.users(id),

    reason text NULL,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    -- Supported V1 scope types
    CONSTRAINT user_role_permission_scopes_type_check
        CHECK (
            scope_type IN (
                'company',
                'branch',
                'department',
                'self'
            )
        ),

    -- Validity window
    CONSTRAINT user_role_permission_scopes_dates_check
        CHECK (
            ends_at IS NULL
            OR ends_at > starts_at
        ),

    -- Scope shape must be explicit and valid
    CONSTRAINT user_role_permission_scopes_shape_check
        CHECK (
            (
                scope_type = 'company'
                AND branch_id IS NULL
                AND department_id IS NULL
            )
            OR
            (
                scope_type = 'branch'
                AND branch_id IS NOT NULL
                AND department_id IS NULL
            )
            OR
          (
    scope_type = 'department'
    AND branch_id IS NULL
    AND department_id IS NOT NULL
)
            OR
            (
                scope_type = 'self'
                AND branch_id IS NULL
                AND department_id IS NULL
            )
        )
);

-- ============================================================
-- Indexes
-- ============================================================

CREATE INDEX user_role_permission_scopes_user_role_idx
ON public.user_role_permission_scopes (user_role_id);

CREATE INDEX user_role_permission_scopes_permission_idx
ON public.user_role_permission_scopes (permission_id);

CREATE INDEX user_role_permission_scopes_active_idx
ON public.user_role_permission_scopes (
    user_role_id,
    permission_id,
    is_active,
    starts_at,
    ends_at
);

CREATE INDEX user_role_permission_scopes_branch_idx
ON public.user_role_permission_scopes (branch_id)
WHERE branch_id IS NOT NULL;

CREATE INDEX user_role_permission_scopes_department_idx
ON public.user_role_permission_scopes (department_id)
WHERE department_id IS NOT NULL;


-- ============================================================
-- Prevent duplicate active scope grants
-- ============================================================

CREATE UNIQUE INDEX user_role_permission_scopes_active_unique
ON public.user_role_permission_scopes (
    user_role_id,
    permission_id,
    scope_type,
    COALESCE(branch_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(department_id, '00000000-0000-0000-0000-000000000000'::uuid),
    starts_at
)
WHERE is_active = true;


-- ============================================================
-- updated_at trigger
-- ============================================================

CREATE TRIGGER user_role_permission_scopes_set_updated_at
BEFORE UPDATE ON public.user_role_permission_scopes
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE public.user_role_permission_scopes
ENABLE ROW LEVEL SECURITY;