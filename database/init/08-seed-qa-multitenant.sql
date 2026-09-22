-- =====================================================================
-- CFG-04: Seed de Datos Multi-tenant para QA y Validación de Aislamiento
-- =====================================================================
-- Idempotente: puede ejecutarse múltiples veces sin duplicar ni romper datos.
-- Contiene mínimo 2 tenants completamente equipados con datos aislados:
--   Tenant A: Plomería Express CDMX SA (a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11)
--   Tenant B: Electricistas Pro Monterrey (a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22)
-- =====================================================================

BEGIN;

-- =====================================================================
-- 1. TENANTS (Operadores Independientes)
-- =====================================================================
INSERT INTO public.tenant (id, nombre, slug, estado, fecha_alta)
VALUES 
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Plomería Express CDMX SA', 'plomeria-express', 'ACTIVO', '2026-01-15 08:00:00Z'),
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'Electricistas Pro Monterrey', 'electricistas-pro', 'ACTIVO', '2026-01-20 09:00:00Z'),
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'Cerrajería Total GDL', 'cerrajeria-total', 'ACTIVO', '2026-02-01 10:00:00Z')
ON CONFLICT (id) DO UPDATE 
SET nombre = EXCLUDED.nombre, slug = EXCLUDED.slug, estado = EXCLUDED.estado;

-- =====================================================================
-- 2. ZONAS GEOGRÁFICAS
-- =====================================================================
INSERT INTO public.zona (id, nivel, nombre, zona_padre_id, estado)
VALUES 
    -- Zonas Centro (CDMX)
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'CIUDAD', 'Ciudad de México', NULL, 'ACTIVO'),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', 'LOCALIDAD', 'Cuauhtémoc / Roma Norte', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'ACTIVO'),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'LOCALIDAD', 'Miguel Hidalgo / Polanco', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'ACTIVO'),
    -- Zonas Norte (Monterrey)
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b12', 'CIUDAD', 'Monterrey', NULL, 'ACTIVO'),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b13', 'LOCALIDAD', 'San Pedro Garza García', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b12', 'ACTIVO'),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b14', 'LOCALIDAD', 'San Jerónimo', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b12', 'ACTIVO')
ON CONFLICT (id) DO UPDATE
SET nombre = EXCLUDED.nombre, estado = EXCLUDED.estado;

-- =====================================================================
-- 3. USUARIOS (Aislamiento por tenant_id)
-- =====================================================================
INSERT INTO public.usuario (id, tenant_id, email, rol, estado, created_at)
VALUES 
    -- Usuarios Tenant A (CDMX)
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a15', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'admin-cdmx@mani.app', 'ADMIN_TENANT', 'ACTIVO', now()),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a16', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'aliado-cdmx@mani.app', 'ALIADO', 'ACTIVO', now()),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a26', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'empresa-cdmx@mani.app', 'ALIADO', 'ACTIVO', now()),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a17', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'cliente-cdmx@mani.app', 'CLIENTE', 'ACTIVO', now()),

    -- Usuarios Tenant B (MTY)
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380b15', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'admin-mty@mani.app', 'ADMIN_TENANT', 'ACTIVO', now()),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380b16', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'aliado-mty@mani.app', 'ALIADO', 'ACTIVO', now()),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380b26', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'empresa-mty@mani.app', 'ALIADO', 'ACTIVO', now()),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380b17', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'cliente-mty@mani.app', 'CLIENTE', 'ACTIVO', now())
ON CONFLICT (id) DO UPDATE 
SET tenant_id = EXCLUDED.tenant_id, email = EXCLUDED.email, rol = EXCLUDED.rol, estado = EXCLUDED.estado;

-- =====================================================================
-- 4. CATEGORÍAS DE SERVICIO (Exclusivas por Tenant)
-- =====================================================================
INSERT INTO public.categoria_servicio (id, tenant_id, nombre, estado, flujo_operativo)
VALUES 
    -- Categorías Tenant A (Plomería CDMX)
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a18', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Plomería y Redes Hidráulicas CDMX', 'ACTIVO', 'COTIZACION_PREVIA'),
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a28', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Detección de Fugas e Impermeabilización CDMX', 'ACTIVO', 'COTIZACION_PREVIA'),

    -- Categorías Tenant B (Electricidad MTY)
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380b18', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'Instalaciones Eléctricas de Alta Potencia MTY', 'ACTIVO', 'COTIZACION_PREVIA'),
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380b19', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'Mantenimiento de Tableros y Subestaciones MTY', 'ACTIVO', 'COTIZACION_PREVIA')
ON CONFLICT (id) DO UPDATE 
SET tenant_id = EXCLUDED.tenant_id, nombre = EXCLUDED.nombre, estado = EXCLUDED.estado;

-- =====================================================================
-- 5. TARIFAS DE REFERENCIA
-- =====================================================================
INSERT INTO public.tarifa_referencia (id, tenant_id, categoria_id, valor_min, valor_tipico, valor_max)
VALUES 
    ('01eebc99-9c0b-4ef8-bb6d-6bb9bd380a01', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a18', 450.00, 850.00, 2200.00),
    ('01eebc99-9c0b-4ef8-bb6d-6bb9bd380a02', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a28', 800.00, 1600.00, 4500.00),
    ('01eebc99-9c0b-4ef8-bb6d-6bb9bd380b01', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380b18', 600.00, 1200.00, 3500.00),
    ('01eebc99-9c0b-4ef8-bb6d-6bb9bd380b02', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380b19', 1500.00, 3500.00, 9000.00)
ON CONFLICT (id) DO UPDATE 
SET valor_min = EXCLUDED.valor_min, valor_tipico = EXCLUDED.valor_tipico, valor_max = EXCLUDED.valor_max;

-- =====================================================================
-- 6. ALIADOS (Técnicos Independientes y Empresas)
-- =====================================================================
INSERT INTO public.aliado (id, tenant_id, usuario_id, tipo, nombre_razon_social, estado_verificacion, created_at)
VALUES 
    -- Aliados Tenant A
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a19', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a16', 'PERSONA_NATURAL', 'Carlos Mendoza Plomería CDMX', 'VERIFICADO', now()),
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a29', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a26', 'PERSONA_JURIDICA', 'Hidráulicos del Valle S.A.S.', 'VERIFICADO', now()),

    -- Aliados Tenant B
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380b19', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380b16', 'PERSONA_NATURAL', 'Roberto Garza Electricidad MTY', 'VERIFICADO', now()),
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380b29', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380b26', 'PERSONA_JURIDICA', 'Soluciones Eléctricas Regias S.A.S.', 'VERIFICADO', now())
ON CONFLICT (id) DO UPDATE 
SET tenant_id = EXCLUDED.tenant_id, nombre_razon_social = EXCLUDED.nombre_razon_social, estado_verificacion = EXCLUDED.estado_verificacion;

-- Documentos KYC de Aliados
INSERT INTO public.documento_kyc (id, tenant_id, aliado_id, tipo_documento, ruta_storage, estado, fecha_carga)
VALUES 
    ('11eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a19', 'CEDULA_CIUDADANIA', 'kyc/cdmx/carlos_mendoza_id.pdf', 'APROBADO', now()),
    ('11eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a29', 'CAMARA_COMERCIO', 'kyc/cdmx/hidraulicos_valle_camara.pdf', 'APROBADO', now()),
    ('11eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380b19', 'CEDULA_CIUDADANIA', 'kyc/mty/roberto_garza_id.pdf', 'APROBADO', now()),
    ('11eebc99-9c0b-4ef8-bb6d-6bb9bd380b12', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380b29', 'CAMARA_COMERCIO', 'kyc/mty/electricas_regias_camara.pdf', 'APROBADO', now())
ON CONFLICT (id) DO UPDATE 
SET estado = EXCLUDED.estado, ruta_storage = EXCLUDED.ruta_storage;

-- =====================================================================
-- 7. CATEGORÍAS Y COBERTURAS POR ALIADO
-- =====================================================================
INSERT INTO public.aliado_categoria (id, tenant_id, aliado_id, categoria_id)
VALUES 
    -- Tenant A
    ('f0eebc99-9c0b-4ef8-bb6d-6bb9bd380a21', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a19', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a18'),
    ('f0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a29', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a28'),
    -- Tenant B
    ('f0eebc99-9c0b-4ef8-bb6d-6bb9bd380b21', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380b19', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380b18'),
    ('f0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380b29', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380b19')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cobertura_aliado (id, tenant_id, aliado_id, zona_id, fecha_declaracion)
VALUES 
    -- Tenant A en Zonas CDMX
    ('21eebc99-9c0b-4ef8-bb6d-6bb9bd380a21', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a19', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', now()),
    ('21eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a29', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', now()),
    -- Tenant B en Zonas MTY
    ('21eebc99-9c0b-4ef8-bb6d-6bb9bd380b21', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380b19', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b13', now()),
    ('21eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380b29', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b14', now())
ON CONFLICT (id) DO NOTHING;

-- =====================================================================
-- 8. CLIENTES Y SITIOS (HOGARES)
-- =====================================================================
INSERT INTO public.cliente (id, tenant_id, usuario_id, tipo)
VALUES 
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a20', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a17', 'PERSONA_NATURAL'),
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380b20', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380b17', 'PERSONA_NATURAL')
ON CONFLICT (id) DO UPDATE 
SET tenant_id = EXCLUDED.tenant_id, tipo = EXCLUDED.tipo;

INSERT INTO public.sitio (id, tenant_id, cliente_id, zona_id, direccion, reglas, created_at)
VALUES 
    -- Sitio Tenant A (CDMX)
    ('f0eebc99-9c0b-4ef8-bb6d-6bb9bd380a23', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a20', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', 'Calle Colima 120, Apto 401, Roma Norte', '{"mascotas": false, "parqueadero": true}'::jsonb, now()),
    -- Sitio Tenant B (MTY)
    ('f0eebc99-9c0b-4ef8-bb6d-6bb9bd380b23', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380b20', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b13', 'Av. Vasconcelos 450, Torre Roble 8B, San Pedro', '{"mascotas": true, "seguridad_privada": true}'::jsonb, now())
ON CONFLICT (id) DO UPDATE 
SET direccion = EXCLUDED.direccion, reglas = EXCLUDED.reglas;

-- =====================================================================
-- 9. SOLICITUDES TRANSACCIONALES
-- =====================================================================
INSERT INTO public.solicitud (id, tenant_id, cliente_id, sitio_id, categoria_id, zona_id, aliado_id, estado, created_at, updated_at)
VALUES 
    -- Tenant A: Solicitud 1 (Pendiente de asignación)
    ('31eebc99-9c0b-4ef8-bb6d-6bb9bd380a01', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a20', 'f0eebc99-9c0b-4ef8-bb6d-6bb9bd380a23', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a18', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', NULL, 'PENDIENTE', now() - interval '2 hours', now() - interval '2 hours'),
    -- Tenant A: Solicitud 2 (Asignada a Carlos Mendoza)
    ('31eebc99-9c0b-4ef8-bb6d-6bb9bd380a02', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a20', 'f0eebc99-9c0b-4ef8-bb6d-6bb9bd380a23', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a28', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a19', 'ASIGNADA', now() - interval '1 day', now() - interval '10 hours'),

    -- Tenant B: Solicitud 1 (Pendiente de asignación)
    ('31eebc99-9c0b-4ef8-bb6d-6bb9bd380b01', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380b20', 'f0eebc99-9c0b-4ef8-bb6d-6bb9bd380b23', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380b18', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b13', NULL, 'PENDIENTE', now() - interval '3 hours', now() - interval '3 hours'),
    -- Tenant B: Solicitud 2 (Asignada a Roberto Garza)
    ('31eebc99-9c0b-4ef8-bb6d-6bb9bd380b02', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380b20', 'f0eebc99-9c0b-4ef8-bb6d-6bb9bd380b23', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380b19', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b13', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380b19', 'ASIGNADA', now() - interval '2 days', now() - interval '1 day')
ON CONFLICT (id) DO UPDATE 
SET estado = EXCLUDED.estado, aliado_id = EXCLUDED.aliado_id, updated_at = EXCLUDED.updated_at;

-- =====================================================================
-- 10. COTIZACIONES FORMALES
-- =====================================================================
INSERT INTO public.cotizacion (id, tenant_id, solicitud_id, aliado_id, valor_mano_obra, valor_materiales, estado, version, created_at)
VALUES 
    -- Cotización Tenant A
    ('41eebc99-9c0b-4ef8-bb6d-6bb9bd380a01', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '31eebc99-9c0b-4ef8-bb6d-6bb9bd380a02', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a19', 950.00, 320.00, 'ACEPTADA', 1, now() - interval '8 hours'),
    -- Cotización Tenant B
    ('41eebc99-9c0b-4ef8-bb6d-6bb9bd380b01', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', '31eebc99-9c0b-4ef8-bb6d-6bb9bd380b02', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380b19', 2800.00, 1400.00, 'ACEPTADA', 1, now() - interval '20 hours')
ON CONFLICT (id) DO UPDATE 
SET estado = EXCLUDED.estado, valor_mano_obra = EXCLUDED.valor_mano_obra;

-- =====================================================================
-- 11. MENSAJES Y EVENTOS DE AUDITORÍA
-- =====================================================================
INSERT INTO public.mensaje (id, tenant_id, solicitud_id, remitente_id, contenido, created_at)
VALUES 
    -- Chat Tenant A
    ('51eebc99-9c0b-4ef8-bb6d-6bb9bd380a01', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '31eebc99-9c0b-4ef8-bb6d-6bb9bd380a02', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a17', 'Hola Carlos, la fuga está goteando bajo el lavamanos principal.', now() - interval '9 hours'),
    ('51eebc99-9c0b-4ef8-bb6d-6bb9bd380a02', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '31eebc99-9c0b-4ef8-bb6d-6bb9bd380a02', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a16', 'Buenas tardes Ana, llevo empaques y herramienta de sellado para atender hoy mismo.', now() - interval '8 hours'),

    -- Chat Tenant B
    ('51eebc99-9c0b-4ef8-bb6d-6bb9bd380b01', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', '31eebc99-9c0b-4ef8-bb6d-6bb9bd380b02', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380b17', 'Buenas tardes Roberto, el breaker de la subestación se dispara cada 2 horas.', now() - interval '22 hours'),
    ('51eebc99-9c0b-4ef8-bb6d-6bb9bd380b02', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', '31eebc99-9c0b-4ef8-bb6d-6bb9bd380b02', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380b16', 'Enterado Gerardo. Llevo equipo de termografía para revisar puntos calientes en el tablero.', now() - interval '21 hours')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.evento_servicio (id, tenant_id, solicitud_id, actor_id, tipo_evento, descripcion, timestamp)
VALUES 
    -- Eventos Tenant A
    ('61eebc99-9c0b-4ef8-bb6d-6bb9bd380a01', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '31eebc99-9c0b-4ef8-bb6d-6bb9bd380a02', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a17', 'SOLICITUD_CREADA', 'Cliente reporta fuga en tubería interna.', now() - interval '1 day'),
    ('61eebc99-9c0b-4ef8-bb6d-6bb9bd380a02', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '31eebc99-9c0b-4ef8-bb6d-6bb9bd380a02', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a16', 'SOLICITUD_ASIGNADA', 'Aliado Carlos Mendoza aceptó el servicio.', now() - interval '10 hours'),

    -- Eventos Tenant B
    ('61eebc99-9c0b-4ef8-bb6d-6bb9bd380b01', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', '31eebc99-9c0b-4ef8-bb6d-6bb9bd380b02', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380b17', 'SOLICITUD_CREADA', 'Cliente reporta fallo en subestación.', now() - interval '2 days'),
    ('61eebc99-9c0b-4ef8-bb6d-6bb9bd380b02', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', '31eebc99-9c0b-4ef8-bb6d-6bb9bd380b02', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380b16', 'SOLICITUD_ASIGNADA', 'Aliado Roberto Garza aceptó el servicio.', now() - interval '1 day')
ON CONFLICT (id) DO NOTHING;

COMMIT;
