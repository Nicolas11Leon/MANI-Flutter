-- =====================================================================
-- Datos Semilla de Prueba (Seed Data) - MANI Local Development
-- =====================================================================

-- 1. Tenant de Prueba
INSERT INTO tenant (id, nombre, slug, estado, fecha_alta)
VALUES 
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'TRAMA Servicios Demo', 'trama-demo', 'ACTIVO', now())
ON CONFLICT (slug) DO NOTHING;

-- 2. Zonas Geográficas
INSERT INTO zona (id, nivel, nombre, zona_padre_id, estado)
VALUES 
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'CIUDAD', 'Bogotá D.C.', NULL, 'ACTIVO'),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', 'LOCALIDAD', 'Chapinero', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'ACTIVO'),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'LOCALIDAD', 'Usaquén', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'ACTIVO')
ON CONFLICT DO NOTHING;

-- 3. Usuarios de Prueba
INSERT INTO usuario (id, tenant_id, email, rol, estado, created_at)
VALUES 
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a15', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'admin@trama.com', 'ADMIN_TENANT', 'ACTIVO', now()),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a16', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'aliado@trama.com', 'ALIADO', 'ACTIVO', now()),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a17', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'cliente@trama.com', 'CLIENTE', 'ACTIVO', now())
ON CONFLICT DO NOTHING;

-- 4. Categoría de Servicio
INSERT INTO categoria_servicio (id, tenant_id, nombre, estado, flujo_operativo)
VALUES 
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a18', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Plomería y Mantenimiento', 'ACTIVO', 'COTIZACION_PREVIA')
ON CONFLICT DO NOTHING;

-- 5. Aliado y Cliente
INSERT INTO aliado (id, tenant_id, usuario_id, tipo, nombre_razon_social, estado_verificacion, created_at)
VALUES 
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a19', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a16', 'PERSONA_NATURAL', 'Juan Pérez Reparaciones', 'VERIFICADO', now())
ON CONFLICT DO NOTHING;

INSERT INTO cliente (id, tenant_id, usuario_id, tipo)
VALUES 
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a20', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a17', 'PERSONA_NATURAL')
ON CONFLICT DO NOTHING;

-- 6. Cobertura del Aliado y Categoría
INSERT INTO aliado_categoria (id, tenant_id, aliado_id, categoria_id)
VALUES 
    ('f0eebc99-9c0b-4ef8-bb6d-6bb9bd380a21', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a19', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a18')
ON CONFLICT DO NOTHING;

INSERT INTO cobertura_aliado (id, tenant_id, aliado_id, zona_id, fecha_declaracion)
VALUES 
    ('f0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a19', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', now())
ON CONFLICT DO NOTHING;

-- 7. Sitio del Cliente
INSERT INTO sitio (id, tenant_id, cliente_id, zona_id, direccion, reglas, created_at)
VALUES 
    ('f0eebc99-9c0b-4ef8-bb6d-6bb9bd380a23', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a20', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', 'Calle 67 # 9-20, Apto 302', '{"mascotas": true, "parqueadero": false}'::jsonb, now())
ON CONFLICT DO NOTHING;
