-- ============================================================
-- HR Permission Delegation V1
-- Effective Access / Temporary Delegation
-- ============================================================

-- ------------------------------------------------------------
-- 1. Permission Delegations
-- ------------------------------------------------------------

CREATE TABLE public.permission_delegations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    delegator_profile_id uuid NOT NULL
        REFERENCES public.profiles(id),

    delegatee_profile_id uuid NOT NULL
        REFERENCES public.profiles(id),

    permission_id uuid NOT NULL
        REFERENCES public.permissions(id),

    -- Optional organizational scope
    branch_id uuid NULL
        REFERENCES public.branches(id),

    department_id uuid NULL
        REFERENCES public.departments(id),

    starts_at timestamptz NOT NULL DEFAULT now(),
    ends_at timestamptz NULL,

    is_active boolean NOT NULL DEFAULT true,

    delegation_reason text NULL,
    notes text NULL,

    -- Who approved the delegation.
    -- Uses auth.users because existing user_roles.assigned_by
    -- follows the same identity model.
    approved_by uuid NULL
        REFERENCES auth.users(id),

    approved_at timestamptz NULL,

    revoked_at timestamptz NULL,
    revoked_by uuid NULL
        REFERENCES auth.users(id),

    revocation_reason text NULL,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT permission_delegations_not_self
        CHECK (delegator_profile_id <> delegatee_profile_id),

    CONSTRAINT permission_delegations_dates_check
        CHECK (ends_at IS NULL OR ends_at > starts_at),

    CONSTRAINT permission_delegations_revocation_check
        CHECK (
            revoked_at IS NULL
            OR revoked_at >= starts_at
        )
);


-- Prevent exact duplicate active delegation records

CREATE UNIQUE INDEX permission_delegations_active_unique
ON public.permission_delegations (
    delegator_profile_id,
    delegatee_profile_id,
    permission_id,
    COALESCE(branch_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(department_id, '00000000-0000-0000-0000-000000000000'::uuid),
    starts_at
)
WHERE is_active = true
  AND revoked_at IS NULL;

CREATE INDEX permission_delegations_delegatee_idx
ON public.permission_delegations (
    delegatee_profile_id,
    permission_id
);

CREATE INDEX permission_delegations_delegator_idx
ON public.permission_delegations (
    delegator_profile_id
);

CREATE INDEX permission_delegations_active_dates_idx
ON public.permission_delegations (
    is_active,
    starts_at,
    ends_at
);


-- ------------------------------------------------------------
-- 2. Permission Self-Suspensions
-- ------------------------------------------------------------

CREATE TABLE public.permission_suspensions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    profile_id uuid NOT NULL
        REFERENCES public.profiles(id),

    permission_id uuid NOT NULL
        REFERENCES public.permissions(id),

    branch_id uuid NULL
        REFERENCES public.branches(id),

    department_id uuid NULL
        REFERENCES public.departments(id),

    starts_at timestamptz NOT NULL DEFAULT now(),
    ends_at timestamptz NULL,

    is_active boolean NOT NULL DEFAULT true,

    suspension_reason text NULL,

    created_by uuid NULL
        REFERENCES auth.users(id),

    revoked_at timestamptz NULL,

    revoked_by uuid NULL
        REFERENCES auth.users(id),

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT permission_suspensions_dates_check
        CHECK (ends_at IS NULL OR ends_at > starts_at)
);


CREATE INDEX permission_suspensions_profile_idx
ON public.permission_suspensions (
    profile_id,
    permission_id
);

CREATE INDEX permission_suspensions_active_dates_idx
ON public.permission_suspensions (
    is_active,
    starts_at,
    ends_at
);


-- ------------------------------------------------------------
-- 3. Enable RLS
-- Policies will be added separately after access-rule testing.
-- ------------------------------------------------------------

ALTER TABLE public.permission_delegations
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.permission_suspensions
ENABLE ROW LEVEL SECURITY;