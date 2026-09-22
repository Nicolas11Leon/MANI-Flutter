-- =====================================================================
-- MANI - Políticas RLS y Función de Registro para Supabase Cloud
-- Copia y pega este script completo en el SQL Editor de tu proyecto Supabase
-- (Dashboard -> SQL Editor -> New Query -> Run)
-- =====================================================================

-- 1. Función RPC con SECURITY DEFINER (omite RLS para registro inicial)
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
SET search_path = public
AS $$
DECLARE
    v_aliado_id UUID;
    v_doc JSONB;
BEGIN
    -- Verificar existencia del tenant
    IF NOT EXISTS (SELECT 1 FROM tenant WHERE id = p_tenant_id) THEN
        RAISE EXCEPTION 'El tenant con ID % no existe.', p_tenant_id;
    END IF;

    -- Verificar existencia de la categoría de servicio
    IF p_categoria_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM categoria_servicio WHERE id = p_categoria_id) THEN
        RAISE EXCEPTION 'La categoría con ID % no existe.', p_categoria_id;
    END IF;

    -- Insertar o actualizar usuario en public.usuario
    INSERT INTO public.usuario (id, tenant_id, email, rol, estado, created_at)
    VALUES (p_usuario_id, p_tenant_id, p_email, 'ALIADO', 'ACTIVO', now())
    ON CONFLICT (id) DO UPDATE 
    SET rol = 'ALIADO', estado = 'ACTIVO';

    -- Insertar en tabla aliado (Persona Natural, estado PENDIENTE)
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
        'PERSONA_NATURAL', 
        p_nombre_completo, 
        'PENDIENTE', 
        now()
    )
    RETURNING id INTO v_aliado_id;

    -- Vincular categoría de servicio inicial
    IF p_categoria_id IS NOT NULL THEN
        INSERT INTO public.aliado_categoria (id, tenant_id, aliado_id, categoria_id)
        VALUES (gen_random_uuid(), p_tenant_id, v_aliado_id, p_categoria_id);
    END IF;

    -- Insertar documentos KYC si vienen adjuntos
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
                COALESCE(v_doc->>'tipo_documento', 'OTRO'),
                COALESCE(v_doc->>'ruta_storage', 'documentos/default.pdf'),
                'PENDIENTE',
                now()
            );
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'usuario_id', p_usuario_id,
        'aliado_id', v_aliado_id,
        'estado_verificacion', 'PENDIENTE',
        'mensaje', 'Aliado registrado en estado PENDIENTE.'
    );
END;
$$;

-- Permisos de ejecución para la RPC
GRANT EXECUTE ON FUNCTION registrar_aliado_persona_natural TO anon, authenticated, service_role;

-- 2. Habilitar RLS y definir políticas permisivas para usuarios autenticados
ALTER TABLE IF EXISTS public.usuario ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.aliado ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.aliado_categoria ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.documento_kyc ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.tenant ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.categoria_servicio ENABLE ROW LEVEL SECURITY;

-- Políticas de lectura pública para catálogo inicial (tenant y categorías)
DROP POLICY IF EXISTS "Lectura pública de tenants" ON public.tenant;
CREATE POLICY "Lectura pública de tenants" ON public.tenant FOR SELECT USING (true);

DROP POLICY IF EXISTS "Lectura pública de categorias" ON public.categoria_servicio;
CREATE POLICY "Lectura pública de categorias" ON public.categoria_servicio FOR SELECT USING (true);

-- Políticas para usuario
DROP POLICY IF EXISTS "Usuarios pueden insertar su propio registro" ON public.usuario;
CREATE POLICY "Usuarios pueden insertar su propio registro" ON public.usuario 
FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Usuarios pueden ver su propio registro" ON public.usuario;
CREATE POLICY "Usuarios pueden ver su propio registro" ON public.usuario 
FOR SELECT USING (auth.uid() = id);

-- Políticas para aliado
DROP POLICY IF EXISTS "Aliados pueden insertar su propio registro" ON public.aliado;
CREATE POLICY "Aliados pueden insertar su propio registro" ON public.aliado 
FOR INSERT WITH CHECK (auth.uid() = usuario_id);

DROP POLICY IF EXISTS "Aliados pueden ver su propio perfil" ON public.aliado;
CREATE POLICY "Aliados pueden ver su propio perfil" ON public.aliado 
FOR SELECT USING (auth.uid() = usuario_id);

-- Políticas para categorias de aliado
DROP POLICY IF EXISTS "Permitir vincular categoria a propio aliado" ON public.aliado_categoria;
CREATE POLICY "Permitir vincular categoria a propio aliado" ON public.aliado_categoria 
FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Lectura de categorias de aliado" ON public.aliado_categoria;
CREATE POLICY "Lectura de categorias de aliado" ON public.aliado_categoria 
FOR SELECT USING (true);

-- Políticas para documentos KYC
DROP POLICY IF EXISTS "Aliados pueden subir sus documentos KYC" ON public.documento_kyc;
CREATE POLICY "Aliados pueden subir sus documentos KYC" ON public.documento_kyc 
FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Aliados pueden consultar sus documentos KYC" ON public.documento_kyc;
CREATE POLICY "Aliados pueden consultar sus documentos KYC" ON public.documento_kyc 
FOR SELECT USING (true);

