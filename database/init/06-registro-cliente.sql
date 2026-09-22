-- =====================================================================
-- US-02.2.1: Registro Cliente Persona Natural (Cuenta Rápida)
-- =====================================================================

-- Función transaccional para registrar un Cliente (Persona Natural)
-- Crea en una única transacción:
-- 1. usuario (rol: 'CLIENTE', estado: 'ACTIVO')
-- 2. cliente (tipo: 'PERSONA_NATURAL')
-- 3. sitio (opcional: primer domicilio/hogar del cliente para mantenimientos)

CREATE OR REPLACE FUNCTION registrar_cliente_persona_natural(
    p_usuario_id UUID,
    p_tenant_id UUID,
    p_email TEXT,
    p_nombre_completo TEXT,
    p_telefono TEXT DEFAULT NULL,
    p_direccion_hogar TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cliente_id UUID;
    v_zona_id UUID;
BEGIN
    -- 1. Verificar existencia del tenant
    IF NOT EXISTS (SELECT 1 FROM tenant WHERE id = p_tenant_id) THEN
        RAISE EXCEPTION 'El tenant con ID % no existe.', p_tenant_id;
    END IF;

    -- 2. Insertar o actualizar usuario en public.usuario
    INSERT INTO public.usuario (id, tenant_id, email, rol, estado, created_at)
    VALUES (p_usuario_id, p_tenant_id, p_email, 'CLIENTE', 'ACTIVO', now())
    ON CONFLICT (id) DO UPDATE 
    SET rol = 'CLIENTE', estado = 'ACTIVO';

    -- 3. Insertar en tabla cliente (Persona Natural)
    INSERT INTO public.cliente (
        id, 
        tenant_id, 
        usuario_id, 
        tipo
    )
    VALUES (
        gen_random_uuid(), 
        p_tenant_id, 
        p_usuario_id, 
        'PERSONA_NATURAL'
    )
    ON CONFLICT (usuario_id) DO UPDATE
    SET tipo = 'PERSONA_NATURAL'
    RETURNING id INTO v_cliente_id;

    -- 4. Si se provee dirección, crear el primer sitio (hogar) del cliente
    IF p_direccion_hogar IS NOT NULL AND trim(p_direccion_hogar) <> '' THEN
        -- Buscar una zona por defecto del tenant o la primera activa
        SELECT id INTO v_zona_id FROM zona WHERE estado = 'ACTIVO' LIMIT 1;
        
        IF v_zona_id IS NOT NULL THEN
            INSERT INTO public.sitio (
                id,
                tenant_id,
                cliente_id,
                zona_id,
                direccion,
                reglas,
                created_at
            )
            VALUES (
                gen_random_uuid(),
                p_tenant_id,
                v_cliente_id,
                v_zona_id,
                trim(p_direccion_hogar),
                jsonb_build_object('nombre_contacto', p_nombre_completo, 'telefono', p_telefono),
                now()
            );
        END IF;
    END IF;

    -- Retornar confirmación
    RETURN jsonb_build_object(
        'success', true,
        'usuario_id', p_usuario_id,
        'cliente_id', v_cliente_id,
        'rol', 'CLIENTE',
        'estado', 'ACTIVO',
        'mensaje', 'Cliente persona natural registrado exitosamente con cuenta activa.'
    );
END;
$$;

-- Permisos para llamada vía API / RPC (compatibles con Supabase y Postgres estándar)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        GRANT EXECUTE ON FUNCTION registrar_cliente_persona_natural TO anon, authenticated, service_role;
    END IF;
END $$;

