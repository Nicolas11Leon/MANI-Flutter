import 'dart:async';

import 'package:flutter/material.dart' show Icons, ScaffoldMessenger, SnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mani/features/platform/data/tenants_datasource.dart';
import 'package:mani/features/audit/presentation/auditoria_page.dart';
import 'package:mani/features/conversation_review/presentation/conversacion_queja_page.dart';
import 'package:mani/features/notifications/domain/aviso.dart';
import 'package:mani/features/notifications/presentation/avisos_page.dart';
import 'package:mani/core/session/contexto_plataforma.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/session/guardas_ruta.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/app_shell.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/refresco_periodico.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/features/asignacion/presentation/bloc/solicitudes_aliado_cubit.dart';
import 'package:mani/features/asignacion/presentation/pages/solicitudes_aliado_page.dart';
import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:mani/features/auth/presentation/pages/login_page.dart';
import 'package:mani/features/home/data/resumen_inicio.dart';
import 'package:mani/features/home/presentation/pages/inicio_page.dart';
import 'package:mani/features/auth/presentation/pages/registro_cliente_page.dart';
import 'package:mani/features/auth/presentation/pages/registro_cliente_empresa_page.dart';
import 'package:mani/features/auth/domain/entities/enlace_recuperacion.dart';
import 'package:mani/features/auth/presentation/pages/olvide_contrasena_page.dart';
import 'package:mani/features/auth/presentation/pages/restablecer_contrasena_page.dart';
import 'package:mani/features/messaging/presentation/chat_cubit.dart';
import 'package:mani/features/messaging/presentation/chat_page.dart';
import 'package:mani/core/platform/guardador_archivo.dart';
import 'package:mani/core/platform/selector_foto_perfil.dart';
import 'package:mani/features/payments/data/cobros_datasource.dart';
import 'package:mani/features/payments/presentation/cobros_aliado_page.dart';
import 'package:mani/features/payments/presentation/pago_cubit.dart';
import 'package:mani/features/payments/presentation/pago_sandbox_page.dart';
import 'package:mani/features/auth/presentation/pages/registro_aliado_page.dart';
import 'package:mani/features/auth/presentation/pages/registro_aliado_empresa_page.dart';
import 'package:mani/features/availability/presentation/pages/disponibilidad_page.dart';
import 'package:mani/features/profile_categories/presentation/pages/categories_page.dart';
import 'package:mani/features/catalog/map/presentation/bloc/mapa_cubit.dart';
import 'package:mani/features/catalog/map/presentation/pages/mapa_zonas_page.dart';
import 'package:mani/features/profiles/coverage/presentation/pages/declarar_cobertura_page.dart';
import 'package:mani/features/profiles/verification/presentation/bloc/bandeja_verificacion_cubit.dart';
import 'package:mani/features/profiles/verification/presentation/pages/bandeja_verificacion_page.dart';
import 'package:mani/features/services/categories/presentation/bloc/categorias_cubit.dart';
import 'package:mani/features/services/categories/presentation/pages/gestion_categorias_page.dart';
import 'package:mani/features/services/requests/presentation/bloc/crear_solicitud_cubit.dart';
import 'package:mani/features/services/requests/presentation/pages/crear_solicitud_page.dart';
import 'package:mani/features/services/eligible_allies/presentation/aliados_elegibles_cubit.dart';
import 'package:mani/features/services/eligible_allies/presentation/aliados_elegibles_page.dart';
import 'package:mani/features/services/tracking/presentation/mis_solicitudes_cubit.dart';
import 'package:mani/features/services/tracking/presentation/mis_solicitudes_page.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_cubit.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart';
import 'package:mani/features/services/additions/presentation/adiciones_cubit.dart';
import 'package:mani/features/services/additions/presentation/adiciones_seccion.dart';
import 'package:mani/features/services/execution/presentation/ejecucion_cubit.dart';
import 'package:mani/features/services/execution/presentation/ejecucion_seccion.dart';
import 'package:mani/features/services/events/data/cola_eventos.dart';
import 'package:mani/features/services/events/presentation/eventos_cubit.dart';
import 'package:mani/features/services/events/presentation/eventos_seccion.dart';
import 'package:mani/features/services/ratings/data/calificacion_cierre_datasource.dart';
import 'package:mani/features/services/ratings/presentation/calificacion_cierre_cubit.dart';
import 'package:mani/features/services/ratings/presentation/calificacion_cierre_widgets.dart';
import 'package:mani/features/profiles/site_rules/presentation/bloc/reglas_sitio_cubit.dart';
import 'package:mani/features/profiles/site_rules/presentation/pages/reglas_sitio_page.dart';
import 'package:mani/features/profiles/company_sites/presentation/bloc/sedes_empresa_cubit.dart';
import 'package:mani/features/profiles/company_sites/presentation/pages/gestion_sedes_empresa_page.dart';
import 'package:mani/features/profiles/direct_employees/presentation/bloc/empleado_directo_cubit.dart';
import 'package:mani/features/profiles/direct_employees/presentation/pages/registrar_empleado_directo_page.dart';
import 'package:mani/features/profiles/own_profile/presentation/pages/editar_perfil_page.dart';
import 'package:mani/features/services/ratings/presentation/politica_cancelacion_page.dart';
import 'package:mani/features/tariffs/data/tarifas_datasource.dart';
import 'package:mani/features/tariffs/presentation/referencia_tarifa_seccion.dart';
import 'package:mani/features/tariffs/presentation/alerta_tarifa_cotizacion.dart';
import 'package:mani/features/tariffs/presentation/reporte_fuera_rango_page.dart';
import 'package:mani/features/tariffs/presentation/tarifario_cubit.dart';
import 'package:mani/features/tariffs/presentation/tarifario_page.dart';
import 'package:mani/features/complaints/data/quejas_datasource.dart';
import 'package:mani/features/complaints/presentation/dialogo_queja.dart';
import 'package:mani/features/complaints/presentation/quejas_cubit.dart';
import 'package:mani/features/complaints/presentation/quejas_page.dart';
import 'package:mani/features/metrics/presentation/metricas_page.dart';
import 'package:mani/features/platform/presentation/tenants_page.dart';
import 'package:mani/features/tenant_rules/presentation/tenant_rules_cubit.dart';
import 'package:mani/features/tenant_rules/presentation/reglas_operativas_page.dart';

/// Notifica a go_router cada vez que cambia el estado de autenticación de
/// Supabase, para que el `redirect` de abajo se reevalúe automáticamente
/// (por ejemplo, cuando expira la sesión o el usuario cierra sesión).
class _AuthChangeNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  _AuthChangeNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Rutas accesibles sin sesión activa (login y los flujos de registro).
const _publicPaths = {
  '/login',
  '/register-cliente',
  '/register-aliado',
  '/register-empresa',
  '/register-cliente-empresa',
  '/forgot-password',
  '/reset-password',
};

bool _isPublicPath(String path) {
  return _publicPaths.contains(path) ||
      path == '/register' ||
      path == '/registro' ||
      path.startsWith('/registro-');
}

/// Chat de un servicio (SCRUM-881). El Cubit consulta a Core cada pocos
/// segundos mientras la pantalla está abierta.
Widget _pantallaChat(String solicitudId) => BlocProvider(
  create: (_) => ChatCubit(sl(), solicitudId)..iniciar(),
  child: const ChatPage(),
);

/// Lleva de un aviso a la pantalla de su solicitud según el rol de la sesión
/// (SCRUM-882 y 884): el mensaje nuevo, al chat; el resto, a la pantalla del
/// servicio. El administrador no participa en los servicios y no navega.
void _abrirAviso(Aviso aviso) {
  final id = aviso.solicitudId;
  if (id == null) return;
  final rol = rolDesdeAccessToken(
    Supabase.instance.client.auth.currentSession?.accessToken,
  );
  final base = switch (rol) {
    RolUsuario.cliente => '/cliente/solicitudes/$id',
    RolUsuario.aliado => '/aliado/solicitudes/$id',
    _ => null,
  };
  if (base == null) return;
  appRouter.push(aviso.esMensaje ? '$base/chat' : '$base/cotizacion');
}

/// Pantalla del servicio de una solicitud: la cotización (SCRUM-865 y 867), la
/// ejecución (SCRUM-868), las adiciones (SCRUM-872) y la bitácora (SCRUM-869,
/// 870 y 873). Cada parte tiene su Cubit y consulta a Core por su lado.
Widget _pantallaServicio(
  String solicitudId, {
  required bool esAliado,
}) => MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => CotizacionCubit(sl(), solicitudId)..cargar()),
    BlocProvider(create: (_) => EjecucionCubit(sl(), solicitudId)..cargar()),
    BlocProvider(create: (_) => AdicionesCubit(sl(), solicitudId)..cargar()),
    // Calificación bidireccional y cierre (SCRUM-874, 875 y 1418).
    BlocProvider(
      create: (_) =>
          CalificacionCierreCubit(sl(), solicitudId: solicitudId)..cargar(),
    ),
    BlocProvider(
      create: (_) => EventosCubit(
        sl(),
        solicitudId,
        // Solo el aliado registra eventos, y solo él los deja en la cola sin
        // conexión (SCRUM-873).
        cola: esAliado && sl.isRegistered<ColaEventos>() ? sl() : null,
        usuarioActual: () => sl<SupabaseClient>().auth.currentUser?.id,
      )..cargar(),
    ),
    if (sl.isRegistered<FuenteModuloM08>())
      BlocProvider(
        create: (_) =>
            CalificacionCierreCubit(sl(), solicitudId: solicitudId)..cargar(),
      ),
  ],
  child: Builder(
    // Sondeo de estado (SCRUM-1636 / SCRUM-1644): el cliente ve que el aliado
    // cotizó, inició, pidió una adición o finalizó sin recargar, y el aliado ve
    // la respuesta del cliente. Solo mientras la pantalla está a la vista.
    builder: (context) => RefrescoPeriodico(
      onRefrescar: () => Future.wait([
        context.read<CotizacionCubit>().cargar(silencioso: true),
        context.read<EjecucionCubit>().cargar(silencioso: true),
        context.read<AdicionesCubit>().cargar(silencioso: true),
        // Calificación y cierre (SCRUM-1710): el cliente ve que el aliado
        // calificó o cerró. Solo si la feature está registrada, igual que su
        // sección.
        if (sl.isRegistered<FuenteModuloM08>())
          context.read<CalificacionCierreCubit>().cargar(silencioso: true),
      ]),
      child: CotizacionPage(
        esAliado: esAliado,
        // Tarifa de referencia vigente de la categoría (HU-M10-02 / SCRUM-886).
        encabezado: ReferenciaTarifaSeccion(
          fuente: sl<FuenteTarifas>(),
          solicitudId: solicitudId,
        ),
        // Alerta de tarifa bidireccional de la versión vigente (HU-M06-02 /
        // SCRUM-866): la ven el aliado y el cliente con el resultado de Rules.
        alertaTarifa: (cotizacionId) => AlertaTarifaCotizacion(
          key: ValueKey('alerta-tarifa-$cotizacionId'),
          fuente: sl<FuenteTarifas>(),
          cotizacionId: cotizacionId,
          esAliado: esAliado,
        ),
        // El pago cobra el total vigente: cotización aceptada + adiciones
        // aceptadas (SCRUM-872). Sin resumen, el total de la cotización.
        alPagar: esAliado
            ? null
            : (cotizacionId, total) => context.push(
                '/cliente/pagos/$cotizacionId',
                extra:
                    context
                        .read<AdicionesCubit>()
                        .state
                        .datos
                        ?.resumen
                        ?.totalVigente ??
                    total,
              ),
        // Chat del servicio (HU-M09-02 / SCRUM-881): solo participan el cliente
        // y el aliado asignado; lo valida Core.
        accionEncabezado: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 270),
          child: ManiButton(
            key: const Key('btn-abrir-chat'),
            etiqueta: esAliado
                ? 'Mensajes con el cliente'
                : 'Mensajes con el aliado',
            icono: Icons.chat_bubble_outline,
            variante: ManiButtonVariante.secundario,
            onPressed: () => context.push(
              '/${esAliado ? 'aliado' : 'cliente'}/solicitudes/$solicitudId/chat',
            ),
          ),
        ),
        // Adiciones por imprevisto (SCRUM-872): cambian el total a pagar, por eso
        // van con los pagos. El aliado las pide con el servicio en ejecución; el
        // cliente decide. Core aplica el tope.
        pagosExtra: BlocBuilder<EjecucionCubit, EjecucionState>(
          buildWhen: (a, b) =>
              a.ejecucion?.enEjecucion != b.ejecucion?.enEjecucion,
          builder: (context, state) => AdicionesSeccion(
            esAliado: esAliado,
            puedePedir: esAliado && (state.ejecucion?.enEjecucion ?? false),
          ),
        ),
        // Ejecución (SCRUM-868) y bitácora. El aliado registra eventos solo con
        // el servicio en ejecución (la regla definitiva la aplica Core,
        // MANI-EVT-409E); el cliente la consulta en solo lectura (SCRUM-870).
        bitacora: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EjecucionSeccion(esAliado: esAliado),
            BlocBuilder<EjecucionCubit, EjecucionState>(
              buildWhen: (a, b) =>
                  a.ejecucion?.enEjecucion != b.ejecucion?.enEjecucion,
              builder: (context, state) => EventosSeccion(
                puedeRegistrar:
                    esAliado && (state.ejecucion?.enEjecucion ?? false),
                urlOpener: sl(),
                selectorFotos: esAliado ? sl() : null,
              ),
            ),
          ],
        ),
        // Calificación y cierre (SCRUM-874, 875 y 1418).
        calificacion: sl.isRegistered<FuenteModuloM08>()
            ? BlocListener<EjecucionCubit, EjecucionState>(
                listenWhen: (a, b) =>
                    a.ejecucion?.finalizada != b.ejecucion?.finalizada &&
                    (b.ejecucion?.finalizada ?? false),
                listener: (context, _) =>
                    context.read<CalificacionCierreCubit>().cargar(),
                child: CalificacionServicioFinalizado(esAliado: esAliado),
              )
            : null,
        alRefrescar: () async {
          await Future.wait([
            context.read<EjecucionCubit>().cargar(),
            context.read<AdicionesCubit>().cargar(),
            context.read<EventosCubit>().cargar(),
            if (sl.isRegistered<FuenteModuloM08>())
              context.read<CalificacionCierreCubit>().cargar(),
          ]);
        },
      ),
    ),
  ),
);

/// Configuración de rutas declarativas limpias para MANI Web (sin hash #).
/// - `/login`: Pantalla de inicio de sesión
/// - `/register-cliente`: Pantalla independiente de registro para clientes (US-02.2.1)
/// - `/register-aliado`: Pantalla independiente de registro para aliados técnicos (US-02.1.1)
/// - `/register-empresa`: Pantalla independiente de registro para aliados empresas (US-02.1.2)
/// - `/register-cliente-empresa`: Registro de cliente empresa con NIT y representante (HU-M02-07)
/// - `/forgot-password` y `/reset-password`: Recuperación de contraseña (HU-M02-10)
/// - `/categories`: Pantalla de selección de categorías del aliado (US-03.1.3)
/// - `/aliado/cobertura`: Zona de cobertura del aliado (US-02.1.4)
/// - `/aliado/cobros`: Cobros del aliado: retención y liquidación simuladas (SCRUM-894)
/// - `/aliado/disponibilidad`: Ausencias del aliado, "No disponible" (US-02.1.6)
/// - `/cliente/solicitudes/nueva`: El cliente publica su solicitud con fotos (US-04.1.1)
/// - `/cliente/solicitudes`: Estado y zona declarada de las solicitudes del cliente (HU-M07-04)
/// - `/cliente/solicitudes/:id/aliados`: Aliados elegibles, por tipo y en el orden de Dispatch (SCRUM-1401)
/// - `/aliado/solicitudes`: Bandeja del aliado para aceptar/rechazar solicitudes (US-04.1.4)
/// - `/cliente/solicitudes/:id/cotizacion` y `/aliado/solicitudes/:id/cotizacion`: Pantalla del servicio:
///   cotización, ejecución y bitácora (US-04.2.1 a US-04.3.3)
/// - `/admin/verificacion-aliados`: Bandeja de verificación del admin del tenant (US-02.1.3)
/// - `/admin/categorias`: Catálogo de categorías de servicio del tenant (US-03.1.1)
/// - `/catalogo/mapa`: Mapa de zonas y barrios del catálogo, sin GPS en vivo (HU-M04-07)
///
/// El `redirect` protege cualquier ruta que no esté en `_publicPaths`: sin
/// sesión activa en Supabase el usuario va a `/login`, y con sesión una ruta
/// de otro rol lo devuelve al inicio del suyo (US-11.2.2 / SCRUM-1445,
/// `guardas_ruta.dart`). La autorización por rol la aplica, de todos modos,
/// el servidor con el token verificado.
final appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: _AuthChangeNotifier(),
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    return resolverRedireccion(
      ubicacion: state.matchedLocation,
      esPublica: _isPublicPath(state.matchedLocation),
      haySesion: session != null,
      rol: rolDesdeAccessToken(session?.accessToken),
    );
  },
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/login'),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    // Ruta independiente: Registro de Cliente (US-02.2.1)
    GoRoute(
      path: '/register-cliente',
      name: 'register-cliente',
      builder: (context, state) => const RegistroClientePage(),
    ),
    GoRoute(
      path: '/registro-cliente',
      redirect: (context, state) => '/register-cliente',
    ),
    // Recuperación de contraseña (HU-M02-10): el enlace del correo abre /reset-password con el token en la URL.
    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (context, state) => const OlvideContrasenaPage(),
    ),
    GoRoute(
      path: '/reset-password',
      name: 'reset-password',
      builder: (context, state) => RestablecerContrasenaPage(
        enlace: EnlaceRecuperacion.resolver(state.uri, Uri.base),
      ),
    ),
    // Ruta independiente: Registro de Cliente Empresa (HU-M02-07)
    GoRoute(
      path: '/register-cliente-empresa',
      name: 'register-cliente-empresa',
      builder: (context, state) => const RegistroClienteEmpresaPage(),
    ),
    // Ruta independiente: Registro de Aliado Técnico (US-02.1.1)
    GoRoute(
      path: '/register-aliado',
      name: 'register-aliado',
      builder: (context, state) => const RegistroAliadoPage(),
    ),
    GoRoute(
      path: '/registro-aliado',
      redirect: (context, state) => '/register-aliado',
    ),
    // Ruta independiente: Registro de Aliado Empresa (US-02.1.2)
    GoRoute(
      path: '/register-empresa',
      name: 'register-empresa',
      builder: (context, state) => const RegistroAliadoEmpresaPage(),
    ),
    GoRoute(
      path: '/registro-empresa',
      redirect: (context, state) => '/register-empresa',
    ),
    // Redirecciones por compatibilidad
    GoRoute(
      path: '/register',
      redirect: (context, state) {
        final rolParam = state.uri.queryParameters['rol']?.toLowerCase();
        if (rolParam == 'empresa') return '/register-empresa';
        if (rolParam == 'aliado') return '/register-aliado';
        return '/register-cliente';
      },
    ),
    GoRoute(
      path: '/registro',
      redirect: (context, state) => '/register-cliente',
    ),
    // Pantallas con sesión dentro del menú superior por rol (US-11.2.1 /
    // SCRUM-1444). El shell solo pinta: la autorización la aplica el servidor.
    ShellRoute(
      builder: (context, state, child) => AppShell(
        rol: rolDesdeAccessToken(
          Supabase.instance.client.auth.currentSession?.accessToken,
        ),
        ubicacion: state.matchedLocation,
        fuenteDatos: sl<FuenteDatosSesion>(),
        onNavegar: (ruta) => context.go(ruta),
        onCerrarSesion: () async {
          // El contexto del admin de plataforma no pasa a la siguiente sesión.
          if (sl.isRegistered<ContextoPlataforma>()) {
            sl<ContextoPlataforma>().limpiar();
          }
          await sl<IAuthRepository>().signOut();
        },
        // Tenant elegido y «Actuar como» del admin de plataforma (SCRUM-901).
        contextoPlataforma: sl.isRegistered<ContextoPlataforma>()
            ? sl<ContextoPlataforma>()
            : null,
        fuenteTenants: sl.isRegistered<FuenteTenants>()
            ? sl<FuenteTenants>()
            : null,
        fuenteUsuarios: sl.isRegistered<FuenteUsuariosTenant>()
            ? sl<FuenteUsuariosTenant>()
            : null,
        child: child,
      ),
      routes: [
        // Inicio por tipo de usuario (US-11.2.3 / SCRUM-1446).
        GoRoute(
          path: rutaInicio,
          name: 'inicio',
          builder: (context, state) => InicioPage(
            rol: rolDesdeAccessToken(
              Supabase.instance.client.auth.currentSession?.accessToken,
            ),
            fuenteSesion: sl<FuenteDatosSesion>(),
            fuenteResumen: sl<FuenteResumenInicio>(),
            contextoPlataforma: sl.isRegistered<ContextoPlataforma>()
                ? sl<ContextoPlataforma>()
                : null,
            onNavegar: (ruta) => context.go(ruta),
            onCerrarSesion: () async {
              await sl<IAuthRepository>().signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ),
        // Ruta independiente: Selección de categorías del aliado (US-03.1.3)
        GoRoute(
          path: '/categories',
          name: 'categories',
          builder: (context, state) => const CategoriesPage(),
        ),
        // Ruta independiente: Zona de Cobertura (US-02.1.4)
        GoRoute(
          path: '/aliado/cobertura',
          name: 'declarar-cobertura',
          // El mapa va dentro: el aliado marca por lista y ve pintado lo que
          // lleva marcado, sin cambiar de pantalla (HU-M04-07 / SCRUM-1396).
          builder: (context, state) => BlocProvider(
            // Panorámica: para elegir cobertura hace falta ver la ciudad
            // entera, no una localidad cada vez.
            create: (_) => sl<MapaCubit>()..cargarPanoramica(),
            child: DeclararCoberturaPage(controller: sl(), conMapa: true),
          ),
        ),
        // Configuración y consulta de reglas contextuales de un sitio (US-02.2.3 / SCRUM-853)
        GoRoute(
          path: '/sitios/:id/reglas',
          name: 'reglas-sitio',
          builder: (context, state) {
            final siteId = state.pathParameters['id'] ?? '';
            final esAliado = state.uri.queryParameters['esAliado'] == 'true';
            return BlocProvider(
              create: (_) => sl<ReglasSitioCubit>(),
              child: ReglasSitioPage(siteId: siteId, esVistaAliado: esAliado),
            );
          },
        ),
        // Edición del perfil propio de cliente o aliado (US-02.3.1 / SCRUM-854)
        GoRoute(
          path: '/perfil/editar',
          name: 'editar-perfil',
          builder: (context, state) => EditarPerfilPage(
            dataSource: sl(),
            selectorImagen: seleccionarFotoPerfil,
          ),
        ),
        // Gestión de múltiples sedes del cliente empresa (US-02.2.2 /
        // SCRUM-852, SCRUM-1387). Core resuelve el cliente por el token.
        GoRoute(
          path: '/cliente/sedes',
          name: 'sedes-empresa',
          // El mapa va dentro: el cliente lo mira para comprobar dónde caen
          // sus sedes (HU-M04-07 / SCRUM-1396).
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => sl<SedesEmpresaCubit>()),
              BlocProvider(create: (_) => sl<MapaCubit>()..cargar()),
            ],
            child: const GestionSedesEmpresaPage(conMapa: true),
          ),
        ),
        // Registro de empleado directo (US-02.1.5 / SCRUM-850, SCRUM-1376). Lo hace el
        // administrador del tenant: Core exige ese rol, y el catálogo de categorías que
        // la pantalla consulta (`/catalog/categories`) también es de administración.
        GoRoute(
          path: '/admin/empleados/nuevo',
          name: 'registrar-empleado-directo',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<EmpleadoDirectoCubit>(),
            child: const RegistrarEmpleadoDirectoPage(),
          ),
        ),
        // Crear solicitud (US-04.1.1): el cliente describe su problema y adjunta
        // fotos; el tenant y el cliente salen de la sesión, nunca de la app.
        GoRoute(
          path: '/cliente/solicitudes/nueva',
          name: 'crear-solicitud',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<CrearSolicitudCubit>()..cargar(),
            child: CrearSolicitudPage(selectorFotos: sl()),
          ),
        ),
        // Mis solicitudes (HU-M07-04 / SCRUM-871): estado y zona declarada,
        // sin rastreo en vivo del aliado.
        GoRoute(
          path: '/cliente/solicitudes',
          name: 'mis-solicitudes',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<MisSolicitudesCubit>()..cargar(),
            child: MisSolicitudesPage(
              onNuevaSolicitud: () => context.go('/cliente/solicitudes/nueva'),
              onVerCotizacion: (id) =>
                  context.push('/cliente/solicitudes/$id/cotizacion'),
              onVerAliados: (id) =>
                  context.push('/cliente/solicitudes/$id/aliados'),
              onPresentarQueja: (id) async {
                final queja = await presentarQueja(
                  context,
                  fuente: sl<FuenteQuejas>(),
                  solicitudId: id,
                );
                if (queja != null && context.mounted) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(
                      key: Key('queja-registrada'),
                      content: Text(
                        'Registramos tu queja. La verás en «Mis quejas».',
                      ),
                    ),
                  );
                }
              },
              // Penalización por cancelación tardía antes de confirmar (SCRUM-878).
              previsualizarCancelacion: (id) =>
                  sl<FuenteModuloM08>().previsualizarCancelacion(id),
            ),
          ),
        ),
        // Aliados elegibles de la solicitud (SCRUM-1398, 1400 y 1401): filtro
        // por tipo y el orden exacto de Dispatch. Solo el cliente (`/cliente/`).
        GoRoute(
          path: '/cliente/solicitudes/:id/aliados',
          name: 'aliados-elegibles',
          builder: (context, state) => BlocProvider(
            create: (_) =>
                AliadosElegiblesCubit(sl(), state.pathParameters['id']!)
                  ..cargar(),
            child: const AliadosElegiblesPage(),
          ),
        ),
        // Cotización del cliente (US-04.2.3 / SCRUM-867): acepta, rechaza o
        // pide ajuste. Solo el cliente dueño responde; lo valida Core.
        GoRoute(
          path: '/cliente/solicitudes/:id/cotizacion',
          name: 'cotizacion-cliente',
          builder: (context, state) =>
              _pantallaServicio(state.pathParameters['id']!, esAliado: false),
        ),
        // Pago de la cotización aceptada en el sandbox (HU-M11-01 / SCRUM-1432):
        // simulador sin dinero ni tarjetas reales. El monto lo calcula Core;
        // `extra` solo trae el total para mostrarlo antes de pagar.
        GoRoute(
          path: '/cliente/pagos/:cotizacionId',
          name: 'pago-sandbox',
          builder: (context, state) => BlocProvider(
            create: (_) =>
                PagoCubit(sl(), state.pathParameters['cotizacionId']!),
            child: PagoSandboxPage(
              total: state.extra as double?,
              cobros: sl<FuenteCobros>(),
              guardador: sl<GuardadorArchivo>(),
            ),
          ),
        ),
        // Chat del servicio (HU-M09-02 / SCRUM-881) para el cliente y para el
        // aliado asignado. Core decide quién participa; la app solo consulta.
        GoRoute(
          path: '/cliente/solicitudes/:id/chat',
          name: 'chat-cliente',
          builder: (context, state) =>
              _pantallaChat(state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/aliado/solicitudes/:id/chat',
          name: 'chat-aliado',
          builder: (context, state) =>
              _pantallaChat(state.pathParameters['id']!),
        ),
        // Cotización del aliado (US-04.2.1 / SCRUM-865): solo el aliado
        // asignado emite; lo valida Core.
        GoRoute(
          path: '/aliado/solicitudes/:id/cotizacion',
          name: 'cotizacion-aliado',
          builder: (context, state) =>
              _pantallaServicio(state.pathParameters['id']!, esAliado: true),
        ),
        // Bandeja del aliado (US-04.1.4). La asignación sin doble aliado la
        // garantiza el servidor (UPDATE condicional atómico, DD-MANI §7.1).
        GoRoute(
          path: '/aliado/solicitudes',
          name: 'solicitudes-aliado',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<SolicitudesAliadoCubit>()..cargar(),
            child: SolicitudesAliadoPage(
              onAbrirCobertura: () => context.push('/aliado/cobertura'),
              onAbrirCategorias: () => context.push('/categories'),
              onAbrirDisponibilidad: () =>
                  context.push('/aliado/disponibilidad'),
              onCotizar: (id) =>
                  context.push('/aliado/solicitudes/$id/cotizacion'),
            ),
          ),
        ),
        // Ausencias del aliado (US-02.1.6). Rol y tenant los valida Core.
        // Bandeja de avisos (SCRUM-882 y 884): mensajes nuevos y cambios de estado.
        // Va bajo `/perfil/`, abierto a todos los roles; Core entrega solo los de la sesión.
        GoRoute(
          path: '/perfil/avisos',
          name: 'avisos',
          builder: (context, state) => AvisosPage(onAbrir: _abrirAviso),
        ),
        // Auditoría de transacciones (SCRUM-889): solo el administrador.
        GoRoute(
          path: '/admin/auditoria-transacciones',
          name: 'auditoria-transacciones',
          builder: (context, state) => const AuditoriaPage(),
        ),
        // Conversación de una queja (SCRUM-883): solo el administrador. Acepta
        // `?solicitudId=` y `?quejaRef=` para llegar desde una queja concreta.
        GoRoute(
          path: '/admin/conversaciones',
          name: 'conversacion-queja',
          builder: (context, state) => ConversacionQuejaPage(
            solicitudId: state.uri.queryParameters['solicitudId'],
            quejaRef: state.uri.queryParameters['quejaRef'],
          ),
        ),
        // Cobros del aliado (SCRUM-894): retención y liquidación simuladas.
        GoRoute(
          path: '/aliado/cobros',
          name: 'cobros-aliado',
          builder: (context, state) => const CobrosAliadoPage(),
        ),
        GoRoute(
          path: '/aliado/disponibilidad',
          name: 'disponibilidad-aliado',
          builder: (context, state) => const DisponibilidadPage(),
        ),
        // Bandeja de verificación de aliados (US-02.1.3). La autorización real
        // la aplica el servidor: las RPC exigen rol ADMIN_TENANT.
        GoRoute(
          path: '/admin/verificacion-aliados',
          name: 'verificacion-aliados',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<BandejaVerificacionCubit>()..cargar(),
            child: BandejaVerificacionPage(
              onAbrirCategorias: () => context.push('/admin/categorias'),
            ),
          ),
        ),
        // Quejas del cliente (HU-M12-01 / SCRUM-895): solo las suyas.
        GoRoute(
          path: '/cliente/quejas',
          name: 'mis-quejas',
          builder: (context, state) => BlocProvider(
            create: (_) => QuejasCubit(sl(), esAdmin: false)..cargar(),
            child: const QuejasPage(),
          ),
        ),
        // Gestión de quejas del tenant (HU-M12-02 / SCRUM-896).
        GoRoute(
          path: '/admin/quejas',
          name: 'quejas-tenant',
          builder: (context, state) => BlocProvider(
            create: (_) => QuejasCubit(sl(), esAdmin: true)..cargar(),
            child: const QuejasPage(),
          ),
        ),
        // Métricas operativas del tenant (HU-M12-06 / SCRUM-900).
        GoRoute(
          path: '/admin/metricas',
          name: 'metricas',
          builder: (context, state) => BlocProvider(
            create: (_) => MetricasCubit(sl())..consultar(),
            child: const MetricasPage(),
          ),
        ),
        // Administración de tenants (HU-M12-07 / SCRUM-901). Core exige el
        // permiso PLATFORM_ADMIN del token.
        GoRoute(
          path: '/plataforma/tenants',
          name: 'tenants-plataforma',
          builder: (context, state) => BlocProvider(
            create: (_) => TenantsCubit(sl())..cargar(),
            child: const TenantsPage(),
          ),
        ),
        // Tarifario de referencia (HU-M10-01 / SCRUM-885). Core exige
        // ADMIN_TENANT; el tenant y el actor salen del token.
        GoRoute(
          path: '/admin/tarifas',
          name: 'tarifario',
          builder: (context, state) => BlocProvider(
            create: (_) => TarifarioCubit(sl(), sl())..cargar(),
            child: const TarifarioPage(),
          ),
        ),
        // Cotizaciones fuera de rango evaluadas por Rules (HU-M10-03 / SCRUM-887).
        GoRoute(
          path: '/admin/reportes/cotizaciones-fuera-de-rango',
          name: 'reporte-fuera-de-rango',
          builder: (context, state) => BlocProvider(
            create: (_) => ReporteFueraDeRangoCubit(sl())..consultar(),
            child: const ReporteFueraDeRangoPage(),
          ),
        ),
        // Reglas operativas propias por tenant (HU-M01-03 / SCRUM-1366).
        GoRoute(
          path: '/admin/reglas',
          name: 'reglas-tenant',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<TenantRulesCubit>()..cargar(),
            child: const ReglasOperativasPage(),
          ),
        ),
        // Historial de servicios del cliente (HU-M08-06 / SCRUM-879). Desde cada
        // servicio finalizado se abre su pantalla para calificar.
        GoRoute(
          path: '/cliente/historial',
          name: 'historial-cliente',
          builder: (context, state) => BlocProvider(
            create: (_) =>
                HistorialServiciosCubit(sl(), esAliado: false)..cargar(),
            child: HistorialServiciosPage(
              onAbrirServicio: (id) =>
                  context.push('/cliente/solicitudes/$id/cotizacion'),
            ),
          ),
        ),
        // Historial de trabajos del aliado (HU-M08-07 / SCRUM-880).
        GoRoute(
          path: '/aliado/historial',
          name: 'historial-aliado',
          builder: (context, state) => BlocProvider(
            create: (_) =>
                HistorialServiciosCubit(sl(), esAliado: true)..cargar(),
            child: HistorialServiciosPage(
              onAbrirServicio: (id) =>
                  context.push('/aliado/solicitudes/$id/cotizacion'),
            ),
          ),
        ),
        // Política de cancelación tardía del tenant (HU-M08-05 / SCRUM-878).
        // Core exige ADMIN_TENANT para guardarla.
        GoRoute(
          path: '/admin/politica-cancelacion',
          name: 'politica-cancelacion',
          builder: (context, state) => BlocProvider(
            create: (_) => PoliticaCancelacionCubit(sl())..cargar(),
            child: const PoliticaCancelacionPage(),
          ),
        ),
        // Catálogo de categorías de servicio (US-03.1.1). Las RPC exigen rol
        // ADMIN_TENANT; el tenant sale de la sesión, nunca de la app.
        GoRoute(
          path: '/catalogo/mapa',
          name: 'catalogo-mapa',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<MapaCubit>()..cargar(),
            child: const MapaZonasPage(),
          ),
        ),
        GoRoute(
          path: '/admin/categorias',
          name: 'categorias',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<CategoriasCubit>()..cargar(),
            child: const GestionCategoriasPage(),
          ),
        ),
      ],
    ),
  ],
);
