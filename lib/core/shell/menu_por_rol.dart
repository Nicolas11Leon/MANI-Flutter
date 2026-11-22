import 'package:flutter/material.dart';
import 'package:mani/core/session/rol_usuario.dart';

/// Entrada del menú superior: etiqueta visible, icono y ruta de go_router.
class EntradaMenu {
  const EntradaMenu({
    required this.etiqueta,
    required this.icono,
    required this.ruta,
  });

  final String etiqueta;
  final IconData icono;
  final String ruta;
}

const _inicio = EntradaMenu(
  etiqueta: 'Inicio',
  icono: Icons.home_outlined,
  ruta: '/inicio',
);

/// Bandeja de avisos (SCRUM-882 y 884): la ven todos los roles.
const _avisos = EntradaMenu(
  etiqueta: 'Avisos',
  icono: Icons.notifications_none,
  ruta: '/perfil/avisos',
);

const _miPerfil = EntradaMenu(
  etiqueta: 'Mi perfil',
  icono: Icons.person_outline,
  ruta: '/perfil/editar',
);

/// Consulta del catálogo geográfico (HU-M04-07), para los tres roles.
const _mapaZonas = EntradaMenu(
  etiqueta: 'Mapa de zonas',
  icono: Icons.map_outlined,
  ruta: '/catalogo/mapa',
);

/// Pantallas del cliente.
const _entradasCliente = [
  EntradaMenu(
    etiqueta: 'Nueva solicitud',
    icono: Icons.add_circle_outline,
    ruta: '/cliente/solicitudes/nueva',
  ),
  EntradaMenu(
    etiqueta: 'Mis solicitudes',
    icono: Icons.list_alt_outlined,
    ruta: '/cliente/solicitudes',
  ),
  // Quejas del cliente (SCRUM-895).
  EntradaMenu(
    etiqueta: 'Mis quejas',
    icono: Icons.feedback_outlined,
    ruta: '/cliente/quejas',
  ),
];

// Pantallas del aliado.
const _entradasAliado = [
  EntradaMenu(
    etiqueta: 'Solicitudes',
    icono: Icons.inbox_outlined,
    ruta: '/aliado/solicitudes',
  ),
  // Historial de trabajos (SCRUM-880).
  EntradaMenu(
    etiqueta: 'Historial',
    icono: Icons.history,
    ruta: '/aliado/historial',
  ),
  EntradaMenu(
    etiqueta: 'Cobertura',
    icono: Icons.checklist_outlined,
    ruta: '/aliado/cobertura',
  ),
  EntradaMenu(
    etiqueta: 'Categorías',
    icono: Icons.category_outlined,
    ruta: '/categories',
  ),
  EntradaMenu(
    etiqueta: 'Mis cobros',
    icono: Icons.payments_outlined,
    ruta: '/aliado/cobros',
  ),
  EntradaMenu(
    etiqueta: 'Disponibilidad',
    icono: Icons.event_busy_outlined,
    ruta: '/aliado/disponibilidad',
  ),
];

// Administración de un tenant: solo su empresa, sin pantallas de cliente,
// de aliado ni de la plataforma.
const _entradasAdminTenant = [
  EntradaMenu(
    etiqueta: 'Verificación de aliados',
    icono: Icons.verified_user_outlined,
    ruta: '/admin/verificacion-aliados',
  ),
  EntradaMenu(
    etiqueta: 'Categorías',
    icono: Icons.category_outlined,
    ruta: '/admin/categorias',
  ),
  // Política de cancelación tardía (SCRUM-878).
  EntradaMenu(
    etiqueta: 'Cancelaciones',
    icono: Icons.event_busy_outlined,
    ruta: '/admin/politica-cancelacion',
  ),
  // Tarifario y cotizaciones fuera de rango (M-10: SCRUM-885 y 887).
  EntradaMenu(
    etiqueta: 'Tarifario',
    icono: Icons.price_change_outlined,
    ruta: '/admin/tarifas',
  ),
  EntradaMenu(
    etiqueta: 'Fuera de rango',
    icono: Icons.report_outlined,
    ruta: '/admin/reportes/cotizaciones-fuera-de-rango',
  ),
  // Empleados directos (SCRUM-1376): los registra el administrador, como exige Core.
  EntradaMenu(
    etiqueta: 'Empleados',
    icono: Icons.badge_outlined,
    ruta: '/admin/empleados/nuevo',
  ),
  // Auditoría de transacciones (SCRUM-889) y conversación de una queja (SCRUM-883).
  EntradaMenu(
    etiqueta: 'Auditoría',
    icono: Icons.fact_check_outlined,
    ruta: '/admin/auditoria-transacciones',
  ),
  EntradaMenu(
    etiqueta: 'Conversaciones',
    icono: Icons.forum_outlined,
    ruta: '/admin/conversaciones',
  ),
  // M-01 (SCRUM-1366).
  EntradaMenu(
    etiqueta: 'Reglas',
    icono: Icons.rule_outlined,
    ruta: '/admin/reglas',
  ),
  // M-12 (SCRUM-896 y 900).
  EntradaMenu(
    etiqueta: 'Quejas',
    icono: Icons.support_agent_outlined,
    ruta: '/admin/quejas',
  ),
  EntradaMenu(
    etiqueta: 'Métricas',
    icono: Icons.insights_outlined,
    ruta: '/admin/metricas',
  ),
  // Límites de zonas y barrios del catálogo; no declara cobertura (HU-M04-07).
  _mapaZonas,
];

// Administración de la plataforma (SCRUM-901).
const _tenants = EntradaMenu(
  etiqueta: 'Tenants',
  icono: Icons.domain_outlined,
  ruta: '/plataforma/tenants',
);

/// Entradas propias de cada rol, sin inicio, avisos ni perfil.
List<EntradaMenu> _propiasDe(RolUsuario rol) => switch (rol) {
  RolUsuario.cliente => _entradasCliente,
  RolUsuario.aliado => _entradasAliado,
  RolUsuario.adminTenant => _entradasAdminTenant,
  _ => const [],
};

/// Entradas del menú superior por rol (US-11.2.1 / SCRUM-1444).
///
/// - El administrador del tenant solo ve la administración de su empresa.
/// - El administrador de plataforma ve los tenants y las pantallas del rol con
///   el que actúa ([actuandoComo]): las de administrador del tenant elegido
///   por omisión, o las del cliente o aliado que eligió en «Actuar como»
///   (SCRUM-901). Así puede usar todas las funciones del sistema.
///
/// Solo se listan rutas que ya existen en `app_router.dart`. Ocultar una
/// entrada no protege la ruta: el bloqueo por rol es de SCRUM-1445 y la
/// autorización la hace el servidor.
List<EntradaMenu> entradasMenuPara(
  RolUsuario rol, {
  RolUsuario actuandoComo = RolUsuario.adminTenant,
}) {
  switch (rol) {
    case RolUsuario.cliente:
      return const [_inicio, ..._entradasCliente, _avisos, _miPerfil];
    case RolUsuario.aliado:
      return const [_inicio, ..._entradasAliado, _avisos, _miPerfil];
    case RolUsuario.adminTenant:
      return const [_inicio, ..._entradasAdminTenant, _avisos, _miPerfil];
    case RolUsuario.adminPlataforma:
      return [
        _inicio,
        _tenants,
        ..._propiasDe(actuandoComo),
        _avisos,
        _miPerfil,
      ];
    case RolUsuario.desconocido:
      return const [_inicio, _miPerfil];
  }
}

// Nombre legible del rol para la cabecera.
String etiquetaRol(RolUsuario rol) {
  switch (rol) {
    case RolUsuario.cliente:
      return 'Cliente';
    case RolUsuario.aliado:
      return 'Aliado';
    case RolUsuario.adminTenant:
      return 'Administrador';
    case RolUsuario.adminPlataforma:
      return 'Administración de plataforma';
    case RolUsuario.desconocido:
      return 'Sin rol';
  }
}
