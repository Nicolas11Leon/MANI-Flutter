-- =====================================================================
-- CFG-04: Script de Validación y Aserción de Aislamiento Multi-Tenant
-- =====================================================================
-- Verifica matemáticamente y relacionalmente que no exista contaminación
-- cruzada (cross-tenant leakage) entre los datos de QA.
-- =====================================================================

\echo '====================================================================='
\echo 'INICIANDO VALIDACIÓN DE AISLAMIENTO MULTI-TENANT (CFG-04)'
\echo '====================================================================='

-- 1. Resumen de Entidades por Tenant
SELECT 
    t.slug AS tenant_slug,
    t.nombre AS tenant_nombre,
    COUNT(DISTINCT u.id) AS total_usuarios,
    COUNT(DISTINCT cs.id) AS total_categorias,
    COUNT(DISTINCT a.id) AS total_aliados,
    COUNT(DISTINCT c.id) AS total_clientes,
    COUNT(DISTINCT s.id) AS total_solicitudes,
    COUNT(DISTINCT cot.id) AS total_cotizaciones
FROM public.tenant t
LEFT JOIN public.usuario u ON u.tenant_id = t.id
LEFT JOIN public.categoria_servicio cs ON cs.tenant_id = t.id
LEFT JOIN public.aliado a ON a.tenant_id = t.id
LEFT JOIN public.cliente c ON c.tenant_id = t.id
LEFT JOIN public.solicitud s ON s.tenant_id = t.id
LEFT JOIN public.cotizacion cot ON cot.tenant_id = t.id
WHERE t.slug IN ('plomeria-express', 'electricistas-pro')
GROUP BY t.id, t.slug, t.nombre
ORDER BY t.slug;

-- 2. Detección de Contaminación Cruzada en Solicitudes
-- Ninguna solicitud debe apuntar a un cliente de otro tenant
SELECT 
    COUNT(*) AS fugas_solicitud_cliente
FROM public.solicitud s
JOIN public.cliente c ON s.cliente_id = c.id
WHERE s.tenant_id <> c.tenant_id;

-- Ninguna solicitud debe apuntar a una categoría de otro tenant
SELECT 
    COUNT(*) AS fugas_solicitud_categoria
FROM public.solicitud s
JOIN public.categoria_servicio cs ON s.categoria_id = cs.id
WHERE s.tenant_id <> cs.tenant_id;

-- Ninguna solicitud asignada debe apuntar a un aliado de otro tenant
SELECT 
    COUNT(*) AS fugas_solicitud_aliado
FROM public.solicitud s
JOIN public.aliado a ON s.aliado_id = a.id
WHERE s.tenant_id <> a.tenant_id;

-- Ninguna cotización debe apuntar a una solicitud de otro tenant
SELECT 
    COUNT(*) AS fugas_cotizacion_solicitud
FROM public.cotizacion cot
JOIN public.solicitud s ON cot.solicitud_id = s.id
WHERE cot.tenant_id <> s.tenant_id;

-- Ningún mensaje debe enviarse con remitente de otro tenant
SELECT 
    COUNT(*) AS fugas_mensaje_usuario
FROM public.mensaje m
JOIN public.usuario u ON m.remitente_id = u.id
WHERE m.tenant_id <> u.tenant_id;

-- 3. Aserción de Aislamiento Estricto
DO $$
DECLARE
    v_fugas INT := 0;
    v_fugas_sol_cli INT;
    v_fugas_sol_cat INT;
    v_fugas_sol_ali INT;
    v_fugas_cot INT;
    v_fugas_msg INT;
    v_count_t1 INT;
    v_count_t2 INT;
BEGIN
    -- Validar existencia de datos en al menos 2 tenants
    SELECT COUNT(*) INTO v_count_t1 FROM public.usuario WHERE tenant_id = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
    SELECT COUNT(*) INTO v_count_t2 FROM public.usuario WHERE tenant_id = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22';

    IF v_count_t1 = 0 OR v_count_t2 = 0 THEN
        RAISE EXCEPTION 'FALLO CFG-04: Se requieren datos en al menos 2 tenants para QA. Tenant A: %, Tenant B: %', v_count_t1, v_count_t2;
    END IF;

    -- Calcular fugas
    SELECT COUNT(*) INTO v_fugas_sol_cli FROM public.solicitud s JOIN public.cliente c ON s.cliente_id = c.id WHERE s.tenant_id <> c.tenant_id;
    SELECT COUNT(*) INTO v_fugas_sol_cat FROM public.solicitud s JOIN public.categoria_servicio cs ON s.categoria_id = cs.id WHERE s.tenant_id <> cs.tenant_id;
    SELECT COUNT(*) INTO v_fugas_sol_ali FROM public.solicitud s JOIN public.aliado a ON s.aliado_id = a.id WHERE s.tenant_id <> a.tenant_id;
    SELECT COUNT(*) INTO v_fugas_cot FROM public.cotizacion cot JOIN public.solicitud s ON cot.solicitud_id = s.id WHERE cot.tenant_id <> s.tenant_id;
    SELECT COUNT(*) INTO v_fugas_msg FROM public.mensaje m JOIN public.usuario u ON m.remitente_id = u.id WHERE m.tenant_id <> u.tenant_id;

    v_fugas := v_fugas_sol_cli + v_fugas_sol_cat + v_fugas_sol_ali + v_fugas_cot + v_fugas_msg;

    IF v_fugas > 0 THEN
        RAISE EXCEPTION 'FALLO DE AISLAMIENTO MULTI-TENANT: Se detectaron % inconsistencias cruzadas entre tenants.', v_fugas;
    ELSE
        RAISE NOTICE '>>> EXCELENTE: 0 VIOLACIONES DE AISLAMIENTO DETECTADAS. TENANT A (% registros) Y TENANT B (% registros) ESTÁN 100%% AISLADOS.', v_count_t1, v_count_t2;
    END IF;
END $$;

\echo '====================================================================='
\echo 'VALIDACIÓN DE AISLAMIENTO MULTI-TENANT FINALIZADA CON ÉXITO'
\echo '====================================================================='
