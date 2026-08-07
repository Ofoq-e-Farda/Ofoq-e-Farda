-- =========================================================
-- Ofoq-e-Farda
-- HR v1.0
-- Training, Certifications and Languages
-- =========================================================


-- =========================================================
-- 1. TRAINING PROVIDERS
-- =========================================================

CREATE TABLE public.training_providers (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code          text NOT NULL UNIQUE,
  name          text NOT NULL,
  name_en       text,
  provider_type text NOT NULL DEFAULT 'external',
  country_id    uuid,
  website       text,
  email         text,
  phone         text,
  address       text,
  is_active     boolean NOT NULL DEFAULT true,
  created_by    uuid,
  updated_by    uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT training_providers_code_format_check
    CHECK (code ~ '^[A-Z0-9_]+$'),

  CONSTRAINT training_providers_type_check
    CHECK (
      provider_type IN (
        'internal',
        'external',
        'government',
        'online',
        'other'
      )
    ),

  CONSTRAINT training_providers_country_id_fkey
    FOREIGN KEY (country_id)
    REFERENCES public.countries(id)
    ON UPDATE CASCADE
    ON DELETE SET NULL,

  CONSTRAINT training_providers_created_by_fkey
    FOREIGN KEY (created_by)
    REFERENCES auth.users(id)
    ON DELETE SET NULL,

  CONSTRAINT training_providers_updated_by_fkey
    FOREIGN KEY (updated_by)
    REFERENCES auth.users(id)
    ON DELETE SET NULL
);

ALTER TABLE public.training_providers
ENABLE ROW LEVEL SECURITY;

CREATE INDEX training_providers_active_idx
ON public.training_providers (is_active);

CREATE INDEX training_providers_country_idx
ON public.training_providers (country_id);

CREATE TRIGGER training_providers_set_updated_at
BEFORE UPDATE ON public.training_providers
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =========================================================
-- 2. EMPLOYEE TRAININGS
-- =========================================================

CREATE TABLE public.employee_trainings (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_profile_id   uuid NOT NULL,
  training_provider_id  uuid,
  provider_name_other   text,
  title                 text NOT NULL,
  training_type         text NOT NULL DEFAULT 'course',
  start_date            date,
  end_date              date,
  duration_hours        numeric(8,2),
  status                text NOT NULL DEFAULT 'planned',
  certificate_received  boolean NOT NULL DEFAULT false,
  certificate_number    text,
  cost                  numeric(14,2),
  currency_id           uuid,
  storage_bucket        text,
  storage_path          text,
  notes                 text,
  created_by            uuid,
  updated_by            uuid,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT employee_trainings_employee_profile_id_fkey
    FOREIGN KEY (employee_profile_id)
    REFERENCES public.employee_profiles(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,

  CONSTRAINT employee_trainings_provider_id_fkey
    FOREIGN KEY (training_provider_id)
    REFERENCES public.training_providers(id)
    ON UPDATE CASCADE
    ON DELETE SET NULL,

  CONSTRAINT employee_trainings_currency_id_fkey
    FOREIGN KEY (currency_id)
    REFERENCES public.currencies(id)
    ON UPDATE CASCADE
    ON DELETE SET NULL,

  CONSTRAINT employee_trainings_created_by_fkey
    FOREIGN KEY (created_by)
    REFERENCES auth.users(id)
    ON DELETE SET NULL,

  CONSTRAINT employee_trainings_updated_by_fkey
    FOREIGN KEY (updated_by)
    REFERENCES auth.users(id)
    ON DELETE SET NULL,

  CONSTRAINT employee_trainings_dates_check
    CHECK (
      end_date IS NULL
      OR start_date IS NULL
      OR end_date >= start_date
    ),

  CONSTRAINT employee_trainings_duration_check
    CHECK (
      duration_hours IS NULL
      OR duration_hours >= 0
    ),

  CONSTRAINT employee_trainings_cost_check
    CHECK (
      cost IS NULL
      OR cost >= 0
    ),

  CONSTRAINT employee_trainings_provider_check
    CHECK (
      training_provider_id IS NOT NULL
      OR provider_name_other IS NOT NULL
    ),

  CONSTRAINT employee_trainings_type_check
    CHECK (
      training_type IN (
        'course',
        'workshop',
        'seminar',
        'conference',
        'on_the_job',
        'online',
        'other'
      )
    ),

  CONSTRAINT employee_trainings_status_check
    CHECK (
      status IN (
        'planned',
        'ongoing',
        'completed',
        'cancelled',
        'failed'
      )
    ),

  CONSTRAINT employee_trainings_storage_check
    CHECK (
      (storage_bucket IS NULL AND storage_path IS NULL)
      OR
      (storage_bucket IS NOT NULL AND storage_path IS NOT NULL)
    )
);

ALTER TABLE public.employee_trainings
ENABLE ROW LEVEL SECURITY;

CREATE INDEX employee_trainings_employee_idx
ON public.employee_trainings (employee_profile_id);

CREATE INDEX employee_trainings_provider_idx
ON public.employee_trainings (training_provider_id);

CREATE INDEX employee_trainings_status_idx
ON public.employee_trainings (status);

CREATE INDEX employee_trainings_dates_idx
ON public.employee_trainings (start_date, end_date);

CREATE TRIGGER employee_trainings_set_updated_at
BEFORE UPDATE ON public.employee_trainings
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =========================================================
-- 3. CERTIFICATION TYPES
-- =========================================================

CREATE TABLE public.certification_types (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code             text NOT NULL UNIQUE,
  name             text NOT NULL,
  name_en          text,
  description      text,
  requires_expiry  boolean NOT NULL DEFAULT false,
  is_active        boolean NOT NULL DEFAULT true,
  created_by       uuid,
  updated_by       uuid,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT certification_types_code_format_check
    CHECK (code ~ '^[A-Z0-9_]+$'),

  CONSTRAINT certification_types_created_by_fkey
    FOREIGN KEY (created_by)
    REFERENCES auth.users(id)
    ON DELETE SET NULL,

  CONSTRAINT certification_types_updated_by_fkey
    FOREIGN KEY (updated_by)
    REFERENCES auth.users(id)
    ON DELETE SET NULL
);

ALTER TABLE public.certification_types
ENABLE ROW LEVEL SECURITY;

CREATE INDEX certification_types_active_idx
ON public.certification_types (is_active);

CREATE TRIGGER certification_types_set_updated_at
BEFORE UPDATE ON public.certification_types
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =========================================================
-- 4. EMPLOYEE CERTIFICATIONS
-- =========================================================

CREATE TABLE public.employee_certifications (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_profile_id   uuid NOT NULL,
  certification_type_id uuid NOT NULL,
  certificate_name      text,
  issuing_organization  text,
  certificate_number    text,
  issue_date            date,
  expiry_date           date,
  status                text NOT NULL DEFAULT 'active',
  verification_status   text NOT NULL DEFAULT 'unverified',
  verified_by           uuid,
  verified_at           timestamptz,
  verification_notes    text,
  storage_bucket        text,
  storage_path          text,
  notes                 text,
  created_by            uuid,
  updated_by            uuid,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT employee_certifications_employee_profile_id_fkey
    FOREIGN KEY (employee_profile_id)
    REFERENCES public.employee_profiles(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,

  CONSTRAINT employee_certifications_type_id_fkey
    FOREIGN KEY (certification_type_id)
    REFERENCES public.certification_types(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT employee_certifications_verified_by_fkey
    FOREIGN KEY (verified_by)
    REFERENCES auth.users(id)
    ON DELETE SET NULL,

  CONSTRAINT employee_certifications_created_by_fkey
    FOREIGN KEY (created_by)
    REFERENCES auth.users(id)
    ON DELETE SET NULL,

  CONSTRAINT employee_certifications_updated_by_fkey
    FOREIGN KEY (updated_by)
    REFERENCES auth.users(id)
    ON DELETE SET NULL,

  CONSTRAINT employee_certifications_dates_check
    CHECK (
      expiry_date IS NULL
      OR issue_date IS NULL
      OR expiry_date >= issue_date
    ),

  CONSTRAINT employee_certifications_status_check
    CHECK (
      status IN (
        'active',
        'expired',
        'revoked',
        'pending'
      )
    ),

  CONSTRAINT employee_certifications_verification_status_check
    CHECK (
      verification_status IN (
        'unverified',
        'pending',
        'verified',
        'rejected'
      )
    ),

  CONSTRAINT employee_certifications_verification_check
    CHECK (
      verification_status <> 'verified'
      OR (verified_by IS NOT NULL AND verified_at IS NOT NULL)
    ),

  CONSTRAINT employee_certifications_storage_check
    CHECK (
      (storage_bucket IS NULL AND storage_path IS NULL)
      OR
      (storage_bucket IS NOT NULL AND storage_path IS NOT NULL)
    )
);

ALTER TABLE public.employee_certifications
ENABLE ROW LEVEL SECURITY;

CREATE INDEX employee_certifications_employee_idx
ON public.employee_certifications (employee_profile_id);

CREATE INDEX employee_certifications_type_idx
ON public.employee_certifications (certification_type_id);

CREATE INDEX employee_certifications_status_idx
ON public.employee_certifications (status);

CREATE INDEX employee_certifications_expiry_idx
ON public.employee_certifications (expiry_date);

CREATE INDEX employee_certifications_verification_idx
ON public.employee_certifications (verification_status);

CREATE TRIGGER employee_certifications_set_updated_at
BEFORE UPDATE ON public.employee_certifications
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =========================================================
-- 5. LANGUAGES
-- =========================================================

CREATE TABLE public.languages (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code          text NOT NULL UNIQUE,
  name          text NOT NULL,
  name_en       text,
  display_order integer NOT NULL DEFAULT 0,
  is_active     boolean NOT NULL DEFAULT true,
  created_by    uuid,
  updated_by    uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT languages_code_format_check
    CHECK (code ~ '^[a-z]{2,10}$'),

  CONSTRAINT languages_created_by_fkey
    FOREIGN KEY (created_by)
    REFERENCES auth.users(id)
    ON DELETE SET NULL,

  CONSTRAINT languages_updated_by_fkey
    FOREIGN KEY (updated_by)
    REFERENCES auth.users(id)
    ON DELETE SET NULL
);

ALTER TABLE public.languages
ENABLE ROW LEVEL SECURITY;

CREATE INDEX languages_active_order_idx
ON public.languages (is_active, display_order);

CREATE TRIGGER languages_set_updated_at
BEFORE UPDATE ON public.languages
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =========================================================
-- 6. EMPLOYEE LANGUAGES
-- =========================================================

CREATE TABLE public.employee_languages (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_profile_id uuid NOT NULL,
  language_id         uuid NOT NULL,
  speaking_level      text NOT NULL DEFAULT 'basic',
  listening_level     text NOT NULL DEFAULT 'basic',
  reading_level       text NOT NULL DEFAULT 'basic',
  writing_level       text NOT NULL DEFAULT 'basic',
  is_native           boolean NOT NULL DEFAULT false,
  certificate_name    text,
  certificate_score   text,
  notes               text,
  created_by          uuid,
  updated_by          uuid,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT employee_languages_employee_profile_id_fkey
    FOREIGN KEY (employee_profile_id)
    REFERENCES public.employee_profiles(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,

  CONSTRAINT employee_languages_language_id_fkey
    FOREIGN KEY (language_id)
    REFERENCES public.languages(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT employee_languages_created_by_fkey
    FOREIGN KEY (created_by)
    REFERENCES auth.users(id)
    ON DELETE SET NULL,

  CONSTRAINT employee_languages_updated_by_fkey
    FOREIGN KEY (updated_by)
    REFERENCES auth.users(id)
    ON DELETE SET NULL,

  CONSTRAINT employee_languages_employee_language_unique
    UNIQUE (employee_profile_id, language_id),

  CONSTRAINT employee_languages_speaking_check
    CHECK (
      speaking_level IN (
        'basic',
        'intermediate',
        'advanced',
        'fluent'
      )
    ),

  CONSTRAINT employee_languages_listening_check
    CHECK (
      listening_level IN (
        'basic',
        'intermediate',
        'advanced',
        'fluent'
      )
    ),

  CONSTRAINT employee_languages_reading_check
    CHECK (
      reading_level IN (
        'basic',
        'intermediate',
        'advanced',
        'fluent'
      )
    ),

  CONSTRAINT employee_languages_writing_check
    CHECK (
      writing_level IN (
        'basic',
        'intermediate',
        'advanced',
        'fluent'
      )
    )
);

ALTER TABLE public.employee_languages
ENABLE ROW LEVEL SECURITY;

CREATE INDEX employee_languages_employee_idx
ON public.employee_languages (employee_profile_id);

CREATE INDEX employee_languages_language_idx
ON public.employee_languages (language_id);

CREATE TRIGGER employee_languages_set_updated_at
BEFORE UPDATE ON public.employee_languages
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();