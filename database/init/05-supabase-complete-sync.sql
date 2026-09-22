-- =====================================================================
-- SINCRONIZACIÓN COMPLETA Y TRIGGER AUTOMÁTICO PARA SUPABASE CLOUD
-- Ejecuta este script en el SQL Editor de tu proyecto Supabase:
-- https://supabase.com/dashboard/project/tpueuiuwxgipItqwb
-- =====================================================================

-- 1. Asegurar que existan los Tenants y Categorías de Servicio en Supabase
INSERT INTO public.tenant (id, nombre, slug, estado, fecha_alta)
VALUES 
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Plomería Express CDMX SA', 'plomeria-express', 'ACTIVO', now()),
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'Electricistas Pro Monterrey', 'electricistas-pro', 'ACTIVO', now()),
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'Cerrajería Total GDL', 'cerrajeria-total', 'ACTIVO', now())
ON CONFLICT (id) DO UPDATE 
SET nombre = EXCLUDED.nombre, slug = EXCLUDED.slug;

INSERT INTO public.categoria_servicio (id, tenant_id, nombre, estado, flujo_operativo)
VALUES 
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a18', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Plomería y Redes Hidráulicas', 'ACTIVO', 'COTIZACION_PREVIA'),
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a19', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Electricidad Residencial e Industrial', 'ACTIVO', 'COTIZACION_PREVIA'),
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a20', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Cerrajería y Seguridad', 'ACTIVO', 'TARIFA_ESTANDAR')
ON CONFLICT (id) DO NOTHING;

-- 2. Función Trigger que se activa AUTOMÁTICAMENTE en cada registro en Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tenant_id UUID;
    v_aliado_id UUID;
    v_categoria_id UUID;
BEGIN
    -- Obtener o asignar tenant por defecto
    v_tenant_id := COALESCE(
        NULLIF(new.raw_user_meta_data->>'tenant_id', '')::uuid,
        'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid
    );

    -- 1. Insertar en tabla pública usuario
    INSERT INTO public.usuario (id, tenant_id, email, rol, estado, created_at)
    VALUES (
        new.id,
        v_tenant_id,
        new.email,
        COALESCE(new.raw_user_meta_data->>'rol', 'ALIADO'),
        'ACTIVO',
        now()
    )
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        rol = EXCLUDED.rol,
        estado = 'ACTIVO';

    -- 2. Si el rol es ALIADO, insertar en tabla pública aliado
    IF COALESCE(new.raw_user_meta_data->>'rol', 'ALIADO') = 'ALIADO' THEN
        INSERT INTO public.aliado (
            id,
            tenant_id,
            usuario_id,
            tipo,
            nombre_razon_social,
            estado_verificacion,
            created_at
        )
        VALUES (
            gen_random_uuid(),
            v_tenant_id,
            new.id,
            COALESCE(new.raw_user_meta_data->>'tipo', 'PERSONA_NATURAL'),
            COALESCE(new.raw_user_meta_data->>'razon_social', new.raw_user_meta_data->>'nombre_completo', split_part(new.email, '@', 1)),
            'PENDIENTE',
            now()
        )
        ON CONFLICT (usuario_id) DO UPDATE
        SET nombre_razon_social = EXCLUDED.nombre_razon_social,
            tipo = EXCLUDED.tipo
        RETURNING id INTO v_aliado_id;

        -- 3. Vincular categoría si viene en la metadata
        IF new.raw_user_meta_data->>'categoria_id' IS NOT NULL AND v_aliado_id IS NOT NULL THEN
            BEGIN
                v_categoria_id := (new.raw_user_meta_data->>'categoria_id')::uuid;
                INSERT INTO public.aliado_categoria (id, tenant_id, aliado_id, categoria_id)
                VALUES (gen_random_uuid(), v_tenant_id, v_aliado_id, v_categoria_id)
                ON CONFLICT DO NOTHING;
            EXCEPTION WHEN OTHERS THEN
                -- Si la categoría no es UUID válido, omitir silenciosamente
            END;
        END IF;
    ELSIF COALESCE(new.raw_user_meta_data->>'rol', 'ALIADO') = 'CLIENTE' THEN
        -- Insertar en tabla pública cliente
        DECLARE
            v_cliente_id UUID;
            v_zona_id UUID;
            v_dir TEXT;
        BEGIN
            INSERT INTO public.cliente (
                id,
                tenant_id,
                usuario_id,
                tipo
            )
            VALUES (
                gen_random_uuid(),
                v_tenant_id,
                new.id,
                COALESCE(new.raw_user_meta_data->>'tipo', 'PERSONA_NATURAL')
            )
            ON CONFLICT (usuario_id) DO UPDATE
            SET tipo = EXCLUDED.tipo
            RETURNING id INTO v_cliente_id;

            -- Si tiene dirección de hogar, crear sitio inicial
            v_dir := new.raw_user_meta_data->>'direccion_hogar';
            IF v_dir IS NOT NULL AND trim(v_dir) <> '' THEN
                SELECT id INTO v_zona_id FROM public.zona WHERE estado = 'ACTIVO' LIMIT 1;
                IF v_zona_id IS NOT NULL THEN
                    INSERT INTO public.sitio (
                        id, tenant_id, cliente_id, zona_id, direccion, reglas, created_at
                    )
                    VALUES (
                        gen_random_uuid(),
                        v_tenant_id,
                        v_cliente_id,
                        v_zona_id,
                        trim(v_dir),
                        jsonb_build_object(
                            'nombre_contacto', new.raw_user_meta_data->>'nombre_completo',
                            'telefono', new.raw_user_meta_data->>'telefono'
                        ),
                        now()
                    );
                END IF;
            END IF;
        END;
    END IF;

    RETURN new;
END;
$$;

-- 3. Activar el Trigger en la tabla de autenticación de Supabase (auth.users)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Sincronizar inmediatamente los usuarios que YA existen en auth.users (como tu usuario registrado)
INSERT INTO public.usuario (id, tenant_id, email, rol, estado, created_at)
SELECT 
    u.id,
    COALESCE(NULLIF(u.raw_user_meta_data->>'tenant_id', '')::uuid, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid),
    u.email,
    COALESCE(u.raw_user_meta_data->>'rol', 'ALIADO'),
    'ACTIVO',
    u.created_at
FROM auth.users u
ON CONFLICT (id) DO UPDATE
SET rol = EXCLUDED.rol, estado = 'ACTIVO';

INSERT INTO public.aliado (id, tenant_id, usuario_id, tipo, nombre_razon_social, estado_verificacion, created_at)
SELECT 
    gen_random_uuid(),
    COALESCE(NULLIF(u.raw_user_meta_data->>'tenant_id', '')::uuid, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid),
    u.id,
    COALESCE(u.raw_user_meta_data->>'tipo', 'PERSONA_NATURAL'),
    COALESCE(u.raw_user_meta_data->>'nombre_completo', split_part(u.email, '@', 1)),
    'PENDIENTE',
    u.created_at
FROM auth.users u
WHERE COALESCE(u.raw_user_meta_data->>'rol', 'ALIADO') = 'ALIADO'
ON CONFLICT (usuario_id) DO NOTHING;

