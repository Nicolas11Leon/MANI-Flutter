import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mani/core/platform/guardador_archivo.dart';
import 'package:mani/features/payments/data/cobros_datasource.dart';
import 'package:mani/features/payments/domain/cobros.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/platform/selector_fotos.dart';
import 'package:mani/core/routing/app_router.dart';
import 'package:mani/core/session/guardas_ruta.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/session/sesion_expirada.dart';
import 'package:mani/core/shell/app_shell.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/shell/menu_por_rol.dart';
import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:mani/features/home/data/resumen_inicio.dart';
import 'package:mani/features/home/presentation/pages/inicio_page.dart';
import 'package:mani/features/profiles/coverage/presentation/controllers/cobertura_controller.dart';
import 'package:mani/features/profiles/own_profile/data/datasources/perfil_propio_remote_datasource.dart';
import 'package:mani/features/profiles/own_profile/domain/entities/perfil_propio.dart';

import '../../features/profiles/coverage/fakes.dart';

class _PkceEnMemoria extends GotrueAsyncStorage {
  final _datos = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _datos[key];
  @override
  Future<void> removeItem({required String key}) async => _datos.remove(key);
  @override
  Future<void> setItem({required String key, required String value}) async =>
      _datos[key] = value;
}

class _SelectorSinFotos implements SelectorFotos {
  @override
  Future<List<ArchivoLocal>> seleccionar() async => const [];
}

class _FuenteFija implements FuenteDatosSesion {
  @override
  Future<DatosSesion> cargar() async =>
      const DatosSesion(nombreUsuario: 'Ana Pérez', nombreTenant: 'Tenant A');
}

class _ResumenFijo implements FuenteResumenInicio {
  @override
  Future<List<IndicadorResumen>> cargar(RolUsuario rol) async => const [];
}

class _AuthFalso implements IAuthRepository {
  int cierres = 0;

  @override
  Future<void> signOut() async => cierres++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _perfil = PerfilPropio(
  id: 'u-1',
  tenantId: 't-a',
  role: 'ALLY',
  fullName: 'Ana Pérez',
  status: 'VERIFIED',
);

class _PerfilFalso implements PerfilPropioRemoteDataSource {
  @override
  Future<PerfilPropio> obtenerPerfilPropio() async => _perfil;

  @override
  Future<PerfilPropio> actualizarPerfilPropio({
    required String fullName,
    required String phone,
    required String address,
  }) async => _perfil;

  @override
  Future<PerfilPropio> subirFotoPerfil({
    required String nombreArchivo,
    required Uint8List bytes,
  }) async => _perfil;
}

/// Sesión local con un access token que no vence durante la prueba. No se
/// verifica firma: el router solo mira si hay sesión y el shell lee el rol.
String _sesionJson(String rol) {
  String parte(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  final segundos = exp.millisecondsSinceEpoch ~/ 1000;
  final token =
      '${parte({'alg': 'ES256', 'typ': 'JWT'})}.${parte({
        'sub': 'u-1',
        'exp': segundos,
        'app_metadata': {'tenant_id': 't-a', 'user_role': rol},
      })}.firma';
  return jsonEncode({
    'access_token': token,
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': segundos,
    'refresh_token': 'refresh-de-prueba',
    'user': {
      'id': 'u-1',
      'aud': 'authenticated',
      'email': 'ana@tenant-a.test',
      'created_at': '2026-10-01T00:00:00Z',
      'app_metadata': {'tenant_id': 't-a', 'user_role': rol},
      'user_metadata': <String, dynamic>{},
    },
  });
}

/// Rutas con sesión que deben quedar dentro del menú superior.
const _rutasConSesion = {
  '/inicio',
  '/categories',
  '/aliado/cobertura',
  '/sitios/:id/reglas',
  '/perfil/editar',
  '/cliente/sedes',
  '/admin/empleados/nuevo',
  '/perfil/avisos',
  '/admin/auditoria-transacciones',
  '/admin/conversaciones',
  '/cliente/solicitudes/nueva',
  '/cliente/solicitudes',
  '/cliente/solicitudes/:id/aliados',
  '/cliente/solicitudes/:id/cotizacion',
  '/cliente/pagos/:cotizacionId',
  '/cliente/solicitudes/:id/chat',
  '/aliado/solicitudes/:id/chat',
  '/aliado/solicitudes/:id/cotizacion',
  '/aliado/solicitudes',
  '/aliado/cobros',
  '/aliado/disponibilidad',
  '/admin/verificacion-aliados',
  '/admin/categorias',
  // M-10 (SCRUM-885 y 887).
  '/admin/tarifas',
  '/admin/reportes/cotizaciones-fuera-de-rango',
  // M-01 (SCRUM-1366).
  '/admin/reglas',
  // M-08 (SCRUM-878, 879 y 880).
  '/cliente/historial',
  '/aliado/historial',
  '/admin/politica-cancelacion',
  // M-12 (SCRUM-895, 896, 900 y 901).
  '/cliente/quejas',
  '/admin/quejas',
  '/admin/metricas',
  '/plataforma/tenants',
  // Mapa del catálogo geográfico (HU-M04-07).
  '/catalogo/mapa',
};

class _GuardadorFalso implements GuardadorArchivo {
  @override
  Future<bool> guardar({
    required String nombre,
    required Uint8List bytes,
    String tipoMime = 'application/octet-stream',
  }) async => true;
}

/// Fuente de cobros vacía: la ruta del pago la resuelve al armar la pantalla.
class _CobrosFalsos implements FuenteCobros {
  @override
  Future<List<CobroAliado>> cobrosDelAliado() async => const [];

  @override
  Future<RetencionPago> retencion(String pagoId) async =>
      throw UnimplementedError();
}

void main() {
  late _AuthFalso auth;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'clave-de-prueba',
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _PkceEnMemoria(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
    auth = _AuthFalso();
    sl.registerSingleton<FuenteDatosSesion>(_FuenteFija());
    sl.registerSingleton<IAuthRepository>(auth);
    sl.registerSingleton<PerfilPropioRemoteDataSource>(_PerfilFalso());
    sl.registerSingleton<SelectorFotos>(_SelectorSinFotos());
    sl.registerSingleton<FuenteResumenInicio>(_ResumenFijo());
    sl.registerSingleton<FuenteCobros>(_CobrosFalsos());
    sl.registerSingleton<GuardadorArchivo>(_GuardadorFalso());
    sl.registerFactory(() => CoberturaController(FakeCoberturaRepository()));
  });

  tearDownAll(sl.reset);

  ShellRoute shell() =>
      appRouter.configuration.routes.whereType<ShellRoute>().single;

  group('US-11.2.1 (SCRUM-1444) — rutas dentro del shell', () {
    test('todas las pantallas con sesión cuelgan del menú superior', () {
      final dentro = shell().routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(dentro, _rutasConSesion);
    });

    test('login y registro quedan fuera del menú', () {
      final fuera = appRouter.configuration.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(
        fuera,
        containsAll([
          '/login',
          '/register-cliente',
          '/register-aliado',
          '/register-empresa',
          '/register-cliente-empresa',
        ]),
      );
      expect(fuera.intersection(_rutasConSesion), isEmpty);
    });

    test('cada entrada del menú de cada rol apunta a una ruta del shell', () {
      for (final rol in RolUsuario.values) {
        for (final e in entradasMenuPara(rol)) {
          expect(_rutasConSesion, contains(e.ruta), reason: '$rol ${e.ruta}');
        }
      }
    });
  });

  testWidgets('cada ruta del shell arma su pantalla con sus dependencias', (
    tester,
  ) async {
    late BuildContext contexto;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          contexto = c;
          return const SizedBox();
        },
      ),
    );

    for (final ruta in shell().routes.whereType<GoRoute>()) {
      final ubicacion = ruta.path.replaceAll(':id', 'sitio-1');
      final estado = GoRouterState(
        appRouter.configuration,
        uri: Uri.parse(ubicacion),
        matchedLocation: ubicacion,
        fullPath: ruta.path,
        pathParameters: const {'id': 'sitio-1'},
        pageKey: ValueKey(ubicacion),
      );
      expect(ruta.builder!(contexto, estado), isA<Widget>(), reason: ruta.path);
    }
  });

  group('US-11.2.1 (SCRUM-1444) — menú montado sobre el router real', () {
    testWidgets(
      'con sesión de aliado la pantalla sale dentro del menú y se puede salir',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.runAsync(
          () => Supabase.instance.client.auth.recoverSession(
            _sesionJson('aliado'),
          ),
        );

        // Se entra directo a una ruta privada: /login necesita el AuthCubit
        // de la app completa y no es lo que se prueba aquí.
        appRouter.go('/perfil/editar');
        await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
        await tester.pumpAndSettle();

        expect(find.byType(AppShell), findsOneWidget);
        expect(find.text('Aliado · Tenant A'), findsOneWidget);
        expect(
          find.byKey(const Key('menu-entrada-/aliado/solicitudes')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('menu-entrada-/admin/categorias')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('menu-cerrar-sesion')));
        await tester.pumpAndSettle();
        expect(auth.cierres, 1);

        await tester.tap(find.byKey(const Key('menu-entrada-/perfil/editar')));
        await tester.pumpAndSettle();
        expect(
          appRouter.routeInformationProvider.value.uri.path,
          '/perfil/editar',
        );
      },
    );
  });

  group('US-11.2.2 (SCRUM-1445) — guardas sobre el router real', () {
    testWidgets('con sesión, una ruta de otro rol redirige al inicio propio', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Sin rol reconocible el inicio solo muestra el perfil; se pinta con
      // los fakes registrados arriba.
      await tester.runAsync(
        () => Supabase.instance.client.auth.recoverSession(
          _sesionJson('rol_inexistente'),
        ),
      );

      appRouter.go('/admin/categorias');
      await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
      await tester.pumpAndSettle();

      expect(appRouter.routeInformationProvider.value.uri.path, '/inicio');
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(InicioPage), findsOneWidget);
      expect(find.byKey(const Key('inicio-sin-rol')), findsOneWidget);
    });

    testWidgets(
      'el registro de cliente empresa (#57) queda fuera de la tabla de roles',
      (tester) async {
        late BuildContext contexto;
        await tester.pumpWidget(
          Builder(
            builder: (c) {
              contexto = c;
              return const SizedBox();
            },
          ),
        );
        const ubicacion = '/register-cliente-empresa';
        final estado = GoRouterState(
          appRouter.configuration,
          uri: Uri.parse(ubicacion),
          matchedLocation: ubicacion,
          fullPath: ubicacion,
          pathParameters: const {},
          pageKey: const ValueKey(ubicacion),
        );
        Future<String?> redirigir() async =>
            appRouter.configuration.topRedirect(contexto, estado);

        // Con sesión de cualquier rol no redirige; como la tabla de roles no
        // conoce la ruta, eso solo pasa si el router la trata como pública
        // (y sin sesión las públicas nunca se redirigen: guardas_ruta_test).
        for (final rol in ['cliente', 'aliado', 'admin_tenant']) {
          await tester.runAsync(
            () =>
                Supabase.instance.client.auth.recoverSession(_sesionJson(rol)),
          );
          expect(await redirigir(), isNull, reason: 'con sesión de $rol');
        }
        for (final rol in RolUsuario.values) {
          expect(rolPuedeAbrir(rol, ubicacion), isFalse, reason: '$rol');
        }
      },
    );

    test('un 401 sin refresco posible cierra la sesión local', () async {
      final auth = Supabase.instance.client.auth;
      await auth.recoverSession(_sesionJson('aliado'));
      expect(auth.currentSession, isNotNull);

      // El refresh token de prueba no existe en ningún servidor: el refresco
      // falla y la sesión tiene que quedar cerrada.
      final reintentar = await refrescarOCerrarSesion(auth);

      expect(reintentar, isFalse);
      expect(auth.currentSession, isNull);
    });
  });
}
