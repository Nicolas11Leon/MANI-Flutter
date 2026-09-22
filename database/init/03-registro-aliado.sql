-- =====================================================================
-- US-02.1.1: Registro Aliado Persona Natural con Documentos KYC
-- =====================================================================

-- Función transaccional para registrar un Aliado (Persona Natural)
-- Crea en una única transacción:
-- 1. usuario (rol: 'ALIADO', estado: 'ACTIVO')
-- 2. aliado (tipo: 'PERSONA_NATURAL', estado_verificacion: 'PENDIENTE')
-- 3. aliado_categoria (asociación de su especialidad técnica)
-- 4. documento_kyc (documentos adjuntos en estado 'PENDIENTE' para revisión de Backoffice)

CREATE OR REPLACE FUNCTION registrar_aliado_persona_natural(
    p_usuario_id UUID,
    p_tenant_id UUID,
    p_email TEXT,
    p_nombre_completo TEXT,
    p_categoria_id UUID,
    p_documentos JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_aliado_id UUID;
    v_doc JSONB;
BEGIN
    -- 1. Verificar existencia del tenant
    IF NOT EXISTS (SELECT 1 FROM tenant WHERE id = p_tenant_id) THEN
        RAISE EXCEPTION 'El tenant con ID % no existe.', p_tenant_id;
    END IF;

    -- 2. Verificar existencia de la categoría de servicio
    IF p_categoria_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM categoria_servicio WHERE id = p_categoria_id) THEN
        RAISE EXCEPTION 'La categoría con ID % no existe.', p_categoria_id;
    END IF;

    -- 3. Insertar o sincronizar usuario
    INSERT INTO usuario (id, tenant_id, email, rol, estado, created_at)
    VALUES (p_usuario_id, p_tenant_id, p_email, 'ALIADO', 'ACTIVO', now())
    ON CONFLICT (id) DO UPDATE 
    SET rol = 'ALIADO', estado = 'ACTIVO';

    -- 4. Insertar en tabla aliado (Persona Natural, estado PENDIENTE)
    INSERT INTO aliado (
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
        p_tenant_id, 
        p_usuario_id, 
        'PERSONA_NATURAL', 
        p_nombre_completo, 
        'PENDIENTE', 
        now()
    )
    RETURNING id INTO v_aliado_id;

    -- 5. Vincular categoría de servicio inicial si fue provista
    IF p_categoria_id IS NOT NULL THEN
        INSERT INTO aliado_categoria (id, tenant_id, aliado_id, categoria_id)
        VALUES (gen_random_uuid(), p_tenant_id, v_aliado_id, p_categoria_id);
    END IF;

    -- 6. Insertar documentos KYC si vienen adjuntos
    IF p_documentos IS NOT NULL AND jsonb_array_length(p_documentos) > 0 THEN
        FOR v_doc IN SELECT * FROM jsonb_array_elements(p_documentos)
        LOOP
            INSERT INTO documento_kyc (
                id,
                tenant_id,
                aliado_id,
                tipo_documento,
                ruta_storage,
                estado,
                fecha_carga
            )
            VALUES (
                gen_random_uuid(),
                p_tenant_id,
                v_aliado_id,
                COALESCE(v_doc->>'tipo_documento', 'OTRO'),
                COALESCE(v_doc->>'ruta_storage', 'documentos/default.pdf'),
                'PENDIENTE',
                now()
            );
        END LOOP;
    END IF;

    -- Retornar información consolidada
    RETURN jsonb_build_object(
        'success', true,
        'usuario_id', p_usuario_id,
        'aliado_id', v_aliado_id,
        'estado_verificacion', 'PENDIENTE',
        'mensaje', 'Aliado persona natural registrado exitosamente en estado PENDIENTE.'
    );
END;
$$;

-- Permisos para llamada vía API / RPC (compatibles con Supabase y Postgres estándar)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        GRANT EXECUTE ON FUNCTION registrar_aliado_persona_natural TO anon, authenticated, service_role;
    END IF;
END $$;
