import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/session/contexto_plataforma.dart';
import 'package:mani/core/session/guardas_ruta.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/app_shell.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/shell/menu_por_rol.dart';
import 'package:mani/features/platform/data/tenants_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _t2 = '10000000-0000-4000-8000-000000000021';
const _clienteT2 = UsuarioTenant(
  id: '30000000-0000-4000-8000-000000000022',
  email: 'cliente.t2@qa.mani.test',
  rol: 'CLIENTE',
);
const _aliadoT2 = UsuarioTenant(
  id: '30000000-0000-4000-8000-000000000023',
  email: 'aliado.t2@qa.mani.test',
  rol: 'ALIADO',
);

class _Sesion implements FuenteDatosSesion {
  @override
  Future<DatosSesion> cargar() async =>
      const DatosSesion(nombreUsuario: 'Plataforma', nombreTenant: 'ACME');
}

class _Tenants implements FuenteTenants {
  @override
  Future<List<TenantPlataforma>> listar() async => const [
    TenantPlataforma(
      id: _t2,
      nombre: 'Nova',
      slug: 'nova-mantenimiento',
      estado: EstadoTenant.activo,
    ),
  ];

  @override
  Future<TenantPlataforma> cambiarEstado(
    String tenantId,
    EstadoTenant estado,
    String motivo,
  ) => throw UnimplementedError();

  @override
  Future<List<CambioEstadoTenant>> historial(String tenantId) async => [];
}

class _Usuarios implements FuenteUsuariosTenant {
  final pedidos = <String>[];

  @override
  Future<List<UsuarioTenant>> listar(String tenantId) async {
    pedidos.add(tenantId);
    return const [_clienteT2, _aliadoT2];
  }
}

/// JWT sin firmar con el rol dado: `rolDesdeAccessToken` solo lee el payload.
String _tokenConRol(String rol) {
  String parte(Map<String, dynamic> o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${parte({'alg': 'none'})}.${parte({
    'sub': 'u-1',
    'app_metadata': {'tenant_id': 'otro', 'user_role': rol},
  })}.firma';
}

/// Auth de Supabase mínimo: la sesión vigente y el flujo de cambios de sesión.
class _AuthFalso implements GoTrueClient {
  final cambios = StreamController<AuthState>.broadcast();
  Session? sesion;

  @override
  Session? get currentSession => sesion;

  @override
  Stream<AuthState> get onAuthStateChange => cambios.stream;

  Session conRol(String rol) => Session(
    accessToken: _tokenConRol(rol),
    tokenType: 'bearer',
    user: const User(
      id: 'u-1',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-11-05T00:00:00Z',
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Set<String> _rutas(RolUsuario rol, {RolUsuario? como}) => {
  for (final e
      in como == null
          ? entradasMenuPara(rol)
          : entradasMenuPara(rol, actuandoComo: como))
    e.ruta,
};

void main() {
  group('SCRUM-901 · contexto del administrador de plataforma', () {
    test(
      'las cabeceras siguen el tenant elegido y el usuario con el que actúa',
      () {
        final c = ContextoPlataforma();
        expect(c.cabeceras, isEmpty);
        expect(c.rolEfectivo, RolUsuario.adminTenant);

        var avisos = 0;
        c.addListener(() => avisos++);
        c.elegirTenant(_t2, 'Nova');
        expect(c.cabeceras, {'X-Mani-Tenant': _t2});

        c.actuarComoUsuario(_clienteT2);
        expect(c.cabeceras, {
          'X-Mani-Tenant': _t2,
          'X-Mani-Actuar-Como': _clienteT2.id,
        });
        expect(c.rolEfectivo, RolUsuario.cliente);

        // Cambiar de tenant deja de actuar como el usuario anterior.
        c.elegirTenant('otro', 'Otro');
        expect(c.actuarComo, isNull);
        c.limpiar();
        expect(c.cabeceras, isEmpty);
        expect(avisos, 4);
        expect(c.version, 4);
      },
    );

    test('el menú del admin de plataforma es el del rol con el que actúa', () {
      final admin = _rutas(RolUsuario.adminPlataforma);
      expect(admin, contains('/plataforma/tenants'));
      expect(admin, containsAll(_rutas(RolUsuario.adminTenant)));
      expect(admin.where((r) => r.startsWith('/cliente/')), isEmpty);

      final comoCliente = _rutas(
        RolUsuario.adminPlataforma,
        como: RolUsuario.cliente,
      );
      expect(comoCliente, contains('/plataforma/tenants'));
      expect(comoCliente, containsAll(_rutas(RolUsuario.cliente)));
      expect(comoCliente.where((r) => r.startsWith('/admin/')), isEmpty);

      final comoAliado = _rutas(
        RolUsuario.adminPlataforma,
        como: RolUsuario.aliado,
      );
      expect(comoAliado, containsAll(_rutas(RolUsuario.aliado)));
    });

    test(
      'las guardas dejan al admin de plataforma abrir todas las pantallas',
      () {
        for (final ruta in [
          '/plataforma/tenants',
          '/admin/quejas',
          '/cliente/solicitudes',
          '/aliado/solicitudes',
        ]) {
          expect(rolPuedeAbrir(RolUsuario.adminPlataforma, ruta), isTrue);
        }
      },
    );

    test(
      'las cabeceras solo salen con una sesión de admin de plataforma: un contexto '
      'que quedó de otra sesión no bloquea al cliente que entra después',
      () {
        // Reproduce el 403 MANI-PLA-403 de «Nueva solicitud»: el admin de
        // plataforma actuó como un cliente, otra persona inició sesión como
        // cliente en el mismo navegador y la app seguía enviando el contexto.
        final auth = _AuthFalso();
        addTearDown(auth.cambios.close);
        final c = ContextoPlataforma(auth: auth)
          ..elegirTenant(_t2, 'Nova')
          ..actuarComoUsuario(_clienteT2);

        auth.sesion = auth.conRol('admin_plataforma');
        expect(c.cabeceras, {
          'X-Mani-Tenant': _t2,
          'X-Mani-Actuar-Como': _clienteT2.id,
        });
        for (final rol in ['cliente', 'aliado', 'admin_tenant']) {
          auth.sesion = auth.conRol(rol);
          expect(c.cabeceras, isEmpty, reason: rol);
        }
        auth.sesion = null;
        expect(c.cabeceras, isEmpty, reason: 'sin sesión');
      },
    );

    test(
      'el contexto se borra al iniciar o cerrar sesión, no al refrescar el token',
      () async {
        final eventos = StreamController<AuthChangeEvent>();
        final c = ContextoPlataforma();
        final sub = c.escucharSesion(eventos.stream);
        addTearDown(() async {
          await sub.cancel();
          await eventos.close();
        });

        Future<void> emitir(AuthChangeEvent e) async {
          eventos.add(e);
          await Future<void>.delayed(Duration.zero);
        }

        c
          ..elegirTenant(_t2, 'Nova')
          ..actuarComoUsuario(_clienteT2);
        await emitir(AuthChangeEvent.tokenRefreshed);
        expect(
          c.actuarComo,
          _clienteT2,
          reason: 'refrescar no cambia de sesión',
        );

        await emitir(AuthChangeEvent.signedOut);
        expect(c.cabeceras, isEmpty);

        c.elegirTenant(_t2, 'Nova');
        await emitir(AuthChangeEvent.signedIn);
        expect(
          c.tenantId,
          isNull,
          reason: 'otro inicio de sesión empieza limpio',
        );
      },
    );

    test(
      'con el auth de la app, el contexto se borra al cambiar de sesión',
      () async {
        final auth = _AuthFalso();
        addTearDown(auth.cambios.close);
        final c = ContextoPlataforma(auth: auth)
          ..elegirTenant(_t2, 'Nova')
          ..actuarComoUsuario(_clienteT2);

        auth.cambios.add(AuthState(AuthChangeEvent.signedIn, null));
        await Future<void>.delayed(Duration.zero);
        expect(c.tenantId, isNull);
        expect(c.actuarComo, isNull);
      },
    );

    test('sin auth (pruebas del shell) las cabeceras son las elegidas', () {
      final c = ContextoPlataforma()..elegirTenant(_t2, 'Nova');
      expect(c.cabeceras, {'X-Mani-Tenant': _t2});
    });

    test(
      'GatewayClient envía las cabeceras del contexto en cada petición',
      () async {
        final c = ContextoPlataforma()
          ..elegirTenant(_t2, 'Nova')
          ..actuarComoUsuario(_aliadoT2);
        final vistas = <http.BaseRequest>[];
        final gateway = GatewayClient(
          baseUrl: 'http://gateway',
          tokenProvider: () async => 'tok',
          httpClient: MockClient((req) async {
            vistas.add(req);
            return http.Response(jsonEncode({'ok': true}), 200);
          }),
          cabecerasExtra: () => c.cabeceras,
        );

        await gateway.get('/api/v1/core/allies/me/history');
        expect(vistas.single.headers['X-Mani-Tenant'], _t2);
        expect(vistas.single.headers['X-Mani-Actuar-Como'], _aliadoT2.id);
        expect(vistas.single.headers['Authorization'], 'Bearer tok');

        c.limpiar();
        await gateway.get('/api/v1/core/profiles/me');
        expect(vistas.last.headers.containsKey('X-Mani-Tenant'), isFalse);
      },
    );

    testWidgets(
      'el shell muestra el selector y cambia de menú al actuar como un cliente',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final contexto = ContextoPlataforma();
        final usuarios = _Usuarios();
        final navegaciones = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: AppShell(
              rol: RolUsuario.adminPlataforma,
              ubicacion: '/inicio',
              fuenteDatos: _Sesion(),
              onNavegar: navegaciones.add,
              onCerrarSesion: () async {},
              contextoPlataforma: contexto,
              fuenteTenants: _Tenants(),
              fuenteUsuarios: usuarios,
              child: const Text('contenido'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('selector-contexto-plataforma')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('menu-entrada-/admin/quejas')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('menu-entrada-/plataforma/tenants')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('selector-tenant')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('selector-tenant-$_t2')));
        await tester.pumpAndSettle();
        expect(contexto.tenantId, _t2);
        expect(find.text('Nova'), findsOneWidget);

        await tester.tap(find.byKey(const Key('selector-actuar-como')));
        await tester.pumpAndSettle();
        expect(usuarios.pedidos, [_t2]);
        await tester.tap(find.byKey(Key('selector-actuar-${_clienteT2.id}')));
        await tester.pumpAndSettle();

        expect(contexto.actuarComo, _clienteT2);
        expect(
          find.byKey(const Key('menu-entrada-/cliente/solicitudes')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('menu-entrada-/admin/quejas')),
          findsNothing,
        );
        expect(navegaciones, ['/inicio', '/inicio']);
      },
    );

    testWidgets('los demás roles no ven el selector', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            rol: RolUsuario.adminTenant,
            ubicacion: '/inicio',
            fuenteDatos: _Sesion(),
            onNavegar: (_) {},
            onCerrarSesion: () async {},
            contextoPlataforma: ContextoPlataforma(),
            fuenteTenants: _Tenants(),
            fuenteUsuarios: _Usuarios(),
            child: const Text('contenido'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('selector-contexto-plataforma')),
        findsNothing,
      );
    });
  });
}
