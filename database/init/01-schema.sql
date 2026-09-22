-- =====================================================================
-- Esquema Oficial de Base de Datos - MANI
-- Dialecto: PostgreSQL (Compatible con Supabase / Postgres 15+)
-- =====================================================================

-- 1. Tabla de Control de Migraciones Versionadas
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(50) PRIMARY KEY,
    description TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Habilitar extensión para generación de UUIDs (por defecto en Supabase)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==========================================
-- 1. TABLAS INDEPENDIENTES / BASE
-- ==========================================

-- Tabla: tenant
CREATE TABLE IF NOT EXISTS tenant (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    estado TEXT NOT NULL,
    fecha_alta TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla: zona (con auto-referencia para jerarquías)
CREATE TABLE IF NOT EXISTS zona (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nivel TEXT NOT NULL,
    nombre TEXT NOT NULL,
    zona_padre_id UUID REFERENCES zona(id) ON DELETE SET NULL,
    estado TEXT NOT NULL
);

-- Tabla: usuario
CREATE TABLE IF NOT EXISTS usuario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenant(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    rol TEXT NOT NULL,
    estado TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================
-- 2. ENTIDADES PRINCIPALES Y PERFILES
-- ==========================================

-- Tabla: categoria_servicio
CREATE TABLE IF NOT EXISTS categoria_servicio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    estado TEXT NOT NULL,
    flujo_operativo TEXT
);

-- Tabla: aliado
CREATE TABLE IF NOT EXISTS aliado (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL UNIQUE REFERENCES usuario(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL,
    nombre_razon_social TEXT NOT NULL,
    estado_verificacion TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla: cliente
CREATE TABLE IF NOT EXISTS cliente (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL UNIQUE REFERENCES usuario(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL
);

-- ==========================================
-- 3. DETALLES Y CONFIGURACIONES DE NEGOCIO
-- ==========================================

-- Tabla: aliado_categoria
CREATE TABLE IF NOT EXISTS aliado_categoria (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    aliado_id UUID NOT NULL REFERENCES aliado(id) ON DELETE CASCADE,
    categoria_id UUID NOT NULL REFERENCES categoria_servicio(id) ON DELETE CASCADE
);

-- Tabla: documento_kyc
CREATE TABLE IF NOT EXISTS documento_kyc (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    aliado_id UUID NOT NULL REFERENCES aliado(id) ON DELETE CASCADE,
    tipo_documento TEXT NOT NULL,
    ruta_storage TEXT NOT NULL,
    estado TEXT NOT NULL,
    fecha_carga TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla: tarifa_referencia
CREATE TABLE IF NOT EXISTS tarifa_referencia (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    categoria_id UUID NOT NULL REFERENCES categoria_servicio(id) ON DELETE CASCADE,
    valor_min DECIMAL(12, 2) NOT NULL,
    valor_tipico DECIMAL(12, 2) NOT NULL,
    valor_max DECIMAL(12, 2) NOT NULL
);

-- Tabla: cobertura_aliado
CREATE TABLE IF NOT EXISTS cobertura_aliado (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    aliado_id UUID NOT NULL REFERENCES aliado(id) ON DELETE CASCADE,
    zona_id UUID NOT NULL REFERENCES zona(id) ON DELETE CASCADE,
    fecha_declaracion TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla: sitio
CREATE TABLE IF NOT EXISTS sitio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    cliente_id UUID NOT NULL REFERENCES cliente(id) ON DELETE CASCADE,
    zona_id UUID NOT NULL REFERENCES zona(id) ON DELETE RESTRICT,
    direccion TEXT NOT NULL,
    reglas JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================
-- 4. FLUJO TRANSACCIONAL (OPERACIÓN)
-- ==========================================

-- Tabla: solicitud
CREATE TABLE IF NOT EXISTS solicitud (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    cliente_id UUID NOT NULL REFERENCES cliente(id) ON DELETE CASCADE,
    sitio_id UUID NOT NULL REFERENCES sitio(id) ON DELETE RESTRICT,
    categoria_id UUID NOT NULL REFERENCES categoria_servicio(id) ON DELETE RESTRICT,
    zona_id UUID NOT NULL REFERENCES zona(id) ON DELETE RESTRICT,
    aliado_id UUID REFERENCES aliado(id) ON DELETE SET NULL,
    estado TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla: cotizacion
CREATE TABLE IF NOT EXISTS cotizacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    solicitud_id UUID NOT NULL REFERENCES solicitud(id) ON DELETE CASCADE,
    aliado_id UUID NOT NULL REFERENCES aliado(id) ON DELETE CASCADE,
    valor_mano_obra DECIMAL(12, 2) NOT NULL,
    valor_materiales DECIMAL(12, 2) NOT NULL,
    estado TEXT NOT NULL,
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla: mensaje
CREATE TABLE IF NOT EXISTS mensaje (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    solicitud_id UUID NOT NULL REFERENCES solicitud(id) ON DELETE CASCADE,
    remitente_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    contenido TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    leido_at TIMESTAMPTZ
);

-- Tabla: evento_servicio
CREATE TABLE IF NOT EXISTS evento_servicio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    solicitud_id UUID NOT NULL REFERENCES solicitud(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    tipo_evento TEXT NOT NULL,
    descripcion TEXT,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla: calificacion
CREATE TABLE IF NOT EXISTS calificacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    solicitud_id UUID NOT NULL REFERENCES solicitud(id) ON DELETE CASCADE,
    autor_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    destinatario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    puntaje INT NOT NULL,
    comentario TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla: notificacion
CREATE TABLE IF NOT EXISTS notificacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL,
    canal TEXT NOT NULL,
    payload JSONB,
    enviado_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    leido_at TIMESTAMPTZ
);

-- ==========================================
-- REGISTRO DE LA MIGRACIÓN
-- ==========================================
INSERT INTO schema_migrations (version, description)
VALUES ('001', 'Initial database schema with 17 core tables and pgcrypto')
ON CONFLICT (version) DO NOTHING;
