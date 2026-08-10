-- =====================================================
-- Ofoq ERP
-- Migration: Shared Audit Log Function Fix
-- Purpose: Align log_audit_changes() with current audit_logs schema
-- =====================================================

CREATE OR REPLACE FUNCTION public.log_audit_changes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_record_id UUID;
BEGIN

    -- Determine affected record ID
    IF TG_OP = 'DELETE' THEN
        v_record_id := OLD.id;
    ELSE
        v_record_id := NEW.id;
    END IF;

    -- Write audit event using the current audit_logs schema
    INSERT INTO public.audit_logs (
        actor_user_id,
        module,
        action,
        entity_table,
        entity_id,
        old_data,
        new_data,
        source,
        metadata,
        occurred_at
    )
    VALUES (
        auth.uid(),
        'database',
        lower(TG_OP),
        TG_TABLE_NAME,
        v_record_id,
        CASE
            WHEN TG_OP IN ('UPDATE', 'DELETE')
                THEN to_jsonb(OLD)
            ELSE NULL
        END,
        CASE
            WHEN TG_OP IN ('INSERT', 'UPDATE')
                THEN to_jsonb(NEW)
            ELSE NULL
        END,
        'database',
        jsonb_build_object(
            'schema', TG_TABLE_SCHEMA,
            'trigger', TG_NAME
        ),
        now()
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;

END;
$$;