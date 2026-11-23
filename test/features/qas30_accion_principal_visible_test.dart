import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:mani/features/auth/domain/usecases/login_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_aliado_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_cliente_empresa_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_cliente_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_empresa_usecase.dart';
import 'package:mani/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:mani/features/auth/presentation/pages/registro_aliado_empresa_page.dart';
import 'package:mani/features/auth/presentation/pages/registro_aliado_page.dart';
import 'package:mani/features/auth/presentation/pages/registro_cliente_page.dart';
import 'package:mani/features/tenant_rules/presentation/reglas_operativas_page.dart';
import 'package:mani/features/tenant_rules/presentation/tenant_rules_cubit.dart';

import 'tenant_rules/tenant_rules_test.dart' show MockFuenteReglasTenant;

class _Repo implements IAuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

AuthCubit _authCubit() {
  final repo = _Repo();
  return AuthCubit(
    loginUseCase: LoginUseCase(repo),
    registerClienteUseCase: RegisterClienteUseCase(repo),
    registerAliadoUseCase: RegisterAliadoUseCase(repo),
    registerEmpresaUseCase: RegisterEmpresaUseCase(repo),
    registerClienteEmpresaUseCase: RegisterClienteEmpresaUseCase(repo),
  );
}

/// QAS-30 (SCRUM-1717): la acción principal se ve en la primera pantalla, sin desplazarse. La prueba heurística T-45
/// la encontró bajo el pliegue en reglas del tenant y en los registros; aquí se comprueba, sin tocar el desplazamiento,
/// que el botón queda completo dentro de la ventana en escritorio pequeño (800x600, el tamaño de T-45) y en celular.
void main() {
  const tamanos = <String, Size>{
    'escritorio 800x600': Size(800, 600),
    'celular 390x844': Size(390, 844),
  };

  Future<void> fijarVentana(WidgetTester tester, Size tamano) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Los formularios largos desbordan con la tipografía de las pruebas; aquí solo importa dónde queda el botón.
    final original = FlutterError.onError;
    FlutterError.onError = (detalles) {
      if (!detalles.toString().contains('overflowed')) original?.call(detalles);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  void esperarVisibleSinDesplazar(
    WidgetTester tester,
    Finder boton,
    Size tamano,
  ) {
    expect(boton, findsOneWidget);
    final rect = tester.getRect(boton);
    expect(
      rect.top,
      greaterThanOrEqualTo(0),
      reason: 'el botón empieza dentro de la ventana',
    );
    expect(
      rect.bottom,
      lessThanOrEqualTo(tamano.height),
      reason:
          'el botón termina dentro de la ventana (no queda bajo el pliegue)',
    );
    expect(tester.widget<ManiButton>(boton).onPressed, isNotNull);
  }

  group('Registros', () {
    setUp(() {
      dotenv.testLoad(fileInput: 'TENANT_SLUG=plomeria-express');
      sl.registerFactory<AuthCubit>(_authCubit);
    });
    tearDown(() async => GetIt.instance.reset());

    final registros = <String, (Widget Function(), String)>{
      'registro de cliente': (
        () => const RegistroClientePage(),
        'CREAR MI CUENTA DE CLIENTE',
      ),
      'registro de aliado': (
        () => const RegistroAliadoPage(),
        'ENVIAR REGISTRO A REVISIÓN',
      ),
      'registro de empresa aliada': (
        () => const RegistroAliadoEmpresaPage(),
        'ENVIAR REGISTRO DE EMPRESA A REVISIÓN',
      ),
    };

    for (final r in registros.entries) {
      for (final t in tamanos.entries) {
        testWidgets(
          '${r.key}, ${t.key}: el botón de envío se ve sin desplazarse',
          (tester) async {
            await fijarVentana(tester, t.value);
            await tester.pumpWidget(MaterialApp(home: r.value.$1()));
            await tester.pump();

            final boton = find.ancestor(
              of: find.text(r.value.$2),
              matching: find.byType(ManiButton),
            );
            esperarVisibleSinDesplazar(tester, boton, t.value);
          },
        );
      }
    }
  });

  group('Reglas del tenant', () {
    for (final t in tamanos.entries) {
      testWidgets(
        '${t.key}: «Guardar nueva versión» se ve sin desplazarse y guarda',
        (tester) async {
          await fijarVentana(tester, t.value);
          final cubit = TenantRulesCubit(MockFuenteReglasTenant());
          await cubit.cargar();

          await tester.pumpWidget(
            MaterialApp(
              home: BlocProvider.value(
                value: cubit,
                child: const ReglasOperativasPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final boton = find.byKey(const Key('btn_guardar_reglas'));
          esperarVisibleSinDesplazar(tester, boton, t.value);

          // Se toca donde está, sin ensureVisible: si quedara bajo el pliegue, el toque no llegaría.
          await tester.tap(boton);
          await tester.pumpAndSettle();
          expect(find.text('VERSIÓN VIGENTE 1'), findsOneWidget);
        },
      );
    }

    testWidgets('mientras carga no muestra la franja de guardar', (
      tester,
    ) async {
      await fijarVentana(tester, const Size(800, 600));
      final cubit = TenantRulesCubit(MockFuenteReglasTenant());

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const ReglasOperativasPage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('btn_guardar_reglas')), findsNothing);
    });
  });
}
