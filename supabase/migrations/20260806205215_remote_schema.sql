-- Migration unit 1: schema_changes
-- Transaction mode: transactional
-- Boundary reason: default

SET check_function_bodies = false;

DROP EXTENSION pg_net;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE UPDATE ON SEQUENCES FROM anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE UPDATE ON SEQUENCES FROM authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE UPDATE ON SEQUENCES FROM service_role;

CREATE FUNCTION public.rls_auto_enable()
  RETURNS event_trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'pg_catalog'
  AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

CREATE FUNCTION public.set_updated_at()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO 'public'
  AS $function$
begin
    new.updated_at = now();
    return new;
end;
$function$;

CREATE TABLE public.assignment_types (
  id            uuid                     DEFAULT gen_random_uuid() NOT NULL,
  code          text                     NOT NULL,
  name          text                     NOT NULL,
  name_en       text,
  description   text,
  display_order integer                  DEFAULT 0 NOT NULL,
  is_active     boolean                  DEFAULT true NOT NULL,
  created_by    uuid,
  updated_by    uuid,
  created_at    timestamp with time zone DEFAULT now() NOT NULL,
  updated_at    timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.assignment_types
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.assignment_types
  ADD CONSTRAINT assignment_types_code_format_check CHECK (code ~ '^[A-Z0-9_]+$'::text);

ALTER TABLE public.assignment_types
  ADD CONSTRAINT assignment_types_code_key UNIQUE (code);

ALTER TABLE public.assignment_types
  ADD CONSTRAINT assignment_types_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.assignment_types
  ADD CONSTRAINT assignment_types_pkey PRIMARY KEY (id);

ALTER TABLE public.assignment_types
  ADD CONSTRAINT assignment_types_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.assignment_types TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.assignment_types TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.assignment_types TO service_role;

CREATE INDEX assignment_types_active_order_idx ON public.assignment_types (is_active, display_order);

CREATE TRIGGER assignment_types_set_updated_at
  BEFORE UPDATE ON public.assignment_types
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.audit_logs (
  id               uuid                     DEFAULT gen_random_uuid() NOT NULL,
  actor_user_id    uuid,
  actor_profile_id uuid,
  branch_id        uuid,
  department_id    uuid,
  module           text                     NOT NULL,
  action           text                     NOT NULL,
  entity_table     text,
  entity_id        uuid,
  event_status     text                     DEFAULT 'success'::text NOT NULL,
  severity         text                     DEFAULT 'info'::text NOT NULL,
  source           text                     DEFAULT 'system'::text NOT NULL,
  description      text,
  old_data         jsonb,
  new_data         jsonb,
  metadata         jsonb                    DEFAULT '{}'::jsonb NOT NULL,
  ip_address       inet,
  user_agent       text,
  device_info      text,
  session_id       text,
  request_id       uuid,
  correlation_id   uuid,
  occurred_at      timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.audit_logs
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.audit_logs
  ADD CONSTRAINT audit_logs_action_format_check CHECK (action ~ '^[a-z0-9_.]+$'::text);

ALTER TABLE public.audit_logs
  ADD CONSTRAINT audit_logs_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.audit_logs
  ADD CONSTRAINT audit_logs_entity_check CHECK (entity_table IS NULL AND entity_id IS NULL OR entity_table IS NOT NULL);

ALTER TABLE public.audit_logs
  ADD CONSTRAINT audit_logs_event_status_check CHECK (event_status = ANY (ARRAY['success'::text, 'failed'::text, 'denied'::text, 'warning'::text]));

ALTER TABLE public.audit_logs
  ADD CONSTRAINT audit_logs_module_format_check CHECK (module ~ '^[a-z0-9_]+$'::text);

ALTER TABLE public.audit_logs
  ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);

ALTER TABLE public.audit_logs
  ADD CONSTRAINT audit_logs_severity_check CHECK (severity = ANY (ARRAY['info'::text, 'warning'::text, 'critical'::text]));

ALTER TABLE public.audit_logs
  ADD CONSTRAINT audit_logs_source_check CHECK (source = ANY (ARRAY['system'::text, 'database'::text, 'flutter'::text, 'web'::text, 'api'::text, 'admin'::text]));

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.audit_logs TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.audit_logs TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.audit_logs TO service_role;

CREATE INDEX audit_logs_entity_idx ON public.audit_logs (entity_table, entity_id);

CREATE INDEX audit_logs_occurred_at_idx ON public.audit_logs (occurred_at DESC);

CREATE INDEX audit_logs_status_severity_idx ON public.audit_logs (event_status, severity);

CREATE INDEX audit_logs_metadata_gin_idx ON public.audit_logs USING gin (metadata);

CREATE INDEX audit_logs_request_id_idx ON public.audit_logs (request_id);

CREATE INDEX audit_logs_actor_user_idx ON public.audit_logs (actor_user_id);

CREATE INDEX audit_logs_actor_profile_idx ON public.audit_logs (actor_profile_id);

CREATE INDEX audit_logs_scope_idx ON public.audit_logs (branch_id, department_id);

CREATE INDEX audit_logs_module_action_idx ON public.audit_logs (module, action);

CREATE TABLE public.banks (
  id            uuid                     DEFAULT gen_random_uuid() NOT NULL,
  code          text                     NOT NULL,
  name          text                     NOT NULL,
  name_en       text,
  short_name    text,
  country_id    uuid,
  swift_code    text,
  website       text,
  contact_phone text,
  email         text,
  address       text,
  display_order integer                  DEFAULT 0 NOT NULL,
  is_active     boolean                  DEFAULT true NOT NULL,
  created_by    uuid,
  updated_by    uuid,
  created_at    timestamp with time zone DEFAULT now() NOT NULL,
  updated_at    timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.banks
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.banks
  ADD CONSTRAINT banks_code_format_check CHECK (code ~ '^[A-Z0-9_]+$'::text);

ALTER TABLE public.banks
  ADD CONSTRAINT banks_code_key UNIQUE (code);

ALTER TABLE public.banks
  ADD CONSTRAINT banks_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.banks
  ADD CONSTRAINT banks_pkey PRIMARY KEY (id);

ALTER TABLE public.banks
  ADD CONSTRAINT banks_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.banks TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.banks TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.banks TO service_role;

CREATE INDEX banks_country_idx ON public.banks (country_id);

CREATE INDEX banks_display_order_idx ON public.banks (display_order);

CREATE INDEX banks_active_idx ON public.banks (is_active);

CREATE TRIGGER banks_set_updated_at
  BEFORE UPDATE ON public.banks
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.branches (
  id          uuid                     DEFAULT gen_random_uuid() NOT NULL,
  province_id uuid                     NOT NULL,
  district_id uuid,
  name        text                     NOT NULL,
  name_en     text,
  address     text,
  phone       text,
  email       text,
  status      text                     DEFAULT 'inactive'::text NOT NULL,
  created_at  timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.branches
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.branches
  ADD CONSTRAINT branches_pkey PRIMARY KEY (id);

ALTER TABLE public.audit_logs
  ADD CONSTRAINT audit_logs_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.branches
  ADD CONSTRAINT branches_status_check CHECK (status = ANY (ARRAY['active'::text, 'inactive'::text, 'suspended'::text]));

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.branches TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.branches TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.branches TO service_role;

CREATE INDEX idx_branches_province_id ON public.branches (province_id);

CREATE INDEX idx_branches_district_id ON public.branches (district_id);

CREATE TABLE public.contract_types (
  id                uuid                     DEFAULT gen_random_uuid() NOT NULL,
  code              text                     NOT NULL,
  name              text                     NOT NULL,
  name_en           text,
  description       text,
  requires_end_date boolean                  DEFAULT true NOT NULL,
  allows_renewal    boolean                  DEFAULT true NOT NULL,
  allows_probation  boolean                  DEFAULT true NOT NULL,
  display_order     integer                  DEFAULT 0 NOT NULL,
  is_active         boolean                  DEFAULT true NOT NULL,
  created_by        uuid,
  updated_by        uuid,
  created_at        timestamp with time zone DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.contract_types
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.contract_types
  ADD CONSTRAINT contract_types_code_format_check CHECK (code ~ '^[A-Z0-9_]+$'::text);

ALTER TABLE public.contract_types
  ADD CONSTRAINT contract_types_code_key UNIQUE (code);

ALTER TABLE public.contract_types
  ADD CONSTRAINT contract_types_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.contract_types
  ADD CONSTRAINT contract_types_pkey PRIMARY KEY (id);

ALTER TABLE public.contract_types
  ADD CONSTRAINT contract_types_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.contract_types TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.contract_types TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.contract_types TO service_role;

CREATE INDEX contract_types_active_order_idx ON public.contract_types (is_active, display_order);

CREATE TRIGGER contract_types_set_updated_at
  BEFORE UPDATE ON public.contract_types
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.countries (
  id         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  name       text                     NOT NULL,
  name_en    text                     NOT NULL,
  code       text,
  is_active  boolean                  DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.countries
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.countries
  ADD CONSTRAINT countries_code_key UNIQUE (code);

ALTER TABLE public.countries
  ADD CONSTRAINT countries_pkey PRIMARY KEY (id);

ALTER TABLE public.banks
  ADD CONSTRAINT banks_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.countries(id) ON UPDATE CASCADE ON DELETE RESTRICT;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.countries TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.countries TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.countries TO service_role;

CREATE POLICY "Public can view active countries" ON public.countries
  FOR SELECT
  TO anon, authenticated
  USING ((is_active = true));

CREATE TABLE public.currencies (
  id               uuid                     DEFAULT gen_random_uuid() NOT NULL,
  code             text                     NOT NULL,
  name             text                     NOT NULL,
  name_en          text,
  symbol           text,
  iso_numeric      text,
  decimal_places   smallint                 DEFAULT 2 NOT NULL,
  is_base_currency boolean                  DEFAULT false NOT NULL,
  display_order    integer                  DEFAULT 0 NOT NULL,
  is_active        boolean                  DEFAULT true NOT NULL,
  created_by       uuid,
  updated_by       uuid,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.currencies
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.currencies
  ADD CONSTRAINT currencies_code_format_check CHECK (code ~ '^[A-Z]{3}$'::text);

ALTER TABLE public.currencies
  ADD CONSTRAINT currencies_code_key UNIQUE (code);

ALTER TABLE public.currencies
  ADD CONSTRAINT currencies_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.currencies
  ADD CONSTRAINT currencies_decimal_places_check CHECK (decimal_places >= 0 AND decimal_places <= 6);

ALTER TABLE public.currencies
  ADD CONSTRAINT currencies_pkey PRIMARY KEY (id);

ALTER TABLE public.currencies
  ADD CONSTRAINT currencies_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.currencies TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.currencies TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.currencies TO service_role;

CREATE INDEX currencies_active_idx ON public.currencies (is_active);

CREATE INDEX currencies_display_order_idx ON public.currencies (display_order);

CREATE UNIQUE INDEX currencies_one_base_currency_idx ON public.currencies (is_base_currency)
  WHERE is_base_currency = true;

CREATE TRIGGER currencies_set_updated_at
  BEFORE UPDATE ON public.currencies
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.departments (
  id         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  branch_id  uuid,
  name       text                     NOT NULL,
  name_en    text,
  is_active  boolean                  DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.departments
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.departments
  ADD CONSTRAINT departments_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;

ALTER TABLE public.departments
  ADD CONSTRAINT departments_pkey PRIMARY KEY (id);

ALTER TABLE public.audit_logs
  ADD CONSTRAINT audit_logs_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON UPDATE CASCADE ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.departments TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.departments TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.departments TO service_role;

CREATE INDEX idx_departments_branch_id ON public.departments (branch_id);

CREATE TABLE public.districts (
  id          uuid                     DEFAULT gen_random_uuid() NOT NULL,
  province_id uuid                     NOT NULL,
  name        text                     NOT NULL,
  name_en     text,
  is_active   boolean                  DEFAULT true NOT NULL,
  created_at  timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.districts
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.districts
  ADD CONSTRAINT districts_pkey PRIMARY KEY (id);

ALTER TABLE public.branches
  ADD CONSTRAINT branches_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.districts(id) ON DELETE SET NULL;

ALTER TABLE public.districts
  ADD CONSTRAINT districts_province_id_name_key UNIQUE (province_id, name);

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.districts TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.districts TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.districts TO service_role;

CREATE INDEX idx_districts_province_id ON public.districts (province_id);

CREATE TABLE public.education_levels (
  id          uuid                     DEFAULT gen_random_uuid() NOT NULL,
  code        text                     NOT NULL,
  name        text                     NOT NULL,
  name_en     text,
  description text,
  level_order integer                  NOT NULL,
  is_active   boolean                  DEFAULT true NOT NULL,
  created_by  uuid,
  updated_by  uuid,
  created_at  timestamp with time zone DEFAULT now() NOT NULL,
  updated_at  timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.education_levels
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.education_levels
  ADD CONSTRAINT education_levels_code_format_check CHECK (code ~ '^[A-Z0-9_]+$'::text);

ALTER TABLE public.education_levels
  ADD CONSTRAINT education_levels_code_key UNIQUE (code);

ALTER TABLE public.education_levels
  ADD CONSTRAINT education_levels_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.education_levels
  ADD CONSTRAINT education_levels_order_check CHECK (level_order > 0);

ALTER TABLE public.education_levels
  ADD CONSTRAINT education_levels_pkey PRIMARY KEY (id);

ALTER TABLE public.education_levels
  ADD CONSTRAINT education_levels_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.education_levels TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.education_levels TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.education_levels TO service_role;

CREATE INDEX education_levels_active_idx ON public.education_levels (is_active);

CREATE UNIQUE INDEX education_levels_level_order_uidx ON public.education_levels (level_order);

CREATE TRIGGER education_levels_set_updated_at
  BEFORE UPDATE ON public.education_levels
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.educational_institutions (
  id               uuid                     DEFAULT gen_random_uuid() NOT NULL,
  code             text                     NOT NULL,
  name             text                     NOT NULL,
  name_en          text,
  institution_type text                     NOT NULL,
  website          text,
  email            text,
  phone            text,
  address          text,
  city             text,
  country_id       uuid,
  is_active        boolean                  DEFAULT true NOT NULL,
  created_by       uuid,
  updated_by       uuid,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.educational_institutions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.educational_institutions
  ADD CONSTRAINT educational_institutions_code_format_check CHECK (code ~ '^[A-Z0-9_]+$'::text);

ALTER TABLE public.educational_institutions
  ADD CONSTRAINT educational_institutions_code_key UNIQUE (code);

ALTER TABLE public.educational_institutions
  ADD CONSTRAINT educational_institutions_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.countries(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.educational_institutions
  ADD CONSTRAINT educational_institutions_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.educational_institutions
  ADD CONSTRAINT educational_institutions_institution_type_check
    CHECK (institution_type = ANY (ARRAY['SCHOOL'::text, 'INSTITUTE'::text, 'UNIVERSITY'::text, 'TRAINING_CENTER'::text, 'OTHER'::text]));

ALTER TABLE public.educational_institutions
  ADD CONSTRAINT educational_institutions_pkey PRIMARY KEY (id);

ALTER TABLE public.educational_institutions
  ADD CONSTRAINT educational_institutions_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.educational_institutions TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.educational_institutions TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.educational_institutions TO service_role;

CREATE INDEX educational_institutions_active_idx ON public.educational_institutions (is_active);

CREATE INDEX educational_institutions_country_idx ON public.educational_institutions (country_id);

CREATE TRIGGER educational_institutions_set_updated_at
  BEFORE UPDATE ON public.educational_institutions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.employee_assignments (
  id                       uuid                     DEFAULT gen_random_uuid() NOT NULL,
  employee_profile_id      uuid                     NOT NULL,
  assignment_type_id       uuid                     NOT NULL,
  branch_id                uuid                     NOT NULL,
  department_id            uuid                     NOT NULL,
  position_id              uuid                     NOT NULL,
  reports_to_assignment_id uuid,
  start_date               date                     NOT NULL,
  end_date                 date,
  is_primary               boolean                  DEFAULT true NOT NULL,
  is_acting                boolean                  DEFAULT false NOT NULL,
  is_active                boolean                  DEFAULT true NOT NULL,
  assignment_reason        text,
  notes                    text,
  created_by               uuid,
  updated_by               uuid,
  created_at               timestamp with time zone DEFAULT now() NOT NULL,
  updated_at               timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.employee_assignments
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.employee_assignments
  ADD CONSTRAINT employee_assignments_assignment_type_id_fkey FOREIGN KEY (assignment_type_id) REFERENCES public.assignment_types(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.employee_assignments
  ADD CONSTRAINT employee_assignments_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.employee_assignments
  ADD CONSTRAINT employee_assignments_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.employee_assignments
  ADD CONSTRAINT employee_assignments_dates_check CHECK (end_date IS NULL OR end_date >= start_date);

ALTER TABLE public.employee_assignments
  ADD CONSTRAINT employee_assignments_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.employee_assignments
  ADD CONSTRAINT employee_assignments_not_self_manager_check CHECK (reports_to_assignment_id IS NULL OR reports_to_assignment_id <> id);

ALTER TABLE public.employee_assignments
  ADD CONSTRAINT employee_assignments_pkey PRIMARY KEY (id);

ALTER TABLE public.employee_assignments
  ADD CONSTRAINT employee_assignments_reports_to_assignment_id_fkey FOREIGN KEY (reports_to_assignment_id) REFERENCES public.employee_assignments(id) ON UPDATE CASCADE ON DELETE
    SET NULL;

ALTER TABLE public.employee_assignments
  ADD CONSTRAINT employee_assignments_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_assignments TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_assignments TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_assignments TO service_role;

CREATE INDEX employee_assignments_employee_idx ON public.employee_assignments (employee_profile_id);

CREATE INDEX employee_assignments_dates_idx ON public.employee_assignments (start_date, end_date);

CREATE INDEX employee_assignments_scope_idx ON public.employee_assignments (branch_id, department_id, is_active);

CREATE UNIQUE INDEX employee_assignments_one_current_primary_idx ON public.employee_assignments (employee_profile_id)
  WHERE is_primary = true AND is_active = true AND end_date IS NULL;

CREATE INDEX employee_assignments_manager_idx ON public.employee_assignments (reports_to_assignment_id);

CREATE INDEX employee_assignments_position_idx ON public.employee_assignments (position_id);

CREATE INDEX employee_assignments_department_idx ON public.employee_assignments (department_id);

CREATE INDEX employee_assignments_branch_idx ON public.employee_assignments (branch_id);

CREATE TRIGGER employee_assignments_set_updated_at
  BEFORE UPDATE ON public.employee_assignments
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.employee_bank_accounts (
  id                  uuid                     DEFAULT gen_random_uuid() NOT NULL,
  employee_profile_id uuid                     NOT NULL,
  bank_id             uuid                     NOT NULL,
  account_holder_name text                     NOT NULL,
  account_number      text                     NOT NULL,
  iban                text,
  swift_code          text,
  account_type        text                     DEFAULT 'CURRENT'::text NOT NULL,
  currency_code       text                     DEFAULT 'AFN'::text NOT NULL,
  is_primary          boolean                  DEFAULT false NOT NULL,
  is_active           boolean                  DEFAULT true NOT NULL,
  notes               text,
  created_by          uuid,
  updated_by          uuid,
  created_at          timestamp with time zone DEFAULT now() NOT NULL,
  updated_at          timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.employee_bank_accounts
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.employee_bank_accounts
  ADD CONSTRAINT employee_bank_accounts_account_type_check CHECK (account_type = ANY (ARRAY['CURRENT'::text, 'SAVINGS'::text, 'SALARY'::text, 'OTHER'::text]));

ALTER TABLE public.employee_bank_accounts
  ADD CONSTRAINT employee_bank_accounts_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES public.banks(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.employee_bank_accounts
  ADD CONSTRAINT employee_bank_accounts_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.employee_bank_accounts
  ADD CONSTRAINT employee_bank_accounts_pkey PRIMARY KEY (id);

ALTER TABLE public.employee_bank_accounts
  ADD CONSTRAINT employee_bank_accounts_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_bank_accounts TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_bank_accounts TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_bank_accounts TO service_role;

CREATE INDEX employee_bank_accounts_active_idx ON public.employee_bank_accounts (is_active);

CREATE INDEX employee_bank_accounts_bank_idx ON public.employee_bank_accounts (bank_id);

CREATE INDEX employee_bank_accounts_employee_idx ON public.employee_bank_accounts (employee_profile_id);

CREATE UNIQUE INDEX employee_bank_accounts_one_primary_idx ON public.employee_bank_accounts (employee_profile_id)
  WHERE is_primary = true AND is_active = true;

CREATE TRIGGER employee_bank_accounts_set_updated_at
  BEFORE UPDATE ON public.employee_bank_accounts
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.employee_emergency_contacts (
  id                   uuid                     DEFAULT gen_random_uuid() NOT NULL,
  employee_profile_id  uuid                     NOT NULL,
  relationship_type_id uuid                     NOT NULL,
  full_name            text                     NOT NULL,
  mobile_number        text                     NOT NULL,
  alternate_phone      text,
  address              text,
  priority_order       integer                  DEFAULT 1 NOT NULL,
  is_primary           boolean                  DEFAULT false NOT NULL,
  is_active            boolean                  DEFAULT true NOT NULL,
  notes                text,
  created_by           uuid,
  updated_by           uuid,
  created_at           timestamp with time zone DEFAULT now() NOT NULL,
  updated_at           timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.employee_emergency_contacts
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.employee_emergency_contacts
  ADD CONSTRAINT employee_emergency_contacts_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.employee_emergency_contacts
  ADD CONSTRAINT employee_emergency_contacts_pkey PRIMARY KEY (id);

ALTER TABLE public.employee_emergency_contacts
  ADD CONSTRAINT employee_emergency_contacts_priority_check CHECK (priority_order > 0);

ALTER TABLE public.employee_emergency_contacts
  ADD CONSTRAINT employee_emergency_contacts_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_emergency_contacts TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_emergency_contacts TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_emergency_contacts TO service_role;

CREATE INDEX employee_emergency_contacts_relationship_idx ON public.employee_emergency_contacts (relationship_type_id);

CREATE INDEX employee_emergency_contacts_employee_idx ON public.employee_emergency_contacts (employee_profile_id);

CREATE UNIQUE INDEX employee_emergency_contacts_one_primary_idx ON public.employee_emergency_contacts (employee_profile_id)
  WHERE is_primary = true AND is_active = true;

CREATE INDEX employee_emergency_contacts_active_idx ON public.employee_emergency_contacts (is_active);

CREATE TRIGGER employee_emergency_contacts_set_updated_at
  BEFORE UPDATE ON public.employee_emergency_contacts
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.employee_profiles (
  id                    uuid                     DEFAULT gen_random_uuid() NOT NULL,
  person_id             uuid                     NOT NULL,
  employee_number       text                     NOT NULL,
  employment_type_id    uuid                     NOT NULL,
  employment_status_id  uuid                     NOT NULL,
  employment_start_date date                     NOT NULL,
  employment_end_date   date,
  corporate_email       text,
  corporate_phone       text,
  extension_number      text,
  profile_photo_path    text,
  notes                 text,
  is_active             boolean                  DEFAULT true NOT NULL,
  created_by            uuid,
  updated_by            uuid,
  created_at            timestamp with time zone DEFAULT now() NOT NULL,
  updated_at            timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.employee_profiles
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.employee_profiles
  ADD CONSTRAINT employee_profiles_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.employee_profiles
  ADD CONSTRAINT employee_profiles_dates_check CHECK (employment_end_date IS NULL OR employment_end_date >= employment_start_date);

ALTER TABLE public.employee_profiles
  ADD CONSTRAINT employee_profiles_employee_number_check CHECK (employee_number ~ '^EMP-[0-9]{6}$'::text);

ALTER TABLE public.employee_profiles
  ADD CONSTRAINT employee_profiles_employee_number_key UNIQUE (employee_number);

ALTER TABLE public.employee_profiles
  ADD CONSTRAINT employee_profiles_pkey PRIMARY KEY (id);

ALTER TABLE public.employee_assignments
  ADD CONSTRAINT employee_assignments_employee_profile_id_fkey FOREIGN KEY (employee_profile_id) REFERENCES public.employee_profiles(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.employee_bank_accounts
  ADD CONSTRAINT employee_bank_accounts_employee_profile_id_fkey FOREIGN KEY (employee_profile_id) REFERENCES public.employee_profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE public.employee_emergency_contacts
  ADD CONSTRAINT employee_emergency_contacts_employee_profile_id_fkey FOREIGN KEY (employee_profile_id) REFERENCES public.employee_profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE public.employee_profiles
  ADD CONSTRAINT employee_profiles_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_profiles TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_profiles TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_profiles TO service_role;

CREATE UNIQUE INDEX employee_profiles_person_id_uidx ON public.employee_profiles (person_id);

CREATE INDEX employee_profiles_active_idx ON public.employee_profiles (is_active);

CREATE INDEX employee_profiles_type_idx ON public.employee_profiles (employment_type_id);

CREATE INDEX employee_profiles_status_idx ON public.employee_profiles (employment_status_id);

CREATE INDEX employee_profiles_employee_number_idx ON public.employee_profiles (employee_number);

CREATE TRIGGER employee_profiles_set_updated_at
  BEFORE UPDATE ON public.employee_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.employee_qualifications (
  id                         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  employee_profile_id        uuid                     NOT NULL,
  education_level_id         uuid                     NOT NULL,
  field_of_study_id          uuid,
  educational_institution_id uuid,
  institution_name_other     text,
  study_country_id           uuid,
  qualification_title        text,
  start_date                 date,
  end_date                   date,
  graduation_year            integer,
  grade_text                 text,
  gpa                        numeric(5,2),
  gpa_scale                  numeric(5,2),
  certificate_number         text,
  verification_status        text                     DEFAULT 'unverified'::text NOT NULL,
  verified_by                uuid,
  verified_at                timestamp with time zone,
  verification_notes         text,
  storage_bucket             text,
  storage_path               text,
  is_highest_qualification   boolean                  DEFAULT false NOT NULL,
  is_active                  boolean                  DEFAULT true NOT NULL,
  notes                      text,
  created_by                 uuid,
  updated_by                 uuid,
  created_at                 timestamp with time zone DEFAULT now() NOT NULL,
  updated_at                 timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.employee_qualifications
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_dates_check CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date);

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_education_level_id_fkey FOREIGN KEY (education_level_id) REFERENCES public.education_levels(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_educational_institution_id_fkey FOREIGN KEY (educational_institution_id) REFERENCES public.educational_institutions(id) ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_employee_profile_id_fkey FOREIGN KEY (employee_profile_id) REFERENCES public.employee_profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_gpa_check CHECK (gpa IS NULL AND gpa_scale IS NULL OR gpa IS NOT NULL AND gpa_scale IS
    NOT NULL AND gpa >= 0::numeric AND gpa_scale > 0::numeric AND gpa <= gpa_scale);

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_graduation_year_check
    CHECK (graduation_year IS NULL OR graduation_year >= 1900 AND graduation_year <= (EXTRACT(year FROM CURRENT_DATE)::integer + 10));

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_institution_check CHECK (educational_institution_id IS NOT NULL OR institution_name_other IS NOT NULL);

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_pkey PRIMARY KEY (id);

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_storage_check CHECK (storage_bucket IS NULL AND storage_path IS NULL OR storage_bucket IS NOT NULL AND storage_path IS NOT NULL);

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_study_country_id_fkey FOREIGN KEY (study_country_id) REFERENCES public.countries(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_verification_check CHECK (verification_status <> 'verified'::text OR verified_by IS NOT NULL AND verified_at IS NOT NULL);

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_verification_status_check
    CHECK (verification_status = ANY (ARRAY['unverified'::text, 'pending'::text, 'verified'::text, 'rejected'::text]));

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_qualifications TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_qualifications TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_qualifications TO service_role;

CREATE INDEX employee_qualifications_employee_idx ON public.employee_qualifications (employee_profile_id);

CREATE INDEX employee_qualifications_level_idx ON public.employee_qualifications (education_level_id);

CREATE INDEX employee_qualifications_country_idx ON public.employee_qualifications (study_country_id);

CREATE INDEX employee_qualifications_field_idx ON public.employee_qualifications (field_of_study_id);

CREATE INDEX employee_qualifications_institution_idx ON public.employee_qualifications (educational_institution_id);

CREATE UNIQUE INDEX employee_qualifications_one_highest_idx ON public.employee_qualifications (employee_profile_id)
  WHERE is_highest_qualification = true AND is_active = true;

CREATE INDEX employee_qualifications_verification_idx ON public.employee_qualifications (verification_status);

CREATE INDEX employee_qualifications_graduation_year_idx ON public.employee_qualifications (graduation_year);

CREATE TRIGGER employee_qualifications_set_updated_at
  BEFORE UPDATE ON public.employee_qualifications
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.employee_work_experiences (
  id                  uuid                     DEFAULT gen_random_uuid() NOT NULL,
  employee_profile_id uuid                     NOT NULL,
  organization_name   text                     NOT NULL,
  job_title           text                     NOT NULL,
  country_id          uuid,
  city                text,
  employment_type_id  uuid,
  start_date          date                     NOT NULL,
  end_date            date,
  is_current          boolean                  DEFAULT false NOT NULL,
  supervisor_name     text,
  supervisor_phone    text,
  supervisor_email    text,
  monthly_salary      numeric(14,2),
  currency_id         uuid,
  responsibilities    text,
  achievements        text,
  leaving_reason      text,
  is_relevant         boolean                  DEFAULT true NOT NULL,
  notes               text,
  created_by          uuid,
  updated_by          uuid,
  created_at          timestamp with time zone DEFAULT now() NOT NULL,
  updated_at          timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.employee_work_experiences
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.employee_work_experiences
  ADD CONSTRAINT employee_work_experiences_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.countries(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.employee_work_experiences
  ADD CONSTRAINT employee_work_experiences_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.employee_work_experiences
  ADD CONSTRAINT employee_work_experiences_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.currencies(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.employee_work_experiences
  ADD CONSTRAINT employee_work_experiences_dates_check CHECK (end_date IS NULL OR end_date >= start_date);

ALTER TABLE public.employee_work_experiences
  ADD CONSTRAINT employee_work_experiences_employee_profile_id_fkey FOREIGN KEY (employee_profile_id) REFERENCES public.employee_profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE public.employee_work_experiences
  ADD CONSTRAINT employee_work_experiences_pkey PRIMARY KEY (id);

ALTER TABLE public.employee_work_experiences
  ADD CONSTRAINT employee_work_experiences_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_work_experiences TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_work_experiences TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employee_work_experiences TO service_role;

CREATE INDEX employee_work_experiences_current_idx ON public.employee_work_experiences (is_current);

CREATE INDEX employee_work_experiences_employee_idx ON public.employee_work_experiences (employee_profile_id);

CREATE INDEX employee_work_experiences_country_idx ON public.employee_work_experiences (country_id);

CREATE TRIGGER employee_work_experiences_set_updated_at
  BEFORE UPDATE ON public.employee_work_experiences
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.employment_contracts (
  id                     uuid                     DEFAULT gen_random_uuid() NOT NULL,
  employee_profile_id    uuid                     NOT NULL,
  contract_type_id       uuid                     NOT NULL,
  assignment_id          uuid,
  contract_number        text                     NOT NULL,
  start_date             date                     NOT NULL,
  end_date               date,
  probation_start_date   date,
  probation_end_date     date,
  basic_salary           numeric(18,2),
  currency_code          text                     DEFAULT 'AFN'::text NOT NULL,
  working_hours_per_week numeric(5,2),
  working_days_per_week  numeric(3,1),
  status                 text                     DEFAULT 'draft'::text NOT NULL,
  signed_by_employee_at  timestamp with time zone,
  approved_by            uuid,
  approved_at            timestamp with time zone,
  storage_bucket         text,
  storage_path           text,
  termination_date       date,
  termination_reason     text,
  notes                  text,
  is_active              boolean                  DEFAULT true NOT NULL,
  created_by             uuid,
  updated_by             uuid,
  created_at             timestamp with time zone DEFAULT now() NOT NULL,
  updated_at             timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.employment_contracts
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_approval_check CHECK (status <> 'active'::text OR approved_by IS NOT NULL AND approved_at IS NOT NULL);

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.employee_assignments(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_contract_number_key UNIQUE (contract_number);

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_contract_type_id_fkey FOREIGN KEY (contract_type_id) REFERENCES public.contract_types(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_dates_check CHECK (end_date IS NULL OR end_date >= start_date);

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_employee_profile_id_fkey FOREIGN KEY (employee_profile_id) REFERENCES public.employee_profiles(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_pkey PRIMARY KEY (id);

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_probation_dates_check CHECK (probation_end_date IS NULL OR probation_start_date IS NULL OR probation_end_date >= probation_start_date);

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_salary_check CHECK (basic_salary IS NULL OR basic_salary >= 0::numeric);

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_status_check CHECK (status = ANY (ARRAY['draft'::text, 'active'::text, 'expired'::text, 'terminated'::text, 'cancelled'::text]));

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_storage_check CHECK (storage_bucket IS NULL AND storage_path IS NULL OR storage_bucket IS NOT NULL AND storage_path IS NOT NULL);

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_termination_date_check CHECK (termination_date IS NULL OR termination_date >= start_date);

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_working_days_check CHECK (working_days_per_week IS NULL OR working_days_per_week >= 0::numeric AND working_days_per_week <= 7::numeric);

ALTER TABLE public.employment_contracts
  ADD CONSTRAINT employment_contracts_working_hours_check CHECK (working_hours_per_week IS NULL OR working_hours_per_week >= 0::numeric AND working_hours_per_week <= 168::numeric);

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employment_contracts TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employment_contracts TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employment_contracts TO service_role;

CREATE INDEX employment_contracts_expiry_idx ON public.employment_contracts (end_date)
  WHERE end_date IS NOT NULL;

CREATE INDEX employment_contracts_type_idx ON public.employment_contracts (contract_type_id);

CREATE INDEX employment_contracts_status_idx ON public.employment_contracts (status);

CREATE INDEX employment_contracts_employee_idx ON public.employment_contracts (employee_profile_id);

CREATE INDEX employment_contracts_assignment_idx ON public.employment_contracts (assignment_id);

CREATE INDEX employment_contracts_dates_idx ON public.employment_contracts (start_date, end_date);

CREATE TRIGGER employment_contracts_set_updated_at
  BEFORE UPDATE ON public.employment_contracts
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.employment_statuses (
  id            uuid                     DEFAULT gen_random_uuid() NOT NULL,
  code          text                     NOT NULL,
  name          text                     NOT NULL,
  name_en       text,
  description   text,
  display_order integer                  DEFAULT 0 NOT NULL,
  is_active     boolean                  DEFAULT true NOT NULL,
  created_by    uuid,
  updated_by    uuid,
  created_at    timestamp with time zone DEFAULT now() NOT NULL,
  updated_at    timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.employment_statuses
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.employment_statuses
  ADD CONSTRAINT employment_statuses_code_format_check CHECK (code ~ '^[A-Z0-9_]+$'::text);

ALTER TABLE public.employment_statuses
  ADD CONSTRAINT employment_statuses_code_key UNIQUE (code);

ALTER TABLE public.employment_statuses
  ADD CONSTRAINT employment_statuses_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.employment_statuses
  ADD CONSTRAINT employment_statuses_pkey PRIMARY KEY (id);

ALTER TABLE public.employee_profiles
  ADD CONSTRAINT employee_profiles_employment_status_id_fkey FOREIGN KEY (employment_status_id) REFERENCES public.employment_statuses(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.employment_statuses
  ADD CONSTRAINT employment_statuses_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employment_statuses TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employment_statuses TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employment_statuses TO service_role;

CREATE INDEX employment_statuses_display_order_idx ON public.employment_statuses (display_order);

CREATE INDEX employment_statuses_is_active_idx ON public.employment_statuses (is_active);

CREATE TRIGGER employment_statuses_set_updated_at
  BEFORE UPDATE ON public.employment_statuses
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.employment_types (
  id                     uuid                     DEFAULT gen_random_uuid() NOT NULL,
  code                   text                     NOT NULL,
  name                   text                     NOT NULL,
  name_en                text,
  description            text,
  is_employee            boolean                  DEFAULT true NOT NULL,
  requires_contract      boolean                  DEFAULT true NOT NULL,
  allows_payroll         boolean                  DEFAULT true NOT NULL,
  allows_attendance      boolean                  DEFAULT true NOT NULL,
  allows_leave           boolean                  DEFAULT true NOT NULL,
  default_probation_days integer,
  is_active              boolean                  DEFAULT true NOT NULL,
  created_by             uuid,
  updated_by             uuid,
  created_at             timestamp with time zone DEFAULT now() NOT NULL,
  updated_at             timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.employment_types
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.employment_types
  ADD CONSTRAINT employment_types_code_format_check CHECK (code ~ '^[A-Z0-9_]+$'::text);

ALTER TABLE public.employment_types
  ADD CONSTRAINT employment_types_code_key UNIQUE (code);

ALTER TABLE public.employment_types
  ADD CONSTRAINT employment_types_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.employment_types
  ADD CONSTRAINT employment_types_default_probation_days_check CHECK (default_probation_days IS NULL OR default_probation_days >= 0);

ALTER TABLE public.employment_types
  ADD CONSTRAINT employment_types_pkey PRIMARY KEY (id);

ALTER TABLE public.employee_profiles
  ADD CONSTRAINT employee_profiles_employment_type_id_fkey FOREIGN KEY (employment_type_id) REFERENCES public.employment_types(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.employee_work_experiences
  ADD CONSTRAINT employee_work_experiences_employment_type_id_fkey FOREIGN KEY (employment_type_id) REFERENCES public.employment_types(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.employment_types
  ADD CONSTRAINT employment_types_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employment_types TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employment_types TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.employment_types TO service_role;

CREATE INDEX employment_types_is_active_idx ON public.employment_types (is_active);

CREATE TRIGGER employment_types_set_updated_at
  BEFORE UPDATE ON public.employment_types
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.fields_of_study (
  id          uuid                     DEFAULT gen_random_uuid() NOT NULL,
  code        text                     NOT NULL,
  name        text                     NOT NULL,
  name_en     text,
  description text,
  is_active   boolean                  DEFAULT true NOT NULL,
  created_by  uuid,
  updated_by  uuid,
  created_at  timestamp with time zone DEFAULT now() NOT NULL,
  updated_at  timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.fields_of_study
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.fields_of_study
  ADD CONSTRAINT fields_of_study_code_format_check CHECK (code ~ '^[A-Z0-9_]+$'::text);

ALTER TABLE public.fields_of_study
  ADD CONSTRAINT fields_of_study_code_key UNIQUE (code);

ALTER TABLE public.fields_of_study
  ADD CONSTRAINT fields_of_study_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.fields_of_study
  ADD CONSTRAINT fields_of_study_pkey PRIMARY KEY (id);

ALTER TABLE public.employee_qualifications
  ADD CONSTRAINT employee_qualifications_field_of_study_id_fkey FOREIGN KEY (field_of_study_id) REFERENCES public.fields_of_study(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.fields_of_study
  ADD CONSTRAINT fields_of_study_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.fields_of_study TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.fields_of_study TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.fields_of_study TO service_role;

CREATE INDEX fields_of_study_active_idx ON public.fields_of_study (is_active);

CREATE TRIGGER fields_of_study_set_updated_at
  BEFORE UPDATE ON public.fields_of_study
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.identity_documents (
  id                  uuid                     DEFAULT gen_random_uuid() NOT NULL,
  person_id           uuid                     NOT NULL,
  document_type       text                     NOT NULL,
  document_number     text                     NOT NULL,
  issuing_country_id  uuid,
  issuing_authority   text,
  issue_date          date,
  expiry_date         date,
  storage_bucket      text,
  storage_path        text,
  verification_status text                     DEFAULT 'unverified'::text NOT NULL,
  verified_by         uuid,
  verified_at         timestamp with time zone,
  is_primary          boolean                  DEFAULT false NOT NULL,
  is_active           boolean                  DEFAULT true NOT NULL,
  notes               text,
  created_by          uuid,
  updated_by          uuid,
  created_at          timestamp with time zone DEFAULT now() NOT NULL,
  updated_at          timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.identity_documents
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.identity_documents
  ADD CONSTRAINT identity_documents_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.identity_documents
  ADD CONSTRAINT identity_documents_dates_check CHECK (expiry_date IS NULL OR issue_date IS NULL OR expiry_date >= issue_date);

ALTER TABLE public.identity_documents
  ADD CONSTRAINT identity_documents_document_type_check
    CHECK
    (document_type = ANY (ARRAY['national_id'::text, 'electronic_national_id'::text, 'passport'::text, 'tax_identification_number'::text, 'work_permit'::text,
    'residence_permit'::text, 'driving_license'::text, 'business_license'::text, 'insurance_card'::text, 'other'::text]));

ALTER TABLE public.identity_documents
  ADD CONSTRAINT identity_documents_issuing_country_id_fkey FOREIGN KEY (issuing_country_id) REFERENCES public.countries(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.identity_documents
  ADD CONSTRAINT identity_documents_person_type_number_unique UNIQUE (person_id, document_type, document_number);

ALTER TABLE public.identity_documents
  ADD CONSTRAINT identity_documents_pkey PRIMARY KEY (id);

ALTER TABLE public.identity_documents
  ADD CONSTRAINT identity_documents_storage_check CHECK (storage_bucket IS NULL AND storage_path IS NULL OR storage_bucket IS NOT NULL AND storage_path IS NOT NULL);

ALTER TABLE public.identity_documents
  ADD CONSTRAINT identity_documents_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.identity_documents
  ADD CONSTRAINT identity_documents_verification_check CHECK (verification_status <> 'verified'::text OR verified_by IS NOT NULL AND verified_at IS NOT NULL);

ALTER TABLE public.identity_documents
  ADD CONSTRAINT identity_documents_verification_status_check
    CHECK (verification_status = ANY (ARRAY['unverified'::text, 'pending'::text, 'verified'::text, 'rejected'::text, 'expired'::text]));

ALTER TABLE public.identity_documents
  ADD CONSTRAINT identity_documents_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.identity_documents TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.identity_documents TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.identity_documents TO service_role;

CREATE UNIQUE INDEX identity_documents_one_primary_per_type_idx ON public.identity_documents (person_id, document_type)
  WHERE is_primary = true AND is_active = true;

CREATE INDEX identity_documents_verification_status_idx ON public.identity_documents (verification_status);

CREATE INDEX identity_documents_expiry_date_idx ON public.identity_documents (expiry_date);

CREATE INDEX identity_documents_document_type_idx ON public.identity_documents (document_type);

CREATE INDEX identity_documents_document_number_idx ON public.identity_documents (document_number);

CREATE INDEX identity_documents_person_id_idx ON public.identity_documents (person_id);

CREATE TRIGGER identity_documents_set_updated_at
  BEFORE UPDATE ON public.identity_documents
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.permissions (
  id                   uuid                     DEFAULT gen_random_uuid() NOT NULL,
  module               text                     NOT NULL,
  resource             text                     NOT NULL,
  action               text                     NOT NULL,
  code                 text                     NOT NULL,
  name                 text                     NOT NULL,
  name_en              text,
  description          text,
  is_system_permission boolean                  DEFAULT true NOT NULL,
  is_active            boolean                  DEFAULT true NOT NULL,
  created_at           timestamp with time zone DEFAULT now() NOT NULL,
  updated_at           timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.permissions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.permissions
  ADD CONSTRAINT permissions_code_format_check CHECK (code ~ '^[a-z0-9_]+(\.[a-z0-9_]+){2,}$'::text);

ALTER TABLE public.permissions
  ADD CONSTRAINT permissions_code_key UNIQUE (code);

ALTER TABLE public.permissions
  ADD CONSTRAINT permissions_module_resource_action_unique UNIQUE (module, resource, action);

ALTER TABLE public.permissions
  ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.permissions TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.permissions TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.permissions TO service_role;

CREATE TABLE public.persons (
  id                     uuid                     DEFAULT gen_random_uuid() NOT NULL,
  person_code            text                     NOT NULL,
  first_name             text                     NOT NULL,
  last_name              text,
  father_name            text,
  grandfather_name       text,
  gender                 text,
  date_of_birth          date,
  primary_phone          text,
  secondary_phone        text,
  primary_email          text,
  nationality_country_id uuid,
  current_province_id    uuid,
  current_district_id    uuid,
  current_address        text,
  preferred_language     text                     DEFAULT 'fa'::text NOT NULL,
  notes                  text,
  is_active              boolean                  DEFAULT true NOT NULL,
  created_by             uuid,
  updated_by             uuid,
  created_at             timestamp with time zone DEFAULT now() NOT NULL,
  updated_at             timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.persons
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.persons
  ADD CONSTRAINT persons_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.persons
  ADD CONSTRAINT persons_current_district_id_fkey FOREIGN KEY (current_district_id) REFERENCES public.districts(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.persons
  ADD CONSTRAINT persons_date_of_birth_check CHECK (date_of_birth IS NULL OR date_of_birth <= CURRENT_DATE);

ALTER TABLE public.persons
  ADD CONSTRAINT persons_gender_check CHECK (gender IS NULL OR (gender = ANY (ARRAY['male'::text, 'female'::text, 'other'::text, 'not_specified'::text])));

ALTER TABLE public.persons
  ADD CONSTRAINT persons_nationality_country_id_fkey FOREIGN KEY (nationality_country_id) REFERENCES public.countries(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.persons
  ADD CONSTRAINT persons_person_code_format_check CHECK (person_code ~ '^[A-Z0-9_-]+$'::text);

ALTER TABLE public.persons
  ADD CONSTRAINT persons_person_code_key UNIQUE (person_code);

ALTER TABLE public.persons
  ADD CONSTRAINT persons_pkey PRIMARY KEY (id);

ALTER TABLE public.employee_profiles
  ADD CONSTRAINT employee_profiles_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.persons(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.identity_documents
  ADD CONSTRAINT identity_documents_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.persons(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE public.persons
  ADD CONSTRAINT persons_preferred_language_check CHECK (preferred_language = ANY (ARRAY['fa'::text, 'ps'::text, 'en'::text]));

ALTER TABLE public.persons
  ADD CONSTRAINT persons_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.persons TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.persons TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.persons TO service_role;

CREATE INDEX persons_is_active_idx ON public.persons (is_active);

CREATE INDEX persons_location_idx ON public.persons (current_province_id, current_district_id);

CREATE INDEX persons_primary_email_idx ON public.persons (primary_email);

CREATE INDEX persons_primary_phone_idx ON public.persons (primary_phone);

CREATE INDEX persons_name_idx ON public.persons (first_name, last_name);

CREATE TRIGGER persons_set_updated_at
  BEFORE UPDATE ON public.persons
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.positions (
  id                 uuid                     DEFAULT gen_random_uuid() NOT NULL,
  code               text                     NOT NULL,
  name               text                     NOT NULL,
  name_en            text,
  description        text,
  parent_position_id uuid,
  hierarchy_level    integer                  DEFAULT 100 NOT NULL,
  is_manager         boolean                  DEFAULT false NOT NULL,
  is_active          boolean                  DEFAULT true NOT NULL,
  created_at         timestamp with time zone DEFAULT now() NOT NULL,
  updated_at         timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.positions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.positions
  ADD CONSTRAINT positions_code_format_check CHECK (code ~ '^[A-Z0-9_]+$'::text);

ALTER TABLE public.positions
  ADD CONSTRAINT positions_code_key UNIQUE (code);

ALTER TABLE public.positions
  ADD CONSTRAINT positions_hierarchy_level_check CHECK (hierarchy_level > 0);

ALTER TABLE public.positions
  ADD CONSTRAINT positions_not_self_parent_check CHECK (parent_position_id IS NULL OR parent_position_id <> id);

ALTER TABLE public.positions
  ADD CONSTRAINT positions_pkey PRIMARY KEY (id);

ALTER TABLE public.employee_assignments
  ADD CONSTRAINT employee_assignments_position_id_fkey FOREIGN KEY (position_id) REFERENCES public.positions(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.positions
  ADD CONSTRAINT positions_parent_position_id_fkey FOREIGN KEY (parent_position_id) REFERENCES public.positions(id) ON UPDATE CASCADE ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.positions TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.positions TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.positions TO service_role;

CREATE INDEX positions_is_active_idx ON public.positions (is_active);

CREATE INDEX positions_parent_position_id_idx ON public.positions (parent_position_id);

CREATE TABLE public.profiles (
  id                    uuid                     NOT NULL,
  person_id             uuid                     NOT NULL,
  branch_id             uuid,
  department_id         uuid,
  position_id           uuid,
  confidentiality_level smallint                 DEFAULT 1 NOT NULL,
  preferred_language    text                     DEFAULT 'fa'::text NOT NULL,
  timezone              text                     DEFAULT 'Asia/Kabul'::text NOT NULL,
  last_login_at         timestamp with time zone,
  must_change_password  boolean                  DEFAULT false NOT NULL,
  is_active             boolean                  DEFAULT true NOT NULL,
  suspended_at          timestamp with time zone,
  suspension_reason     text,
  created_by            uuid,
  updated_by            uuid,
  created_at            timestamp with time zone DEFAULT now() NOT NULL,
  updated_at            timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.profiles
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_confidentiality_level_check CHECK (confidentiality_level >= 1 AND confidentiality_level <= 5);

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.persons(id) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_person_id_key UNIQUE (person_id);

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);

ALTER TABLE public.audit_logs
  ADD CONSTRAINT audit_logs_actor_profile_id_fkey FOREIGN KEY (actor_profile_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_position_id_fkey FOREIGN KEY (position_id) REFERENCES public.positions(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_preferred_language_check CHECK (preferred_language = ANY (ARRAY['fa'::text, 'ps'::text, 'en'::text]));

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_suspension_check CHECK (suspended_at IS NULL AND suspension_reason IS NULL OR suspended_at IS NOT NULL);

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.profiles TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.profiles TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.profiles TO service_role;

CREATE INDEX profiles_department_id_idx ON public.profiles (department_id);

CREATE INDEX profiles_active_scope_idx ON public.profiles (is_active, branch_id, department_id);

CREATE INDEX profiles_person_id_idx ON public.profiles (person_id);

CREATE INDEX profiles_branch_id_idx ON public.profiles (branch_id);

CREATE INDEX profiles_position_id_idx ON public.profiles (position_id);

CREATE TRIGGER profiles_set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.provinces (
  id         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  country_id uuid                     NOT NULL,
  name       text                     NOT NULL,
  name_en    text                     NOT NULL,
  code       text                     NOT NULL,
  is_active  boolean                  DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE POLICY "Public can view active branches" ON public.branches
  FOR SELECT
  TO anon, authenticated
  USING (((status = 'active'::text) AND (EXISTS ( SELECT 1
   FROM public.provinces p
  WHERE ((p.id = branches.province_id) AND (p.is_active = true))))));

CREATE POLICY "Public can view active districts" ON public.districts
  FOR SELECT
  TO anon, authenticated
  USING (((is_active = true) AND (EXISTS ( SELECT 1
   FROM public.provinces p
  WHERE ((p.id = districts.province_id) AND (p.is_active = true))))));

ALTER TABLE public.provinces
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.provinces
  ADD CONSTRAINT provinces_code_key UNIQUE (code);

ALTER TABLE public.provinces
  ADD CONSTRAINT provinces_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.countries(id) ON DELETE RESTRICT;

ALTER TABLE public.provinces
  ADD CONSTRAINT provinces_pkey PRIMARY KEY (id);

ALTER TABLE public.branches
  ADD CONSTRAINT branches_province_id_fkey FOREIGN KEY (province_id) REFERENCES public.provinces(id) ON DELETE RESTRICT;

ALTER TABLE public.districts
  ADD CONSTRAINT districts_province_id_fkey FOREIGN KEY (province_id) REFERENCES public.provinces(id) ON DELETE RESTRICT;

ALTER TABLE public.persons
  ADD CONSTRAINT persons_current_province_id_fkey FOREIGN KEY (current_province_id) REFERENCES public.provinces(id) ON UPDATE CASCADE ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.provinces TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.provinces TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.provinces TO service_role;

CREATE INDEX idx_provinces_country_id ON public.provinces (country_id);

CREATE POLICY "Public can view active provinces" ON public.provinces
  FOR SELECT
  TO anon, authenticated
  USING ((is_active = true));

CREATE TABLE public.relationship_types (
  id            uuid                     DEFAULT gen_random_uuid() NOT NULL,
  code          text                     NOT NULL,
  name          text                     NOT NULL,
  name_en       text,
  description   text,
  display_order integer                  DEFAULT 0 NOT NULL,
  is_active     boolean                  DEFAULT true NOT NULL,
  created_by    uuid,
  updated_by    uuid,
  created_at    timestamp with time zone DEFAULT now() NOT NULL,
  updated_at    timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.relationship_types
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.relationship_types
  ADD CONSTRAINT relationship_types_code_format_check CHECK (code ~ '^[A-Z0-9_]+$'::text);

ALTER TABLE public.relationship_types
  ADD CONSTRAINT relationship_types_code_key UNIQUE (code);

ALTER TABLE public.relationship_types
  ADD CONSTRAINT relationship_types_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.relationship_types
  ADD CONSTRAINT relationship_types_pkey PRIMARY KEY (id);

ALTER TABLE public.employee_emergency_contacts
  ADD CONSTRAINT employee_emergency_contacts_relationship_type_id_fkey FOREIGN KEY (relationship_type_id) REFERENCES public.relationship_types(id) ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE public.relationship_types
  ADD CONSTRAINT relationship_types_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.relationship_types TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.relationship_types TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.relationship_types TO service_role;

CREATE INDEX relationship_types_display_order_idx ON public.relationship_types (display_order);

CREATE INDEX relationship_types_active_idx ON public.relationship_types (is_active);

CREATE TRIGGER relationship_types_set_updated_at
  BEFORE UPDATE ON public.relationship_types
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.role_permissions (
  id            uuid                     DEFAULT gen_random_uuid() NOT NULL,
  role_id       uuid                     NOT NULL,
  permission_id uuid                     NOT NULL,
  granted       boolean                  DEFAULT true NOT NULL,
  created_at    timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.role_permissions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.role_permissions
  ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE public.role_permissions
  ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (id);

ALTER TABLE public.role_permissions
  ADD CONSTRAINT role_permissions_role_permission_unique UNIQUE (role_id, permission_id);

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.role_permissions TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.role_permissions TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.role_permissions TO service_role;

CREATE INDEX role_permissions_role_id_idx ON public.role_permissions (role_id);

CREATE INDEX role_permissions_permission_id_idx ON public.role_permissions (permission_id);

CREATE TABLE public.roles (
  id              uuid                     DEFAULT gen_random_uuid() NOT NULL,
  code            text                     NOT NULL,
  name            text                     NOT NULL,
  name_en         text,
  description     text,
  hierarchy_level integer                  DEFAULT 100 NOT NULL,
  is_system_role  boolean                  DEFAULT false NOT NULL,
  is_active       boolean                  DEFAULT true NOT NULL,
  created_at      timestamp with time zone DEFAULT now() NOT NULL,
  updated_at      timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.roles
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.roles
  ADD CONSTRAINT roles_code_key UNIQUE (code);

ALTER TABLE public.roles
  ADD CONSTRAINT roles_hierarchy_level_check CHECK (hierarchy_level > 0);

ALTER TABLE public.roles
  ADD CONSTRAINT roles_pkey PRIMARY KEY (id);

ALTER TABLE public.role_permissions
  ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON UPDATE CASCADE ON DELETE CASCADE;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.roles TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.roles TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.roles TO service_role;

CREATE TABLE public.services (
  id               uuid                     DEFAULT gen_random_uuid() NOT NULL,
  name             text                     NOT NULL,
  name_en          text                     NOT NULL,
  description      text,
  category         text,
  price            numeric(14,2),
  duration_minutes integer,
  is_active        boolean                  DEFAULT true NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.services
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.services
  ADD CONSTRAINT services_pkey PRIMARY KEY (id);

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.services TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.services TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.services TO service_role;

CREATE POLICY "Public can view active services" ON public.services
  FOR SELECT
  TO anon, authenticated
  USING ((is_active = true));

CREATE TABLE public.user_roles (
  id                uuid                     DEFAULT gen_random_uuid() NOT NULL,
  profile_id        uuid                     NOT NULL,
  role_id           uuid                     NOT NULL,
  branch_id         uuid,
  department_id     uuid,
  starts_at         timestamp with time zone DEFAULT now() NOT NULL,
  ends_at           timestamp with time zone,
  is_active         boolean                  DEFAULT true NOT NULL,
  assigned_by       uuid,
  assignment_reason text,
  notes             text,
  created_at        timestamp with time zone DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.user_roles
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_roles
  ADD CONSTRAINT user_roles_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.user_roles
  ADD CONSTRAINT user_roles_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.user_roles
  ADD CONSTRAINT user_roles_dates_check CHECK (ends_at IS NULL OR ends_at >= starts_at);

ALTER TABLE public.user_roles
  ADD CONSTRAINT user_roles_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.user_roles
  ADD CONSTRAINT user_roles_pkey PRIMARY KEY (id);

ALTER TABLE public.user_roles
  ADD CONSTRAINT user_roles_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE public.user_roles
  ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE public.user_roles
  ADD CONSTRAINT user_roles_unique_scope UNIQUE (profile_id, role_id, branch_id, department_id, starts_at);

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.user_roles TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.user_roles TO authenticated;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.user_roles TO service_role;

CREATE INDEX user_roles_department_idx ON public.user_roles (department_id);

CREATE INDEX user_roles_profile_idx ON public.user_roles (profile_id);

CREATE INDEX user_roles_role_idx ON public.user_roles (role_id);

CREATE INDEX user_roles_branch_idx ON public.user_roles (branch_id);

CREATE INDEX user_roles_active_idx ON public.user_roles (is_active);

CREATE TRIGGER user_roles_set_updated_at
  BEFORE UPDATE ON public.user_roles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE EVENT TRIGGER ensure_rls
  ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  EXECUTE FUNCTION public.rls_auto_enable();
