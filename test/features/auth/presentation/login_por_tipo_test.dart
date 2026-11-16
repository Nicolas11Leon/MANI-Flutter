import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/session/guardas_ruta.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/features/auth/domain/entities/auth_failure.dart';
import 'package:mani/features/auth/domain/entities/user_entity.dart';
import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:mani/features/auth/domain/usecases/login_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_aliado_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_cliente_empresa_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_cliente_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_empresa_usecase.dart';
import 'package:mani/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:mani/core/widgets/mani_personaje.dart';
import 'package:mani/features/auth/presentation/pages/login_page.dart';

class _RepoFalso implements IAuthRepository {
  final intentos = <({String email, String password})>[];
  AuthFailure? falla;

  @override
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    intentos.add((email: email, password: password));
    if (falla != null) throw falla!;
    return const UserEntity(id: 'u-1', email: 'ana@mani.app');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

AuthCubit _cubit(_RepoFalso repo) => AuthCubit(
  loginUseCase: LoginUseCase(repo),
  registerClienteUseCase: RegisterClienteUseCase(repo),
  registerAliadoUseCase: RegisterAliadoUseCase(repo),
  registerEmpresaUseCase: RegisterEmpresaUseCase(repo),
  registerClienteEmpresaUseCase: RegisterClienteEmpresaUseCase(repo),
);

/// SCRUM-1370 (HU-M02-02): inicio de sesión por tipo de usuario. La pestaña es presentación; el destino y los permisos
/// los decide el rol del token (C3).
void main() {
  late _RepoFalso repo;

  setUp(() {
    repo = _RepoFalso();
    sl.registerFactory<AuthCubit>(() => _cubit(repo));
  });
  tearDown(() async => GetIt.instance.reset());

  Future<void> montar(
    WidgetTester tester, {
    required RolUsuario rolDelToken,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 1800);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: rutaLogin,
      routes: [
        GoRoute(
          path: rutaLogin,
          builder: (_, _) => LoginPage(rolDeSesion: () => rolDelToken),
        ),
        GoRoute(
          path: rutaInicio,
          builder: (_, _) => const Scaffold(body: Text('pantalla-de-inicio')),
        ),
        GoRoute(
          path: '/admin/verificacion-aliados',
          builder: (_, _) => const Scaffold(body: Text('pantalla-admin')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  Future<void> ingresar(WidgetTester tester) async {
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'ana@mani.app');
    await tester.enterText(campos.at(1), 'Password123');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'C1: el login RBAC presenta formulario directo de credenciales sin selectores de rol redundantes',
    (tester) async {
      await montar(tester, rolDelToken: RolUsuario.cliente);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Ingresar'), findsOneWidget);
      // Sin pestañas ni selectores confusos
      expect(find.text('Soy Cliente'), findsNothing);
      expect(find.text('Soy Aliado'), findsNothing);
      expect(find.text('Admin'), findsNothing);
      expect(find.text('EMPRESA / TENANT'), findsNothing);
    },
  );

  testWidgets(
    'C1: cada tipo de usuario inicia sesión directamente y aterriza en el inicio según su token RBAC',
    (tester) async {
      for (final rol in [
        RolUsuario.cliente,
        RolUsuario.aliado,
        RolUsuario.adminTenant,
      ]) {
        await montar(tester, rolDelToken: rol);
        await ingresar(tester);

        expect(
          find.text('pantalla-de-inicio'),
          findsOneWidget,
          reason: rol.name,
        );
        expect(
          find.text('¡Bienvenido a MANI!'),
          findsOneWidget,
          reason: 'saludo tras login',
        );
        await GetIt.instance.reset();
        sl.registerFactory<AuthCubit>(() => _cubit(repo));
      }
    },
  );

  testWidgets('C3: al servidor solo llegan el correo y la contraseña', (
    tester,
  ) async {
    await montar(tester, rolDelToken: RolUsuario.cliente);
    await ingresar(tester);

    expect(repo.intentos, [(email: 'ana@mani.app', password: 'Password123')]);
  });

  testWidgets(
    'C2: credenciales inválidas muestran el mensaje genérico, no navegan y no crean sesión',
    (tester) async {
      repo.falla = const AuthFailure('Correo o contraseña incorrectos.');
      await montar(tester, rolDelToken: RolUsuario.desconocido);

      await ingresar(tester);

      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      expect(find.text('pantalla-de-inicio'), findsNothing);
      expect(
        find.text('Ingresar'),
        findsOneWidget,
        reason: 'sigue en el formulario',
      );
    },
  );

  testWidgets('C2: sin correo ni contraseña no se llama al servidor', (
    tester,
  ) async {
    await montar(tester, rolDelToken: RolUsuario.cliente);
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(repo.intentos, isEmpty);
  });

  testWidgets(
    'el muñequito aparece una sola vez y el error de credenciales sale dentro de la tarjeta',
    (tester) async {
      repo.falla = const AuthFailure('Correo o contraseña incorrectos.');
      await montar(tester, rolDelToken: RolUsuario.desconocido);
      expect(find.byType(ManiPersonaje), findsOneWidget);

      await ingresar(tester);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    },
  );

  testWidgets(
    'en celular con el teclado abierto el muñequito se reduce y el botón se alcanza',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: rutaLogin,
        routes: [
          GoRoute(path: rutaLogin, builder: (_, _) => const LoginPage()),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(ManiPersonaje)).height,
        lessThanOrEqualTo(72),
      );
      await tester.ensureVisible(find.text('Ingresar'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Ingresar')).bottom,
        lessThanOrEqualTo(340),
      );
    },
  );

  group('C3: el rol del token manda sobre cualquier selección (router)', () {
    test(
      'un cliente no puede abrir rutas de administrador ni de aliado: vuelve a su inicio',
      () {
        for (final destino in [
          '/admin/verificacion-aliados',
          '/admin/categorias',
          '/aliado/solicitudes',
        ]) {
          expect(
            resolverRedireccion(
              ubicacion: destino,
              esPublica: false,
              haySesion: true,
              rol: RolUsuario.cliente,
            ),
            rutaInicioPara(RolUsuario.cliente),
            reason: destino,
          );
        }
      },
    );

    test('un aliado no abre rutas de cliente ni de administrador', () {
      for (final destino in [
        '/cliente/solicitudes',
        '/cliente/pagos/abc',
        '/admin/categorias',
      ]) {
        expect(
          resolverRedireccion(
            ubicacion: destino,
            esPublica: false,
            haySesion: true,
            rol: RolUsuario.aliado,
          ),
          rutaInicioPara(RolUsuario.aliado),
          reason: destino,
        );
      }
    });

    test('un rol desconocido no abre ninguna entrada de negocio', () {
      for (final destino in [
        '/cliente/solicitudes',
        '/aliado/solicitudes',
        '/admin/categorias',
      ]) {
        expect(
          resolverRedireccion(
            ubicacion: destino,
            esPublica: false,
            haySesion: true,
            rol: RolUsuario.desconocido,
          ),
          rutaInicioPara(RolUsuario.desconocido),
          reason: destino,
        );
      }
    });

    test(
      'con sesión abierta, el login lleva al inicio del rol; sin sesión, las rutas piden login',
      () {
        expect(
          resolverRedireccion(
            ubicacion: rutaLogin,
            esPublica: true,
            haySesion: true,
            rol: RolUsuario.aliado,
          ),
          rutaInicioPara(RolUsuario.aliado),
        );
        expect(
          resolverRedireccion(
            ubicacion: '/cliente/solicitudes',
            esPublica: false,
            haySesion: false,
            rol: RolUsuario.desconocido,
          ),
          rutaLogin,
        );
      },
    );
  });
}
