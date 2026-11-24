import 'dart:convert';
import 'dart:ui' show Tristate;

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
import 'package:mani/core/shell/navegacion_movil.dart';
import 'package:mani/features/notifications/data/avisos_datasource.dart';
import 'package:mani/features/notifications/domain/aviso.dart';

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

class _AvisosFijos implements FuenteAvisos {
  _AvisosFijos(this.items);
  final List<Aviso> items;
  @override
  Future<BandejaAvisos> listar({int limite = 50}) async =>
      BandejaAvisos(items: items, simulada: true, proveedor: 'mock');
}

Aviso _avisoDePrueba(String id, {bool leido = false}) => Aviso(
  id: id,
  tipo: 'SOLICITUD_ASIGNADA',
  canal: 'PUSH',
  payload: const {},
  leidoEn: leido ? DateTime(2026, 11, 14) : null,
);

Future<void> _montar(
  WidgetTester tester, {
  required double ancho,
  required RolUsuario rol,
  FuenteDatosSesion? fuente,
  String ubicacion = '/',
  ValueChanged<String>? onNavegar,
  Future<void> Function()? onCerrarSesion,
  bool Function()? puedeVolver,
  VoidCallback? onVolver,
  FuenteAvisos? fuenteAvisos,
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
        puedeVolver: puedeVolver,
        onVolver: onVolver,
        fuenteAvisos: fuenteAvisos,
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
      expect(find.text('Mis zonas'), findsOneWidget);
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
      // Cerrar sesión pide confirmación (SCRUM-1650, QAS-39).
      await tester.tap(find.byKey(const ValueKey('confirmacion-confirmar')));
      await tester.pumpAndSettle();

      expect(cerro, isTrue);
    });

    testWidgets(
      'cliente en móvil: cinco destinos con Inicio en el centro, sin menú desplegable',
      (tester) async {
        String? destino;
        await _montar(
          tester,
          ancho: 390,
          rol: RolUsuario.cliente,
          onNavegar: (r) => destino = r,
        );

        expect(find.byKey(const Key('menu-compacto')), findsNothing);
        for (final ruta in const [
          '/cliente/solicitudes/nueva',
          '/servicios',
          '/inicio',
          '/cliente/solicitudes',
          '/cuenta',
        ]) {
          expect(
            find.byKey(Key('menu-entrada-$ruta')),
            findsOneWidget,
            reason: ruta,
          );
        }

        // Orden de izquierda a derecha: Nueva, Servicios, Inicio (centro), Mis pedidos, Perfil.
        double x(String ruta) =>
            tester.getCenter(find.byKey(Key('menu-entrada-$ruta'))).dx;
        final orden = [
          x('/cliente/solicitudes/nueva'),
          x('/servicios'),
          x('/inicio'),
          x('/cliente/solicitudes'),
          x('/cuenta'),
        ];
        expect([...orden]..sort(), orden);
        expect(x('/inicio'), closeTo(390 / 2, 1));

        await tester.tap(
          find.byKey(const Key('menu-entrada-/cliente/solicitudes')),
        );
        await tester.pumpAndSettle();
        expect(destino, '/cliente/solicitudes');
      },
    );

    testWidgets(
      'el cliente no tiene Avisos en la barra: los abre con la campana de arriba',
      (tester) async {
        String? destino;
        await _montar(
          tester,
          ancho: 390,
          rol: RolUsuario.cliente,
          onNavegar: (r) => destino = r,
        );

        expect(
          find.byKey(const Key('menu-entrada-/perfil/avisos')),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('menu-avisos')));
        await tester.pumpAndSettle();
        expect(destino, '/perfil/avisos');
      },
    );

    testWidgets(
      'el administrador de plataforma conserva la barra de cuatro destinos con Avisos',
      (tester) async {
        await _montar(tester, ancho: 390, rol: RolUsuario.adminPlataforma);

        for (final ruta in const [
          '/inicio',
          '/servicios',
          '/perfil/avisos',
          '/cuenta',
        ]) {
          expect(
            find.byKey(Key('menu-entrada-$ruta')),
            findsOneWidget,
            reason: ruta,
          );
        }
        expect(find.byKey(const Key('menu-avisos')), findsNothing);
      },
    );

    testWidgets(
      'en móvil cerrar sesión sigue en la barra superior del administrador de plataforma',
      (tester) async {
        var cerro = false;
        await _montar(
          tester,
          ancho: 390,
          rol: RolUsuario.adminPlataforma,
          onCerrarSesion: () async => cerro = true,
        );

        expect(find.byKey(const Key('menu-cerrar-sesion')), findsOneWidget);
        await tester.tap(find.byKey(const Key('menu-cerrar-sesion')));
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

  group('SCRUM-1647 — navegación para celular (solo ancho compacto)', () {
    testWidgets(
      'el escritorio no tiene barra inferior, campana, volver ni deslizado',
      (tester) async {
        await _montar(
          tester,
          ancho: 1200,
          rol: RolUsuario.cliente,
          ubicacion: '/inicio',
        );
        expect(find.byKey(const Key('barra-inferior')), findsNothing);
        expect(find.byKey(const Key('menu-atras')), findsNothing);
        expect(find.byKey(const Key('menu-avisos')), findsNothing);
        expect(find.byKey(const Key('deslizar-menus')), findsNothing);
      },
    );

    testWidgets('en los cuatro menús del cliente no se muestra volver', (
      tester,
    ) async {
      for (final ruta in const [
        '/inicio',
        '/servicios',
        '/cuenta',
        '/cliente/solicitudes',
      ]) {
        await _montar(
          tester,
          ancho: 390,
          rol: RolUsuario.cliente,
          ubicacion: ruta,
        );
        expect(find.byKey(const Key('menu-atras')), findsNothing, reason: ruta);
        expect(
          find.byKey(const Key('menu-titulo-seccion')),
          findsNothing,
          reason: ruta,
        );
      }
    });

    testWidgets('los avisos del cliente muestran volver al inicio', (
      tester,
    ) async {
      String? destino;
      await _montar(
        tester,
        ancho: 390,
        rol: RolUsuario.cliente,
        ubicacion: '/perfil/avisos',
        onNavegar: (r) => destino = r,
      );
      expect(find.byKey(const Key('menu-atras')), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu-atras')));
      await tester.pumpAndSettle();
      expect(destino, '/inicio');
    });

    testWidgets(
      'una pantalla de Servicios muestra volver y su título, y vuelve a Servicios',
      (tester) async {
        String? destino;
        await _montar(
          tester,
          ancho: 390,
          rol: RolUsuario.cliente,
          ubicacion: '/cliente/quejas',
          onNavegar: (r) => destino = r,
        );

        expect(find.byKey(const Key('menu-atras')), findsOneWidget);
        expect(find.byKey(const Key('menu-titulo-seccion')), findsOneWidget);
        await tester.tap(find.byKey(const Key('menu-atras')));
        await tester.pumpAndSettle();
        expect(destino, '/servicios');
      },
    );

    testWidgets('una pantalla de Perfil vuelve a Perfil', (tester) async {
      String? destino;
      await _montar(
        tester,
        ancho: 390,
        rol: RolUsuario.cliente,
        ubicacion: '/perfil/editar',
        onNavegar: (r) => destino = r,
      );

      await tester.tap(find.byKey(const Key('menu-atras')));
      await tester.pumpAndSettle();
      expect(destino, '/cuenta');
    });

    testWidgets('el detalle de un pedido vuelve a Mis pedidos', (tester) async {
      String? destino;
      await _montar(
        tester,
        ancho: 390,
        rol: RolUsuario.cliente,
        ubicacion: '/cliente/solicitudes/123',
        onNavegar: (r) => destino = r,
      );

      await tester.tap(find.byKey(const Key('menu-atras')));
      await tester.pumpAndSettle();
      expect(destino, '/cliente/solicitudes');
    });

    testWidgets(
      'si hay una pantalla anterior en la pila, volver regresa a ella',
      (tester) async {
        String? destino;
        var volvio = false;
        await _montar(
          tester,
          ancho: 390,
          rol: RolUsuario.cliente,
          ubicacion: '/cliente/quejas',
          onNavegar: (r) => destino = r,
          puedeVolver: () => true,
          onVolver: () => volvio = true,
        );

        await tester.tap(find.byKey(const Key('menu-atras')));
        await tester.pumpAndSettle();
        expect(volvio, isTrue);
        expect(destino, isNull);
      },
    );

    testWidgets(
      'el atrás del sistema sube un nivel en celular y solo sale desde el inicio',
      (tester) async {
        final destinos = <String>[];
        Future<bool> atras(String ubicacion) async {
          destinos.clear();
          await _montar(
            tester,
            ancho: 390,
            rol: RolUsuario.cliente,
            ubicacion: ubicacion,
            onNavegar: destinos.add,
          );
          final manejado = await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          return manejado;
        }

        expect(await atras('/cliente/quejas'), isTrue);
        expect(destinos, ['/servicios']);
        expect(await atras('/perfil/editar'), isTrue);
        expect(destinos, ['/cuenta']);
        expect(await atras('/servicios'), isTrue);
        expect(destinos, ['/inicio']);
        expect(await atras('/cliente/solicitudes'), isTrue);
        expect(destinos, ['/inicio']);

        // En el inicio el sistema no lo intercepta: la app se cierra, como en cualquier app.
        expect(await atras('/inicio'), isFalse);
        expect(destinos, isEmpty);
      },
    );

    testWidgets('en escritorio el atrás del sistema no se intercepta', (
      tester,
    ) async {
      final destinos = <String>[];
      await _montar(
        tester,
        ancho: 1200,
        rol: RolUsuario.cliente,
        ubicacion: '/cliente/solicitudes',
        onNavegar: destinos.add,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(destinos, isEmpty);
    });

    testWidgets(
      'el destino activo de la barra del cliente sigue a la pantalla',
      (tester) async {
        Future<List<bool>> marcas(String ubicacion) async {
          await _montar(
            tester,
            ancho: 390,
            rol: RolUsuario.cliente,
            ubicacion: ubicacion,
          );
          bool sel(String ruta) =>
              tester
                  .getSemantics(find.byKey(Key('menu-entrada-$ruta')))
                  .flagsCollection
                  .isSelected ==
              Tristate.isTrue;
          return [
            sel('/servicios'),
            sel('/inicio'),
            sel('/cliente/solicitudes'),
            sel('/cuenta'),
          ];
        }

        // Servicios, Inicio, Mis pedidos, Perfil
        expect(await marcas('/inicio'), [false, true, false, false]);
        expect(await marcas('/servicios'), [true, false, false, false]);
        expect(await marcas('/cliente/quejas'), [true, false, false, false]);
        expect(await marcas('/cliente/solicitudes'), [
          false,
          false,
          true,
          false,
        ]);
        expect(await marcas('/cliente/solicitudes/123'), [
          false,
          false,
          true,
          false,
        ]);
        expect(await marcas('/perfil/editar'), [false, false, false, true]);
        expect(await marcas('/cliente/sedes'), [false, false, false, true]);
      },
    );

    testWidgets(
      'en un flujo de varios pasos no hay barra inferior ni deslizado y la flecha sale al inicio',
      (tester) async {
        String? destino;
        await _montar(
          tester,
          ancho: 390,
          rol: RolUsuario.cliente,
          ubicacion: '/cliente/solicitudes/nueva',
          onNavegar: (r) => destino = r,
        );

        expect(find.byKey(const Key('barra-inferior')), findsNothing);
        expect(find.byKey(const Key('deslizar-menus')), findsNothing);
        await tester.tap(find.byKey(const Key('menu-atras')));
        await tester.pumpAndSettle();
        expect(destino, '/inicio');
      },
    );

    testWidgets('la campana muestra cuántos avisos sin leer hay', (
      tester,
    ) async {
      await _montar(
        tester,
        ancho: 390,
        rol: RolUsuario.cliente,
        ubicacion: '/inicio',
        fuenteAvisos: _AvisosFijos([
          _avisoDePrueba('a'),
          _avisoDePrueba('b'),
          _avisoDePrueba('c', leido: true),
        ]),
      );
      expect(find.byKey(const Key('menu-avisos-contador')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('sin avisos sin leer la campana no muestra número', (
      tester,
    ) async {
      await _montar(
        tester,
        ancho: 390,
        rol: RolUsuario.cliente,
        ubicacion: '/inicio',
        fuenteAvisos: _AvisosFijos([_avisoDePrueba('a', leido: true)]),
      );
      expect(find.byKey(const Key('menu-avisos')), findsOneWidget);
      expect(find.byKey(const Key('menu-avisos-contador')), findsNothing);
    });
  });

  group('SCRUM-1647 — deslizar entre los menús del cliente', () {
    test('el orden es Servicios, Inicio, Mis pedidos y Perfil', () {
      expect(menusDeslizablesCliente, [
        '/servicios',
        '/inicio',
        '/cliente/solicitudes',
        '/cuenta',
      ]);
    });

    test('cada menú tiene su vecino y los extremos no dan la vuelta', () {
      expect(
        menuVecinoAlDeslizar('/inicio', haciaAdelante: true),
        '/cliente/solicitudes',
      );
      expect(
        menuVecinoAlDeslizar('/inicio', haciaAdelante: false),
        '/servicios',
      );
      expect(
        menuVecinoAlDeslizar('/cliente/solicitudes', haciaAdelante: true),
        '/cuenta',
      );
      expect(menuVecinoAlDeslizar('/servicios', haciaAdelante: false), isNull);
      expect(menuVecinoAlDeslizar('/cuenta', haciaAdelante: true), isNull);
    });

    test('fuera de los cuatro menús no se desliza', () {
      expect(
        menuVecinoAlDeslizar('/cliente/solicitudes/nueva', haciaAdelante: true),
        isNull,
      );
      expect(
        menuVecinoAlDeslizar('/perfil/avisos', haciaAdelante: false),
        isNull,
      );
      expect(
        menuVecinoAlDeslizar('/cliente/solicitudes/123', haciaAdelante: true),
        isNull,
      );
    });

    testWidgets(
      'deslizar el dedo a la izquierda lleva al menú de la derecha, y viceversa',
      (tester) async {
        final destinos = <String>[];
        await _montar(
          tester,
          ancho: 390,
          rol: RolUsuario.cliente,
          ubicacion: '/inicio',
          onNavegar: destinos.add,
        );

        await tester.fling(
          find.byKey(const Key('deslizar-menus')),
          const Offset(-300, 0),
          1500,
        );
        await tester.pumpAndSettle();
        await tester.fling(
          find.byKey(const Key('deslizar-menus')),
          const Offset(300, 0),
          1500,
        );
        await tester.pumpAndSettle();
        expect(destinos, ['/cliente/solicitudes', '/servicios']);
      },
    );

    testWidgets('un gesto lento o corto no cambia de menú', (tester) async {
      final destinos = <String>[];
      await _montar(
        tester,
        ancho: 390,
        rol: RolUsuario.cliente,
        ubicacion: '/inicio',
        onNavegar: destinos.add,
      );

      await tester.fling(
        find.byKey(const Key('deslizar-menus')),
        const Offset(-300, 0),
        100,
      );
      await tester.pumpAndSettle();
      expect(destinos, isEmpty);
    });

    testWidgets('el administrador de plataforma no desliza entre menús', (
      tester,
    ) async {
      await _montar(
        tester,
        ancho: 390,
        rol: RolUsuario.adminPlataforma,
        ubicacion: '/inicio',
      );
      expect(find.byKey(const Key('deslizar-menus')), findsNothing);
    });
  });
}
