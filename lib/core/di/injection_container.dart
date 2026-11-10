import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mani/features/audit/data/auditoria_datasource.dart';
import 'package:mani/features/conversation_review/data/conversacion_queja_datasource.dart';
import 'package:mani/features/notifications/data/avisos_datasource.dart';
import 'package:mani/core/session/contexto_plataforma.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/session/sesion_expirada.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/features/catalog/map/data/mapa_remote_datasource.dart';
import 'package:mani/features/catalog/map/presentation/bloc/mapa_cubit.dart';
import 'package:mani/features/home/data/resumen_inicio.dart';
import 'package:mani/core/platform/url_opener.dart';
import 'package:mani/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:mani/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:mani/features/auth/domain/usecases/login_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_cliente_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_aliado_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_empresa_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_cliente_empresa_usecase.dart';
import 'package:mani/features/auth/data/datasources/recuperacion_contrasena_remote_data_source.dart';
import 'package:mani/features/auth/data/repositories/recuperacion_contrasena_repository_impl.dart';
import 'package:mani/features/auth/domain/repositories/i_recuperacion_contrasena_repository.dart';
import 'package:mani/features/auth/domain/usecases/recuperar_contrasena_usecases.dart';
import 'package:mani/features/auth/presentation/bloc/recuperacion_contrasena_cubit.dart';
import 'package:mani/features/messaging/data/mensajes_datasource.dart';
import 'package:mani/core/platform/guardador_archivo.dart';
import 'package:mani/features/payments/data/cobros_datasource.dart';
import 'package:mani/features/payments/data/pagos_datasource.dart';
import 'package:mani/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:mani/features/availability/data/datasources/disponibilidad_remote_datasource.dart';
import 'package:mani/features/availability/data/repositories/disponibilidad_repository_impl.dart';
import 'package:mani/features/availability/domain/repositories/i_disponibilidad_repository.dart';
import 'package:mani/features/availability/presentation/bloc/disponibilidad_cubit.dart';
import 'package:mani/features/profile_categories/data/datasources/categories_remote_datasource.dart';
import 'package:mani/features/profile_categories/data/repositories/categories_repository_impl.dart';
import 'package:mani/features/profile_categories/domain/repositories/i_categories_repository.dart';
import 'package:mani/features/profile_categories/domain/usecases/get_available_categories_usecase.dart';
import 'package:mani/features/profile_categories/domain/usecases/get_selected_categories_usecase.dart';
import 'package:mani/features/profile_categories/domain/usecases/save_selected_categories_usecase.dart';
import 'package:mani/features/profile_categories/presentation/bloc/categories_cubit.dart';
import 'package:mani/features/profiles/coverage/domain/repositories/cobertura_repository.dart';
import 'package:mani/features/profiles/coverage/data/repositories/cobertura_repository_impl.dart';
import 'package:mani/features/profiles/coverage/data/datasources/cobertura_remote_datasource.dart';
import 'package:mani/features/profiles/coverage/presentation/controllers/cobertura_controller.dart';
import 'package:mani/features/profiles/verification/data/datasources/verificacion_remote_datasource.dart';
import 'package:mani/features/profiles/verification/data/repositories/verificacion_aliados_repository_impl.dart';
import 'package:mani/features/profiles/verification/domain/repositories/verificacion_aliados_repository.dart';
import 'package:mani/features/profiles/verification/domain/usecases/verificacion_usecases.dart';
import 'package:mani/features/profiles/verification/presentation/bloc/bandeja_verificacion_cubit.dart';
import 'package:mani/features/services/categories/data/datasources/catalogo_publico_datasource.dart';
import 'package:mani/features/services/categories/data/datasources/categorias_remote_datasource.dart';
import 'package:mani/features/services/categories/data/repositories/categorias_repository_impl.dart';
import 'package:mani/features/services/categories/domain/repositories/categorias_repository.dart';
import 'package:mani/features/services/categories/domain/usecases/categoria_usecases.dart';
import 'package:mani/features/services/categories/presentation/bloc/categorias_cubit.dart';
import 'package:mani/features/asignacion/data/datasources/asignacion_remote_datasource.dart';
import 'package:mani/features/asignacion/data/repositories/asignacion_repository_impl.dart';
import 'package:mani/features/asignacion/domain/repositories/i_asignacion_repository.dart';
import 'package:mani/features/asignacion/domain/usecases/asignacion_usecases.dart';
import 'package:mani/features/asignacion/presentation/bloc/solicitudes_aliado_cubit.dart';
import 'package:mani/core/platform/selector_fotos.dart';
import 'package:mani/features/tenant_rules/data/tenant_rules_datasource.dart';
import 'package:mani/features/tenant_rules/presentation/tenant_rules_cubit.dart';
import 'package:mani/features/services/requests/data/datasources/solicitudes_cliente_remote_datasource.dart';
import 'package:mani/features/services/requests/data/repositories/solicitudes_cliente_repository_impl.dart';
import 'package:mani/features/services/requests/domain/repositories/solicitudes_cliente_repository.dart';
import 'package:mani/features/services/requests/domain/usecases/solicitud_usecases.dart';
import 'package:mani/features/services/requests/presentation/bloc/crear_solicitud_cubit.dart';
import 'package:mani/features/services/eligible_allies/data/elegibles_datasource.dart';
import 'package:mani/features/services/tracking/data/seguimiento_datasource.dart';
import 'package:mani/features/services/tracking/presentation/mis_solicitudes_cubit.dart';
import 'package:mani/features/profiles/site_rules/data/reglas_sitio_remote_datasource.dart';
import 'package:mani/features/profiles/site_rules/domain/usecases/reglas_sitio_usecases.dart';
import 'package:mani/features/profiles/site_rules/presentation/bloc/reglas_sitio_cubit.dart';
import 'package:mani/features/profiles/company_sites/data/sedes_empresa_remote_datasource.dart';
import 'package:mani/features/profiles/company_sites/domain/usecases/sedes_empresa_usecases.dart';
import 'package:mani/features/profiles/company_sites/presentation/bloc/sedes_empresa_cubit.dart';
import 'package:mani/features/profiles/direct_employees/data/empleados_directos_remote_datasource.dart';
import 'package:mani/features/profiles/own_profile/data/datasources/perfil_propio_remote_datasource.dart';
import 'package:mani/features/profiles/direct_employees/domain/usecases/registrar_empleado_directo_usecase.dart';
import 'package:mani/features/profiles/direct_employees/presentation/bloc/empleado_directo_cubit.dart';
import 'package:mani/features/services/quotes/data/cotizaciones_datasource.dart';
import 'package:mani/features/services/additions/data/adiciones_datasource.dart';
import 'package:mani/features/services/execution/data/ejecucion_datasource.dart';
import 'package:mani/features/services/events/data/almacen_cola_eventos.dart';
import 'package:mani/features/services/events/data/cola_eventos.dart';
import 'package:mani/features/services/events/data/eventos_datasource.dart';
import 'package:mani/features/services/ratings/data/calificacion_cierre_datasource.dart';
import 'package:mani/core/session/tenant_sesion.dart';
import 'package:mani/features/services/ratings/data/politica_cancelacion_datasource.dart';
import 'package:mani/features/tariffs/data/tarifas_datasource.dart';
import 'package:mani/features/complaints/data/quejas_datasource.dart';
import 'package:mani/features/metrics/data/metricas_datasource.dart';
import 'package:mani/features/platform/data/tenants_datasource.dart';

final sl = GetIt.instance; // sl = service locator

Future<void> init() async {
  // External
  sl.registerLazySingleton(() => Supabase.instance.client);

  // Core
  // Cliente del API Gateway (ADR-0019). El JWT lo sigue emitiendo
  // Supabase Auth; aquí solo se lee de la sesión local.
  sl.registerLazySingleton(
    () => GatewayClient(
      baseUrl: dotenv.maybeGet('API_GATEWAY_URL') ?? 'http://localhost:80',
      tokenProvider: () async =>
          sl<SupabaseClient>().auth.currentSession?.accessToken,
      // Ante un 401 se intenta refrescar una vez. Si no se puede, la sesión
      // local se cierra y el `redirect` del router lleva al login
      // (US-11.2.2 / SCRUM-1445): no se deja al usuario en una pantalla que
      // ya no puede cargar nada.
      onTokenExpired: () => refrescarOCerrarSesion(sl<SupabaseClient>().auth),
      // Tenant elegido y usuario con el que actúa el admin de plataforma
      // (SCRUM-901). Vacío para los demás roles.
      cabecerasExtra: () => sl<ContextoPlataforma>().cabeceras,
    ),
  );
  sl.registerLazySingleton<ContextoPlataforma>(ContextoPlataforma.new);
  sl.registerLazySingleton<FuenteUsuariosTenant>(
    () => GatewayFuenteUsuariosTenant(sl()),
  );
  sl.registerLazySingleton<UrlOpener>(() => const UrlLauncherOpener());
  sl.registerLazySingleton<SelectorFotos>(
    () => const FilePickerSelectorFotos(),
  );

  // Features - Auth
  // Bloc
  sl.registerFactory(
    () => AuthCubit(
      loginUseCase: sl(),
      registerClienteUseCase: sl(),
      registerAliadoUseCase: sl(),
      registerEmpresaUseCase: sl(),
      registerClienteEmpresaUseCase: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterClienteUseCase(sl()));
  sl.registerLazySingleton(() => RegisterAliadoUseCase(sl()));
  sl.registerLazySingleton(() => RegisterEmpresaUseCase(sl()));
  sl.registerLazySingleton(() => RegisterClienteEmpresaUseCase(sl()));

  // Recuperación de contraseña (HU-M02-10)
  sl.registerFactory(
    () => RecuperacionContrasenaCubit(
      solicitarUseCase: sl(),
      restablecerUseCase: sl(),
    ),
  );
  sl.registerLazySingleton(() => SolicitarRecuperacionUseCase(sl()));
  sl.registerLazySingleton(() => RestablecerContrasenaUseCase(sl()));
  sl.registerLazySingleton<IRecuperacionContrasenaRepository>(
    () => RecuperacionContrasenaRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<IRecuperacionContrasenaRemoteDataSource>(
    () => RecuperacionContrasenaRemoteDataSource(client: sl(), gateway: sl()),
  );

  // Repository
  sl.registerLazySingleton<IAuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<IAuthRemoteDataSource>(
    () => AuthRemoteDataSource(client: sl(), gateway: sl()),
  );

  // Features - Profile Categories
  // Bloc
  sl.registerFactory(
    () => CategoriesCubit(
      getAvailableCategoriesUseCase: sl(),
      getSelectedCategoriesUseCase: sl(),
      saveSelectedCategoriesUseCase: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetAvailableCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => GetSelectedCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => SaveSelectedCategoriesUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ICategoriesRepository>(
    () => CategoriesRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<CategoriesRemoteDataSource>(
    () => GatewayCategoriesDataSource(sl()),
  );

  // Features - Availability (US-02.1.6). Va por el Gateway: Core Node expone
  // /profiles/me/unavailability y resuelve tenant y aliado desde el JWT.
  sl.registerFactory(() => DisponibilidadCubit(repository: sl()));
  sl.registerLazySingleton<IDisponibilidadRepository>(
    () => DisponibilidadRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<DisponibilidadRemoteDataSource>(
    () => GatewayDisponibilidadDataSource(sl()),
  );

  // Features - Profiles / Coverage (US-02.1.4)
  sl.registerFactory(() => CoberturaController(sl()));
  sl.registerLazySingleton<CoberturaRepository>(
    () => CoberturaRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<CoberturaRemoteDataSource>(
    () => GatewayCoberturaDataSource(sl(), sesion: sl()),
  );

  // Features - Catalogo / Mapa cartografico (HU-M04-07, SCRUM-1396)
  sl.registerFactory(() => MapaCubit(sl()));
  sl.registerLazySingleton<MapaRemoteDataSource>(
    () => GatewayMapaDataSource(sl()),
  );

  // Features - Profiles / Verification (US-02.1.3)
  sl.registerFactory(
    () => BandejaVerificacionCubit(
      listar: sl(),
      obtenerDetalle: sl(),
      aprobar: sl(),
      rechazar: sl(),
      urlDocumento: sl(),
      urlOpener: sl(),
    ),
  );
  sl.registerLazySingleton(() => ListarSolicitudesAliados(sl()));
  sl.registerLazySingleton(() => ObtenerDetalleAliado(sl()));
  sl.registerLazySingleton(() => AprobarAliado(sl()));
  sl.registerLazySingleton(() => RechazarAliado(sl()));
  sl.registerLazySingleton(() => ObtenerUrlDocumento(sl()));
  sl.registerLazySingleton<VerificacionAliadosRepository>(
    () => VerificacionAliadosRepositoryImpl(sl()),
  );
  // SCRUM-1384: la bandeja habla con Core por el Gateway (ADR-0027).
  sl.registerLazySingleton<VerificacionRemoteDataSource>(
    () => GatewayVerificacionDataSource(sl(), sesion: sl()),
  );

  // Features - Services / Categories (US-03.1.1 / US-03.1.2)
  sl.registerFactory(
    () => CategoriasCubit(listar: sl(), crear: sl(), cambiarEstado: sl()),
  );
  sl.registerLazySingleton(() => ListarCategorias(sl()));
  sl.registerLazySingleton(() => CrearCategoria(sl()));
  sl.registerLazySingleton(() => CambiarEstadoCategoria(sl()));
  sl.registerLazySingleton<CategoriasRepository>(
    () => CategoriasRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<CategoriasRemoteDataSource>(
    () => GatewayCategoriasDataSource(sl(), sesion: sl()),
  );
  // Catálogo público del tenant para los registros sin sesión (aliado y empresa).
  sl.registerLazySingleton(() => CatalogoPublicoDataSource(sl()));

  // Features - Asignación / Aceptar-rechazar solicitud (US-04.1.4)
  sl.registerFactory(
    () => SolicitudesAliadoCubit(listar: sl(), aceptar: sl(), rechazar: sl()),
  );
  sl.registerLazySingleton(() => ListarSolicitudesAliado(sl()));
  sl.registerLazySingleton(() => AceptarSolicitud(sl()));
  sl.registerLazySingleton(() => RechazarSolicitud(sl()));
  sl.registerLazySingleton<IAsignacionRepository>(
    () => AsignacionRepositoryImpl(sl()),
  );
  // Bandeja, aceptar y rechazar por el Gateway hacia Dispatch (decisión 6A,
  // SCRUM-1402/1403/1404); reemplaza las RPC de la migración 005.
  sl.registerLazySingleton<AsignacionRemoteDataSource>(
    () => GatewayAsignacionDataSource(
      sl(),
      tenantIdSesion: () => tenantIdDeSesion(sl<SupabaseClient>().auth),
    ),
  );

  // Aliados elegibles de la solicitud por el Gateway a Dispatch (SCRUM-1398,
  // 1400 y 1401). El Cubit se crea por solicitud en la ruta.
  sl.registerLazySingleton<FuenteElegibles>(() => GatewayFuenteElegibles(sl()));

  // Seguimiento del cliente (HU-M07-04 / SCRUM-871).
  sl.registerFactory(() => MisSolicitudesCubit(sl()));
  sl.registerLazySingleton<FuenteSeguimiento>(
    () => GatewayFuenteSeguimiento(sl()),
  );

  // Cotización (US-04.2.1 / SCRUM-865 y US-04.2.3 / SCRUM-867), por el Gateway
  // a Core. El Cubit se crea por solicitud en la ruta.
  sl.registerLazySingleton<FuenteCotizaciones>(
    () => GatewayFuenteCotizaciones(sl()),
  );
  // Pago en el sandbox (HU-M11-01 / SCRUM-1432), por el Gateway a Core. El Cubit
  // se crea por cotización en la ruta.
  sl.registerLazySingleton<FuentePagos>(() => GatewayFuentePagos(sl()));
  // Módulo M-08: calificación bidireccional, cierre, historial y penalización
  // por cancelación tardía (SCRUM-874, 875, 878, 879, 880 y 1418), por el
  // Gateway a Core.
  sl.registerLazySingleton<FuenteModuloM08>(() => GatewayFuenteModuloM08(sl()));
  sl.registerLazySingleton<FuentePoliticaCancelacion>(
    () => GatewayFuentePoliticaCancelacion(sl()),
  );
  // Tarifario de referencia (M-10: SCRUM-885, 886 y 887), por el Gateway a Core.
  sl.registerLazySingleton<FuenteTarifas>(() => GatewayFuenteTarifas(sl()));
  // Quejas, métricas y tenants (M-12: SCRUM-895, 896, 900 y 901), por el
  // Gateway a Core. Los Cubits se crean en cada ruta.
  sl.registerLazySingleton<FuenteQuejas>(() => GatewayFuenteQuejas(sl()));
  sl.registerLazySingleton<FuenteMetricas>(() => GatewayFuenteMetricas(sl()));
  sl.registerLazySingleton<FuenteTenants>(() => GatewayFuenteTenants(sl()));
  sl.registerLazySingleton<FuenteCobros>(() => GatewayFuenteCobros(sl()));
  sl.registerLazySingleton<GuardadorArchivo>(
    () => const FilePickerGuardadorArchivo(),
  );
  // Mensajería cliente-aliado (HU-M09-02 / SCRUM-881), por el Gateway a Core. El
  // Cubit se crea por solicitud en la ruta y consulta cada pocos segundos.
  sl.registerLazySingleton<FuenteMensajes>(() => GatewayFuenteMensajes(sl()));
  // SCRUM-882/884 (bandeja de avisos), SCRUM-889 (auditoría) y SCRUM-883
  // (conversación de una queja): lecturas por el Gateway; el rol lo decide Core.
  sl.registerLazySingleton<FuenteAvisos>(() => GatewayFuenteAvisos(sl()));
  sl.registerLazySingleton<FuenteAuditoria>(() => GatewayFuenteAuditoria(sl()));
  sl.registerLazySingleton<FuenteConversacionQueja>(
    () => GatewayFuenteConversacionQueja(sl()),
  );
  // Ejecución del servicio (US-04.3.1 / SCRUM-868), en la misma pantalla.
  sl.registerLazySingleton<FuenteEjecucion>(() => GatewayFuenteEjecucion(sl()));
  // Adiciones por imprevisto (US-04.3.5 / SCRUM-872), en la misma pantalla.
  sl.registerLazySingleton<FuenteAdiciones>(() => GatewayFuenteAdiciones(sl()));
  // Bitácora del servicio (US-04.3.2 / SCRUM-869), en la misma pantalla.
  sl.registerLazySingleton<FuenteEventos>(() => GatewayFuenteEventos(sl()));
  // Cola de eventos sin conexión (US-04.3.6 / SCRUM-873), solo en el móvil.
  // Es del usuario de la sesión: se borra al cerrarla, también cuando la
  // cierra el vencimiento del token (decisión del PO).
  sl.registerLazySingleton<ColaEventos>(() {
    final auth = sl<SupabaseClient>().auth;
    final cola = ColaEventos(
      crearAlmacenColaEventos(),
      usuarioActual: () => auth.currentUser?.id,
    );
    auth.onAuthStateChange.listen((cambio) {
      if (cambio.event == AuthChangeEvent.signedOut) cola.vaciar();
    });
    return cola;
  });

  // Features - Services / Requests: crear solicitud (US-04.1.1)
  sl.registerFactory(
    () => CrearSolicitudCubit(
      cargarCatalogo: sl(),
      buscarZonas: sl(),
      publicar: sl(),
      avisarAliados: sl(),
    ),
  );
  sl.registerLazySingleton(() => CargarCatalogoSolicitud(sl()));
  sl.registerLazySingleton(() => AvisarAliados(sl()));
  sl.registerLazySingleton(() => BuscarZonas(sl()));
  sl.registerLazySingleton(() => PublicarSolicitud(sl()));
  sl.registerLazySingleton<SolicitudesClienteRepository>(
    () => SolicitudesClienteRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<SolicitudesClienteRemoteDataSource>(
    () => SolicitudesClienteRemoteDataSourceImpl(sl(), sl()),
  );

  // Features - Profiles / Reglas de Sitio (US-02.2.3 / SCRUM-853)
  sl.registerFactory(
    () => ReglasSitioCubit(obtenerUseCase: sl(), configurarUseCase: sl()),
  );
  sl.registerLazySingleton(() => ObtenerReglasSitioUseCase(sl()));
  sl.registerLazySingleton(() => ConfigurarReglasSitioUseCase(sl()));
  sl.registerLazySingleton<IReglasSitioRepository>(
    () => ReglasSitioRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<IReglasSitioRemoteDataSource>(
    () => ReglasSitioRemoteDataSource(gateway: sl()),
  );

  // Features - Profiles / Perfil propio (US-02.3.1 / SCRUM-854): habla con Core por el Gateway.
  sl.registerLazySingleton<PerfilPropioRemoteDataSource>(
    () => GatewayPerfilPropioDataSource(sl()),
  );

  // Shell de aplicación (US-11.2.1 / SCRUM-1444): cabecera del menú superior.
  sl.registerLazySingleton<FuenteDatosSesion>(
    () => GatewayFuenteDatosSesion(sl()),
  );

  // Inicio por tipo de usuario (US-11.2.3 / SCRUM-1446).
  sl.registerLazySingleton<FuenteResumenInicio>(
    () => GatewayResumenInicio(sl()),
  );

  // Features - Profiles / Sedes Empresa (US-02.2.2 / SCRUM-852)
  sl.registerFactory(
    () => SedesEmpresaCubit(
      listarUseCase: sl(),
      agregarUseCase: sl(),
      editarUseCase: sl(),
      listarZonasUseCase: sl(),
    ),
  );
  sl.registerLazySingleton(() => ListarSedesEmpresaUseCase(sl()));
  sl.registerLazySingleton(() => AgregarSedeEmpresaUseCase(sl()));
  sl.registerLazySingleton(() => EditarSedeEmpresaUseCase(sl()));
  sl.registerLazySingleton(() => ListarZonasSedeUseCase(sl()));
  sl.registerLazySingleton<ISedesEmpresaRepository>(
    () => SedesEmpresaRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ISedesEmpresaRemoteDataSource>(
    () => SedesEmpresaRemoteDataSource(gateway: sl()),
  );

  // Features - Profiles / Empleados Directos (US-02.1.5 / SCRUM-850)
  sl.registerFactory(() => EmpleadoDirectoCubit(registrarUseCase: sl()));
  sl.registerLazySingleton(() => RegistrarEmpleadoDirectoUseCase(sl()));
  sl.registerLazySingleton<IEmpleadosDirectosRepository>(
    () => EmpleadosDirectosRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<IEmpleadosDirectosRemoteDataSource>(
    () => EmpleadosDirectosRemoteDataSource(gateway: sl()),
  );

  // Features - Tenant Rules (SCRUM-1366 / HU-M01-03)
  sl.registerLazySingleton<FuenteReglasTenant>(
    () => GatewayFuenteReglasTenant(sl()),
  );
  sl.registerFactory(() => TenantRulesCubit(sl()));
}
