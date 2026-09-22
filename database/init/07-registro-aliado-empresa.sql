-- =====================================================================
-- US-02.1.2: Registro Aliado Empresa (Persona Jurídica)
-- =====================================================================

-- Función transaccional para registrar un Aliado Empresa (Persona Jurídica)
-- Crea en una única transacción:
-- 1. usuario (rol: 'ALIADO', estado: 'ACTIVO')
-- 2. aliado (tipo: 'PERSONA_JURIDICA', nombre_razon_social: p_razon_social, estado_verificacion: 'PENDIENTE')
-- 3. aliado_categoria (asociación de especialidad de servicio)
-- 4. documento_kyc (Cámara de Comercio, RUT de la empresa, cédula de rep. legal)

CREATE OR REPLACE FUNCTION registrar_aliado_empresa(
    p_usuario_id UUID,
    p_tenant_id UUID,
    p_email TEXT,
    p_razon_social TEXT,
    p_nit TEXT,
    p_nombre_representante TEXT,
    p_doc_representante TEXT DEFAULT NULL,
    p_telefono_contacto TEXT DEFAULT NULL,
    p_categoria_id UUID DEFAULT NULL,
    p_documentos JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_aliado_id UUID;
    v_doc JSONB;
BEGIN
    -- 1. Verificar existencia del tenant
    IF NOT EXISTS (SELECT 1 FROM tenant WHERE id = p_tenant_id) THEN
        RAISE EXCEPTION 'El tenant con ID % no existe.', p_tenant_id;
    END IF;

    -- 2. Verificar existencia de la categoría de servicio si fue provista
    IF p_categoria_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM categoria_servicio WHERE id = p_categoria_id) THEN
        RAISE EXCEPTION 'La categoría con ID % no existe.', p_categoria_id;
    END IF;

    -- 3. Insertar o actualizar usuario en public.usuario
    INSERT INTO public.usuario (id, tenant_id, email, rol, estado, created_at)
    VALUES (p_usuario_id, p_tenant_id, p_email, 'ALIADO', 'ACTIVO', now())
    ON CONFLICT (id) DO UPDATE 
    SET rol = 'ALIADO', estado = 'ACTIVO';

    -- 4. Insertar en tabla aliado (Persona Jurídica, estado PENDIENTE)
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
        p_tenant_id, 
        p_usuario_id, 
        'PERSONA_JURIDICA', 
        p_razon_social, 
        'PENDIENTE', 
        now()
    )
    ON CONFLICT (usuario_id) DO UPDATE
    SET nombre_razon_social = EXCLUDED.nombre_razon_social,
        tipo = 'PERSONA_JURIDICA'
    RETURNING id INTO v_aliado_id;

    -- 5. Vincular categoría de servicio inicial si fue provista
    IF p_categoria_id IS NOT NULL THEN
        INSERT INTO public.aliado_categoria (id, tenant_id, aliado_id, categoria_id)
        VALUES (gen_random_uuid(), p_tenant_id, v_aliado_id, p_categoria_id)
        ON CONFLICT DO NOTHING;
    END IF;

    -- 6. Insertar documentos KYC si vienen adjuntos
    IF p_documentos IS NOT NULL AND jsonb_array_length(p_documentos) > 0 THEN
        FOR v_doc IN SELECT * FROM jsonb_array_elements(p_documentos)
        LOOP
            INSERT INTO public.documento_kyc (
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
                COALESCE(v_doc->>'tipo_documento', 'CAMARA_COMERCIO'),
                COALESCE(v_doc->>'ruta_storage', 'documentos/empresa_doc.pdf'),
                'PENDIENTE',
                now()
            );
        END LOOP;
    END IF;

    -- Retornar confirmación
    RETURN jsonb_build_object(
        'success', true,
        'usuario_id', p_usuario_id,
        'aliado_id', v_aliado_id,
        'rol', 'ALIADO',
        'tipo', 'PERSONA_JURIDICA',
        'estado_verificacion', 'PENDIENTE',
        'mensaje', 'Aliado empresa (persona jurídica) registrado exitosamente en estado PENDIENTE.'
    );
END;
$$;

-- Permisos para llamada vía API / RPC (compatibles con Supabase y Postgres estándar)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        GRANT EXECUTE ON FUNCTION registrar_aliado_empresa TO anon, authenticated, service_role;
    END IF;
END $$;

