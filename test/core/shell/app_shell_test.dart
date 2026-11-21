import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/session/guardas_ruta.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/app_shell.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/shell/menu_por_rol.dart';

/// Arma un JWT sin firma válida: el shell solo lee el payload para pintar.
String _token(Map<String, dynamic> payload) {
  String parte(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${parte({'alg': 'ES256', 'typ': 'JWT'})}.${parte(payload)}.firma';
}

class _FuenteFija implements FuenteDatosSesion {
  _FuenteFija(this._datos);
  final DatosSesion _datos;
  @override
  Future<DatosSesion> cargar() async => _datos;
}

class _FuenteQueFalla implements FuenteDatosSesion {
  @override
  Future<DatosSesion> cargar() => Future.error(Exception('Core no responde'));
}

Future<void> _montar(
  WidgetTester tester, {
  required double ancho,
  required RolUsuario rol,
  FuenteDatosSesion? fuente,
  String ubicacion = '/',
  ValueChanged<String>? onNavegar,
  Future<void> Function()? onCerrarSesion,
}) async {
  tester.view.physicalSize = Size(ancho, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AppShell(
        rol: rol,
        ubicacion: ubicacion,
        fuenteDatos:
            fuente ??
            _FuenteFija(
              const DatosSesion(
                nombreUsuario: 'Ana Pérez',
                nombreTenant: 'Plomería Express',
              ),
            ),
        onNavegar: onNavegar ?? (_) {},
        onCerrarSesion: onCerrarSesion ?? () async {},
        child: const Text('contenido de la pantalla'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('US-11.2.1 (SCRUM-1444) — rol de la sesión', () {
    test('traduce el claim del hook y los nombres de dominio de Core', () {
      expect(rolDesdeClaim('cliente'), RolUsuario.cliente);
      expect(rolDesdeClaim('CLIENT'), RolUsuario.cliente);
      expect(rolDesdeClaim('aliado'), RolUsuario.aliado);
      expect(rolDesdeClaim('ALLY'), RolUsuario.aliado);
      expect(rolDesdeClaim('admin_tenant'), RolUsuario.adminTenant);
      expect(rolDesdeClaim('ADMIN'), RolUsuario.adminTenant);
    });

    test('un rol vacío o desconocido no abre entradas de negocio', () {
      expect(rolDesdeClaim(null), RolUsuario.desconocido);
      expect(rolDesdeClaim('superusuario'), RolUsuario.desconocido);
      expect(entradasMenuPara(RolUsuario.desconocido).map((e) => e.ruta), [
        '/inicio',
        '/perfil/editar',
      ]);
    });

    test('lee app_metadata.user_role del access token', () {
      final token = _token({
        'sub': 'u-1',
        'app_metadata': {'tenant_id': 't-1', 'user_role': 'aliado'},
      });
      expect(rolDesdeAccessToken(token), RolUsuario.aliado);
    });

    test('acepta el claim alterno rol', () {
      final token = _token({
        'app_metadata': {'rol': 'admin_tenant'},
      });
      expect(rolDesdeAccessToken(token), RolUsuario.adminTenant);
    });

    test('token ausente, mal formado o sin app_metadata da desconocido', () {
      expect(rolDesdeAccessToken(null), RolUsuario.desconocido);
      expect(rolDesdeAccessToken('no-es-un-jwt'), RolUsuario.desconocido);
      expect(rolDesdeAccessToken('a.%%%.c'), RolUsuario.desconocido);
      expect(
        rolDesdeAccessToken(_token({'sub': 'u-1'})),
        RolUsuario.desconocido,
      );
    });
  });

  group('US-11.2.1 (SCRUM-1444) — entradas por rol', () {
    Set<String> rutas(RolUsuario rol) =>
        entradasMenuPara(rol).map((e) => e.ruta).toSet();

    test('cliente ve sus pantallas y ninguna de aliado ni de admin', () {
      final r = rutas(RolUsuario.cliente);
      expect(r, containsAll(['/cliente/solicitudes/nueva', '/cliente/sedes']));
      expect(r.any((x) => x.startsWith('/aliado')), isFalse);
      expect(r.any((x) => x.startsWith('/admin')), isFalse);
    });

    test(
      'aliado ve bandeja, cobertura, categorías, cobros y disponibilidad',
      () {
        final r = rutas(RolUsuario.aliado);
        expect(
          r,
          containsAll([
            '/aliado/solicitudes',
            '/aliado/cobertura',
            '/categories',
            '/aliado/cobros',
            '/aliado/disponibilidad',
          ]),
        );
        expect(r.any((x) => x.startsWith('/admin')), isFalse);
        expect(r.any((x) => x.startsWith('/cliente')), isFalse);
      },
    );

    test('admin del tenant ve solo la administración de su empresa', () {
      final r = rutas(RolUsuario.adminTenant);
      expect(
        r,
        containsAll(['/admin/verificacion-aliados', '/admin/categorias']),
      );
      expect(
        r.where(
          (x) =>
              x.startsWith('/aliado/') ||
              x.startsWith('/cliente/') ||
              x.startsWith('/plataforma/') ||
              x == '/categories',
        ),
        isEmpty,
      );
    });

    test('admin de plataforma ve tenants y la administración por omisión', () {
      final r = rutas(RolUsuario.adminPlataforma);
      expect(
        r,
        containsAll({'/plataforma/tenants', ...rutas(RolUsuario.adminTenant)}),
      );
      // Las de cliente y aliado aparecen al actuar como uno
      // (contexto_plataforma_test.dart).
      expect(r.where((x) => x.startsWith('/cliente/')), isEmpty);
    });

    test(
      'SCRUM-1376: el registro de empleados está en el menú del admin, que es quien lo hace en Core, y no en el del aliado',
      () {
        expect(
          rutas(RolUsuario.adminTenant),
          contains('/admin/empleados/nuevo'),
        );
        expect(
          rutas(RolUsuario.aliado),
          isNot(contains('/aliado/empleados/nuevo')),
        );
        expect(
          rutas(RolUsuario.aliado).any((x) => x.contains('empleados')),
          isFalse,
        );
      },
    );

    test(
      'SCRUM-889 y 883: el admin ve la auditoría y las conversaciones; nadie más',
      () {
        expect(
          rutas(RolUsuario.adminTenant),
          containsAll([
            '/admin/auditoria-transacciones',
            '/admin/conversaciones',
          ]),
        );
        for (final rol in [RolUsuario.cliente, RolUsuario.aliado]) {
          expect(
            rutas(rol).any((x) => x.startsWith('/admin')),
            isFalse,
            reason: rol.name,
          );
          expect(rolPuedeAbrir(rol, '/admin/auditoria-transacciones'), isFalse);
          expect(rolPuedeAbrir(rol, '/admin/conversaciones'), isFalse);
        }
        expect(
          rolPuedeAbrir(
            RolUsuario.adminTenant,
            '/admin/auditoria-transacciones',
          ),
          isTrue,
        );
      },
    );

    test(
      'SCRUM-882 y 884: todos los roles ven los avisos y pueden abrirlos',
      () {
        for (final rol in [
          RolUsuario.cliente,
          RolUsuario.aliado,
          RolUsuario.adminTenant,
        ]) {
          expect(rutas(rol), contains('/perfil/avisos'), reason: rol.name);
          expect(
            rolPuedeAbrir(rol, '/perfil/avisos'),
            isTrue,
            reason: rol.name,
          );
        }
      },
    );

    test('todos los roles tienen inicio primero y acceso a su perfil', () {
      for (final rol in RolUsuario.values) {
        expect(entradasMenuPara(rol).first.ruta, '/inicio', reason: '$rol');
        expect(rutas(rol), contains('/perfil/editar'), reason: '$rol');
      }
    });
  });

  group('US-11.2.1 (SCRUM-1444) — datos de la cabecera por el Gateway', () {
    const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

    GatewayClient gateway(Future<http.Response> Function(http.Request) h) =>
        GatewayClient(
          baseUrl: 'http://gateway.test',
          tokenProvider: () async => 'token',
          httpClient: MockClient(h),
          maxRetries: 0,
        );

    Future<DatosSesion> cargarCon(Map<String, dynamic> perfil) {
      final rutas = <String>[];
      return GatewayFuenteDatosSesion(
        gateway((req) async {
          rutas.add(req.url.path);
          expect(
            req.url.path,
            '/api/v1/core/profiles/me',
            reason: 'la cabecera no debe consultar otra ruta (ni /tenants)',
          );
          return http.Response(
            jsonEncode({'profile': perfil}),
            200,
            headers: jsonHeaders,
          );
        }),
      ).cargar().whenComplete(() => expect(rutas, hasLength(1)));
    }

    test('toma nombre y tenant del perfil sin pedir /tenants', () async {
      final datos = await cargarCon({
        'fullName': 'Ana Pérez',
        'tenantId': 't-2',
        'tenantName': 'Plomería Express',
      });

      expect(datos.nombreUsuario, 'Ana Pérez');
      expect(datos.nombreTenant, 'Plomería Express');
    });

    test('acepta tenant_name y el objeto tenant del perfil', () async {
      final snake = await cargarCon({
        'nombre': 'Ana',
        'tenant_name': ' Acme Servicios ',
      });
      final objeto = await cargarCon({
        'fullName': 'Ana',
        'tenant': {'nombre': 'Nova Mantenimiento'},
      });

      expect(snake.nombreUsuario, 'Ana');
      expect(snake.nombreTenant, 'Acme Servicios');
      expect(objeto.nombreTenant, 'Nova Mantenimiento');
    });

    test('si el perfil solo trae el id del tenant, no se inventa', () async {
      final datos = await cargarCon({'fullName': '', 'tenantId': 't-9'});

      expect(datos.nombreUsuario, 'Usuario');
      expect(datos.nombreTenant, isNull);
    });

    test('un nombre de tenant vacío también queda sin tenant', () async {
      final datos = await cargarCon({
        'fullName': 'Ana',
        'tenant': {'name': '  '},
      });

      expect(datos.nombreTenant, isNull);
    });
  });

  group('US-11.2.1 (SCRUM-1444) — menú superior', () {
    testWidgets('en escritorio muestra usuario, rol, tenant y entradas', (
      tester,
    ) async {
      await _montar(tester, ancho: 1024, rol: RolUsuario.aliado);

      expect(find.byKey(const Key('menu-superior')), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Aliado · Plomería Express'), findsOneWidget);
      expect(find.text('Solicitudes'), findsOneWidget);
      expect(find.text('Cobertura'), findsOneWidget);
      expect(find.text('Verificación de aliados'), findsNothing);
      expect(find.byKey(const Key('menu-compacto')), findsNothing);
      expect(find.text('contenido de la pantalla'), findsOneWidget);
    });

    testWidgets(
      'en escritorio la barra es desplazable con botones de navegación',
      (tester) async {
        await _montar(tester, ancho: 1024, rol: RolUsuario.adminTenant);
        expect(find.byKey(const Key('menu-scroll-izq')), findsOneWidget);
        expect(find.byKey(const Key('menu-scroll-der')), findsOneWidget);

        await tester.tap(find.byKey(const Key('menu-scroll-der')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('menu-scroll-izq')));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('tocar una entrada navega a su ruta', (tester) async {
      String? destino;
      await _montar(
        tester,
        ancho: 1024,
        rol: RolUsuario.adminTenant,
        onNavegar: (r) => destino = r,
      );

      await tester.tap(find.byKey(const Key('menu-entrada-/admin/categorias')));

      expect(destino, '/admin/categorias');
    });

    testWidgets('cerrar sesión está disponible y llama al cierre', (
      tester,
    ) async {
      var cerro = false;
      await _montar(
        tester,
        ancho: 1024,
        rol: RolUsuario.cliente,
        onCerrarSesion: () async => cerro = true,
      );

      await tester.tap(find.byKey(const Key('menu-cerrar-sesion')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirmacion-confirmar')));
      await tester.pumpAndSettle();

      expect(cerro, isTrue);
    });

    testWidgets('en móvil las entradas van en un menú desplegable', (
      tester,
    ) async {
      String? destino;
      await _montar(
        tester,
        ancho: 390,
        rol: RolUsuario.cliente,
        onNavegar: (r) => destino = r,
      );

      expect(find.byKey(const Key('menu-compacto')), findsOneWidget);
      expect(find.text('Mis sedes'), findsNothing);
      expect(find.byKey(const Key('menu-cerrar-sesion')), findsOneWidget);

      await tester.tap(find.byKey(const Key('menu-compacto')));
      await tester.pumpAndSettle();
      expect(find.text('Mis sedes'), findsOneWidget);

      await tester.tap(find.text('Mis sedes'));
      await tester.pumpAndSettle();
      expect(destino, '/cliente/sedes');
    });

    testWidgets(
      'en móvil el menú desplegable incluye cerrar sesión y ejecuta onCerrarSesion',
      (tester) async {
        var cerro = false;
        await _montar(
          tester,
          ancho: 390,
          rol: RolUsuario.cliente,
          onCerrarSesion: () async => cerro = true,
        );

        await tester.tap(find.byKey(const Key('menu-compacto')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('menu-compacto-cerrar-sesion')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('menu-compacto-cerrar-sesion')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('confirmacion-confirmar')));
        await tester.pumpAndSettle();
        expect(cerro, isTrue);
      },
    );

    testWidgets('si Core no responde, el menú sigue usable con el rol', (
      tester,
    ) async {
      await _montar(
        tester,
        ancho: 1024,
        rol: RolUsuario.aliado,
        fuente: _FuenteQueFalla(),
      );

      expect(find.text('MANI'), findsOneWidget);
      expect(find.text('Aliado'), findsOneWidget);
      expect(find.text('Solicitudes'), findsOneWidget);
      expect(find.byKey(const Key('menu-cerrar-sesion')), findsOneWidget);
    });

    testWidgets('resalta la entrada de la ruta actual y sus subrutas', (
      tester,
    ) async {
      await _montar(
        tester,
        ancho: 1024,
        rol: RolUsuario.cliente,
        ubicacion: '/cliente/sedes',
      );

      final activa = tester.widget<TextButton>(
        find.byKey(const Key('menu-entrada-/cliente/sedes')),
      );
      final inactiva = tester.widget<TextButton>(
        find.byKey(const Key('menu-entrada-/perfil/editar')),
      );
      expect(activa.style?.backgroundColor?.resolve({}), isNotNull);
      expect(inactiva.style?.backgroundColor?.resolve({}), isNull);
    });

    testWidgets('en una subruta solo resalta la entrada más específica', (
      tester,
    ) async {
      await _montar(
        tester,
        ancho: 1024,
        rol: RolUsuario.cliente,
        ubicacion: '/cliente/solicitudes/nueva',
      );

      Color? fondo(String ruta) => tester
          .widget<TextButton>(find.byKey(Key('menu-entrada-$ruta')))
          .style
          ?.backgroundColor
          ?.resolve({});
      expect(fondo('/cliente/solicitudes/nueva'), isNotNull);
      // "Mis solicitudes" es prefijo de la ruta pero no debe resaltarse.
      expect(fondo('/cliente/solicitudes'), isNull);
    });
  });

  group('SCRUM-1650 — confirmación antes de cerrar sesión', () {
    final variantes = {
      'botón de escritorio': (ancho: 1024.0, menu: false),
      'ícono de móvil': (ancho: 390.0, menu: false),
      'opción del menú desplegable': (ancho: 390.0, menu: true),
    };

    Future<void> pedirCierre(WidgetTester tester, {required bool menu}) async {
      if (menu) {
        await tester.tap(find.byKey(const Key('menu-compacto')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('menu-compacto-cerrar-sesion')));
      } else {
        await tester.tap(find.byKey(const Key('menu-cerrar-sesion')));
      }
      await tester.pumpAndSettle();
    }

    for (final MapEntry(key: nombre, value: v) in variantes.entries) {
      testWidgets('$nombre: muestra el diálogo y confirmar cierra la sesión', (
        tester,
      ) async {
        var cierres = 0;
        await _montar(
          tester,
          ancho: v.ancho,
          rol: RolUsuario.cliente,
          onCerrarSesion: () async => cierres++,
        );

        await pedirCierre(tester, menu: v.menu);

        expect(find.text('¿Cerrar sesión?'), findsOneWidget);
        expect(cierres, 0, reason: 'no cierra antes de confirmar');

        await tester.tap(find.byKey(const ValueKey('confirmacion-confirmar')));
        await tester.pumpAndSettle();

        expect(cierres, 1);
        expect(find.text('¿Cerrar sesión?'), findsNothing);
      });

      testWidgets('$nombre: cancelar no cierra y deja la pantalla igual', (
        tester,
      ) async {
        var cierres = 0;
        await _montar(
          tester,
          ancho: v.ancho,
          rol: RolUsuario.cliente,
          onCerrarSesion: () async => cierres++,
        );

        await pedirCierre(tester, menu: v.menu);
        await tester.tap(find.byKey(const ValueKey('confirmacion-cancelar')));
        await tester.pumpAndSettle();

        expect(cierres, 0);
        expect(find.text('¿Cerrar sesión?'), findsNothing);
        expect(find.text('contenido de la pantalla'), findsOneWidget);
        expect(find.byKey(const Key('menu-cerrar-sesion')), findsOneWidget);
      });
    }

    testWidgets('tocar fuera del diálogo equivale a cancelar', (tester) async {
      var cierres = 0;
      await _montar(
        tester,
        ancho: 1024,
        rol: RolUsuario.cliente,
        onCerrarSesion: () async => cierres++,
      );

      await pedirCierre(tester, menu: false);
      await tester.tapAt(const Offset(5, 795));
      await tester.pumpAndSettle();

      expect(find.text('¿Cerrar sesión?'), findsNothing);
      expect(cierres, 0);
    });
  });
}
