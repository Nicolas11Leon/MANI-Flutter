import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:mani/features/auth/domain/usecases/login_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_aliado_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_cliente_empresa_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_cliente_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_empresa_usecase.dart';
import 'package:mani/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:mani/features/auth/presentation/pages/login_page.dart';

class _RepoFalso implements IAuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _montar(
  WidgetTester tester, {
  String? rol,
  double ancho = 390,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(ancho, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: LoginPage(rol: rol),
    ),
  );
  await tester.pumpAndSettle();
}

ManiButtonVariante _variante(WidgetTester tester, String etiqueta) => tester
    .widget<ManiButton>(find.widgetWithText(ManiButton, etiqueta))
    .variante;

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

  group(
    'SCRUM-1647 — el login según el rol con el que se llegó desde la landing',
    () {
      testWidgets(
        '?rol=cliente avisa «Ingresas como cliente» y destaca su registro',
        (tester) async {
          await _montar(tester, rol: 'cliente');

          expect(find.byKey(const Key('login-aviso-rol')), findsOneWidget);
          expect(find.text('Ingresas como cliente'), findsOneWidget);
          expect(_variante(tester, 'Soy cliente'), ManiButtonVariante.primario);
          expect(
            _variante(tester, 'Soy aliado'),
            ManiButtonVariante.secundario,
          );
        },
      );

      testWidgets(
        '?rol=aliado avisa «Ingresas como aliado técnico» y destaca su registro',
        (tester) async {
          await _montar(tester, rol: 'aliado');

          expect(find.text('Ingresas como aliado técnico'), findsOneWidget);
          expect(_variante(tester, 'Soy aliado'), ManiButtonVariante.primario);
          expect(
            _variante(tester, 'Soy cliente'),
            ManiButtonVariante.secundario,
          );
        },
      );

      testWidgets('el rol se normaliza: " Cliente " vale como cliente', (
        tester,
      ) async {
        await _montar(tester, rol: ' Cliente ');

        expect(find.text('Ingresas como cliente'), findsOneWidget);
      });

      testWidgets(
        'sin rol, o con uno que no es de entrada, el login es el de siempre',
        (tester) async {
          for (final rol in <String?>[
            null,
            '',
            'admin',
            'ADMIN_TENANT',
            'plataforma',
            'cliente&x=1',
          ]) {
            await _montar(tester, rol: rol);

            expect(
              find.byKey(const Key('login-aviso-rol')),
              findsNothing,
              reason: 'rol $rol',
            );
            expect(
              _variante(tester, 'Soy cliente'),
              ManiButtonVariante.secundario,
              reason: 'rol $rol',
            );
            expect(
              _variante(tester, 'Soy aliado'),
              ManiButtonVariante.secundario,
              reason: 'rol $rol',
            );
          }
        },
      );

      testWidgets('el aviso cabe en celular y en escritorio sin desbordar', (
        tester,
      ) async {
        for (final ancho in [360.0, 768.0, 1440.0]) {
          await _montar(tester, rol: 'aliado', ancho: ancho);

          expect(
            find.byKey(const Key('login-aviso-rol')),
            findsOneWidget,
            reason: '$ancho px',
          );
          expect(tester.takeException(), isNull, reason: '$ancho px');
        }
      });

      test('RolDeEntrada.desdeParametro solo reconoce cliente y aliado', () {
        expect(RolDeEntrada.desdeParametro('cliente'), RolDeEntrada.cliente);
        expect(RolDeEntrada.desdeParametro('ALIADO'), RolDeEntrada.aliado);
        expect(RolDeEntrada.desdeParametro('admin'), isNull);
        expect(RolDeEntrada.desdeParametro(null), isNull);
      });

      test('cada rol lleva a su registro', () {
        expect(RolDeEntrada.cliente.rutaRegistro, '/register-cliente');
        expect(RolDeEntrada.aliado.rutaRegistro, '/register-aliado');
      });
    },
  );
}
