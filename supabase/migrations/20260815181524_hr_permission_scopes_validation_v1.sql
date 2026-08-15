-- ============================================================
-- Ofoq ERP
-- HR RBAC V1 - Permission Scope Validation
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_user_role_permission_scope_v1()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_role_id uuid;
    v_role_branch_id uuid;
    v_role_department_id uuid;
    v_role_starts_at timestamptz;
    v_role_ends_at timestamptz;
    v_role_is_active boolean;

    v_department_branch_id uuid;
BEGIN
    -- --------------------------------------------------------
    -- 1. Resolve user-role assignment
    -- --------------------------------------------------------
    SELECT
        ur.role_id,
        ur.branch_id,
        ur.department_id,
        ur.starts_at,
        ur.ends_at,
        ur.is_active
    INTO
        v_role_id,
        v_role_branch_id,
        v_role_department_id,
        v_role_starts_at,
        v_role_ends_at,
        v_role_is_active
    FROM public.user_roles ur
    WHERE ur.id = NEW.user_role_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User role assignment does not exist';
    END IF;

    IF v_role_is_active IS NOT TRUE THEN
        RAISE EXCEPTION 'User role assignment is inactive';
    END IF;


    -- --------------------------------------------------------
    -- 2. Permission must belong to the assigned role
    -- --------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1
        FROM public.role_permissions rp
        WHERE rp.role_id = v_role_id
          AND rp.permission_id = NEW.permission_id
          AND rp.granted = true
    ) THEN
        RAISE EXCEPTION
            'Permission is not granted to the assigned role';
    END IF;


    -- --------------------------------------------------------
    -- 3. Scope validity must remain inside role validity
    -- --------------------------------------------------------
    IF NEW.starts_at < v_role_starts_at THEN
        RAISE EXCEPTION
            'Permission scope cannot start before the role assignment';
    END IF;

    IF v_role_ends_at IS NOT NULL
       AND (
            NEW.ends_at IS NULL
            OR NEW.ends_at > v_role_ends_at
       ) THEN
        RAISE EXCEPTION
            'Permission scope cannot outlive the role assignment';
    END IF;


    -- --------------------------------------------------------
    -- 4. Resolve department branch
    -- --------------------------------------------------------
    IF NEW.scope_type = 'department' THEN
        SELECT d.branch_id
        INTO v_department_branch_id
        FROM public.departments d
        WHERE d.id = NEW.department_id
          AND d.is_active = true;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Department does not exist or is inactive';
        END IF;
    END IF;


    -- --------------------------------------------------------
    -- 5. Department-scoped role
    -- --------------------------------------------------------
    IF v_role_department_id IS NOT NULL THEN

        IF NEW.scope_type = 'self' THEN
            RETURN NEW;
        END IF;

        IF NEW.scope_type <> 'department'
           OR NEW.department_id <> v_role_department_id THEN
            RAISE EXCEPTION
                'Permission scope exceeds the department scope of the role';
        END IF;

        RETURN NEW;
    END IF;


    -- --------------------------------------------------------
    -- 6. Branch-scoped role
    -- --------------------------------------------------------
    IF v_role_branch_id IS NOT NULL THEN

        IF NEW.scope_type = 'self' THEN
            RETURN NEW;
        END IF;

        IF NEW.scope_type = 'branch' THEN
            IF NEW.branch_id <> v_role_branch_id THEN
                RAISE EXCEPTION
                    'Permission scope exceeds the branch scope of the role';
            END IF;

            RETURN NEW;
        END IF;

        IF NEW.scope_type = 'department' THEN
            IF v_department_branch_id IS DISTINCT FROM v_role_branch_id THEN
                RAISE EXCEPTION
                    'Department is outside the branch scope of the role';
            END IF;

            RETURN NEW;
        END IF;

        RAISE EXCEPTION
            'Permission scope exceeds the branch scope of the role';
    END IF;


    -- --------------------------------------------------------
    -- 7. Company-scoped role
    -- --------------------------------------------------------
    RETURN NEW;
END;
$$;


CREATE TRIGGER user_role_permission_scopes_validate
BEFORE INSERT OR UPDATE
ON public.user_role_permission_scopes
FOR EACH ROW
EXECUTE FUNCTION public.validate_user_role_permission_scope_v1();