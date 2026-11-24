import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/app_shell.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:mani/features/auth/domain/usecases/login_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_aliado_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_cliente_empresa_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_cliente_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_empresa_usecase.dart';
import 'package:mani/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:mani/features/auth/presentation/pages/login_page.dart';
import 'package:mani/features/auth/presentation/widgets/auth_layout.dart';

class _RepoFalso implements IAuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FuenteFija implements FuenteDatosSesion {
  @override
  Future<DatosSesion> cargar() async => const DatosSesion(
    nombreUsuario: 'Ana María Pérez Rodríguez',
    nombreTenant: 'Plomería y Electricidad Express del Norte',
  );
}

/// Anchos de referencia: móvil, tableta, escritorio pequeño y amplio.
const _anchos = [360.0, 768.0, 1024.0, 1440.0];

Future<void> _pantalla(WidgetTester tester, double ancho, Widget home) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(ancho, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: home));
  await tester.pumpAndSettle();
}

/// Guardas de layout del rediseño: ninguna superficie principal desborda
/// (un RenderFlex que desborda lanza en pruebas) en los anchos de referencia.
void main() {
  setUp(() {
    final repo = _RepoFalso();
    sl.registerFactory<AuthCubit>(
      () => AuthCubit(
        loginUseCase: LoginUseCase(repo),
        registerClienteUseCase: RegisterClienteUseCase(repo),
        registerAliadoUseCase: RegisterAliadoUseCase(repo),
        registerEmpresaUseCase: RegisterEmpresaUseCase(repo),
        registerClienteEmpresaUseCase: RegisterClienteEmpresaUseCase(repo),
      ),
    );
  });
  tearDown(() async => GetIt.instance.reset());

  for (final ancho in _anchos) {
    testWidgets('login sin desbordes a ${ancho.toInt()} px', (tester) async {
      await _pantalla(
        tester,
        ancho,
        LoginPage(rolDeSesion: () => RolUsuario.cliente),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Ingresar'), findsOneWidget);
      // El login de SCRUM-1646 (Nicolás) no lleva el panel de marca de
      // escritorio de #152; se valida solo que no desborde.
    });

    for (final rol in [
      RolUsuario.cliente,
      RolUsuario.aliado,
      RolUsuario.adminTenant,
    ]) {
      testWidgets('shell de ${rol.name} sin desbordes a ${ancho.toInt()} px', (
        tester,
      ) async {
        await _pantalla(
          tester,
          ancho,
          AppShell(
            rol: rol,
            ubicacion: '/inicio',
            fuenteDatos: _FuenteFija(),
            onNavegar: (_) {},
            onCerrarSesion: () async {},
            child: const ManiEstadoVacio(
              titulo: 'Aún no tienes trabajos',
              texto: 'Cuando aceptes una solicitud aparecerá aquí.',
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'barra de envío y estados sin desbordes a ${ancho.toInt()} px',
      (tester) async {
        await _pantalla(
          tester,
          ancho,
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(ManiSpace.lg),
              child: Column(
                children: [
                  AuthBarraEnvio(
                    titulo: 'Garantía de Servicio para Clientes',
                    descripcion:
                        'Tus datos de hogar quedan protegidos y sólo se '
                        'comparten al confirmar un servicio.',
                    etiquetaBoton: 'CREAR MI CUENTA DE CLIENTE',
                    cargando: false,
                    onPressed: () {},
                  ),
                  ManiGap.vLg,
                  ManiEstadoError(
                    mensaje:
                        'No pudimos cargar tus solicitudes. Revisa tu '
                        'conexión e inténtalo de nuevo.',
                    onReintentar: () {},
                  ),
                  ManiGap.vLg,
                  const ManiStatusBadge(
                    etiqueta: 'Pendiente de verificación documental',
                    tono: ManiTono.aviso,
                    icono: Icons.hourglass_top_rounded,
                  ),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('la lista esqueleto no desborda a 360 px', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ManiSkeletonLista()),
      ),
    );
    // Late sin fin: se avanza un tramo fijo en vez de esperar a que pare.
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('el skeleton queda estático con movimiento reducido', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ManiSkeleton(),
        ),
      ),
    );
    // Sin animación en curso: no quedan frames pendientes.
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
