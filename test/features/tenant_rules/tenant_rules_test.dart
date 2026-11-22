import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/network/gateway_exception.dart';
import 'package:mani/features/tenant_rules/data/tenant_rules_datasource.dart';
import 'package:mani/features/tenant_rules/domain/regla_tenant.dart';
import 'package:mani/features/tenant_rules/presentation/reglas_operativas_page.dart';
import 'package:mani/features/tenant_rules/presentation/tenant_rules_cubit.dart';

class MockFuenteReglasTenant implements FuenteReglasTenant {
  ReglaTenantVigente vigente = const ReglaTenantVigente(
    version: 0,
    origen: 'POR_OMISION',
    reglas: ReglasOperativas(
      criterioOrden: 'CALIFICACION',
      toleranciaTarifa: 10.0,
      comisionPorcentaje: 15.0,
      ventanaCancelacionHoras: 2.0,
      penalizacionCancelacion: 20.0,
      minutosParaAceptarOferta: 15,
    ),
  );

  List<ReglaTenantHistorialItem> historial = [];
  bool debeFallar = false;
  bool fallarHistorial = false;
  Exception? excepcionActualizar;
  Exception? excepcionCargar;

  @override
  Future<ReglaTenantVigente> getVigente() async {
    if (excepcionCargar != null) throw excepcionCargar!;
    if (debeFallar) throw Exception('Fallo de red simulado');
    return vigente;
  }

  @override
  Future<List<ReglaTenantHistorialItem>> getHistorial() async {
    if (fallarHistorial) throw Exception('Fallo de historial');
    if (debeFallar) throw Exception('Fallo de red simulado');
    return historial;
  }

  @override
  Future<ReglaTenantVigente> actualizar({
    required int expectedVersion,
    required ReglasOperativas reglas,
  }) async {
    if (excepcionActualizar != null) throw excepcionActualizar!;
    if (debeFallar) throw Exception('Error 409 o 503');
    vigente = ReglaTenantVigente(
      version: expectedVersion + 1,
      origen: 'PROPIO',
      estado: 'VIGENTE',
      reglas: reglas,
    );
    historial.insert(
      0,
      ReglaTenantHistorialItem(
        id: 'h1',
        version: vigente.version,
        estado: 'VIGENTE',
        reglas: reglas,
      ),
    );
    return vigente;
  }
}

void main() {
  group('TenantRules Domain & Cubit (SCRUM-1366)', () {
    test('ReglasOperativas serializa y deserializa correctamente', () {
      final json = {
        'ordenListado': {'criterio': 'COBERTURA'},
        'alertaTarifa': {'toleranciaPorcentaje': 25.0},
        'comision': {'porcentaje': 12.0},
        'cancelacion': {'ventanaHoras': 6.0, 'penalizacionPorcentaje': 30.0},
        'oferta': {'minutosParaAceptar': 45},
      };

      final reglas = ReglasOperativas.fromJson(json);
      expect(reglas.criterioOrden, 'COBERTURA');
      expect(reglas.toleranciaTarifa, 25.0);
      expect(reglas.comisionPorcentaje, 12.0);
      expect(reglas.ventanaCancelacionHoras, 6.0);
      expect(reglas.penalizacionCancelacion, 30.0);
      expect(reglas.minutosParaAceptarOferta, 45);

      final outJson = reglas.toJson();
      expect(outJson['ordenListado']['criterio'], 'COBERTURA');
      expect(outJson['alertaTarifa']['toleranciaPorcentaje'], 25.0);
    });

    test('TenantRulesCubit carga estado vigente e historial', () async {
      final fuente = MockFuenteReglasTenant();
      final cubit = TenantRulesCubit(fuente);

      await cubit.cargar();
      expect(cubit.state, isA<TenantRulesLoaded>());
      final loaded = cubit.state as TenantRulesLoaded;
      expect(loaded.vigente.version, 0);
      expect(loaded.vigente.origen, 'POR_OMISION');
    });

    test('TenantRulesCubit usa mensajeErrorGateway al fallar cargar', () async {
      final fuente = MockFuenteReglasTenant()
        ..excepcionCargar = const GatewayException(
          statusCode: 503,
          message: 'No disponible',
          cuerpo: {'code': 'RULES_SERVICE_UNAVAILABLE'},
        );
      final cubit = TenantRulesCubit(fuente);

      await cubit.cargar();
      expect(cubit.state, isA<TenantRulesError>());
      final errorState = cubit.state as TenantRulesError;
      expect(
        errorState.mensaje,
        'El motor de reglas no está disponible en este momento. Inténtalo más tarde.',
      );
    });

    test('TenantRulesCubit guarda nueva versión y actualiza estado', () async {
      final fuente = MockFuenteReglasTenant();
      final cubit = TenantRulesCubit(fuente);

      await cubit.cargar();

      const nuevasReglas = ReglasOperativas(
        criterioOrden: 'COBERTURA',
        toleranciaTarifa: 20.0,
        comisionPorcentaje: 10.0,
        ventanaCancelacionHoras: 4.0,
        penalizacionCancelacion: 15.0,
        minutosParaAceptarOferta: 30,
      );

      final ok = await cubit.guardar(nuevasReglas);
      expect(ok, isTrue);

      final loaded = cubit.state as TenantRulesLoaded;
      expect(loaded.vigente.version, 1);
      expect(loaded.vigente.origen, 'PROPIO');
      expect(loaded.vigente.reglas.criterioOrden, 'COBERTURA');
      expect(loaded.mensajeExito, contains('versión 1'));
    });

    test(
      'TenantRulesCubit reporta guardado exitoso aun si getHistorial falla',
      () async {
        final fuente = MockFuenteReglasTenant();
        final cubit = TenantRulesCubit(fuente);
        await cubit.cargar();

        fuente.fallarHistorial = true;
        const nuevasReglas = ReglasOperativas(
          criterioOrden: 'COBERTURA',
          toleranciaTarifa: 20.0,
          comisionPorcentaje: 10.0,
          ventanaCancelacionHoras: 4.0,
          penalizacionCancelacion: 15.0,
          minutosParaAceptarOferta: 30,
        );

        final ok = await cubit.guardar(nuevasReglas);
        expect(ok, isTrue);
        final loaded = cubit.state as TenantRulesLoaded;
        expect(loaded.vigente.version, 1);
        expect(loaded.mensajeExito, contains('versión 1'));
        expect(loaded.mensajeError, isNull);
      },
    );

    test(
      'TenantRulesCubit recarga versión vigente tras un 409 y limpia mensaje crudo',
      () async {
        final fuente = MockFuenteReglasTenant();
        final cubit = TenantRulesCubit(fuente);
        await cubit.cargar();

        // Simulamos que en el backend ya existe una versión 2
        fuente.vigente = const ReglaTenantVigente(
          version: 2,
          origen: 'PROPIO',
          reglas: ReglasOperativas(
            criterioOrden: 'COBERTURA',
            toleranciaTarifa: 15.0,
            comisionPorcentaje: 15.0,
            ventanaCancelacionHoras: 2.0,
            penalizacionCancelacion: 20.0,
            minutosParaAceptarOferta: 15,
          ),
        );

        fuente.excepcionActualizar = const GatewayException(
          statusCode: 409,
          message: 'Conflicto',
          cuerpo: {'error': 'MANI-TEN-409: La versión no coincide.'},
        );

        const nuevasReglas = ReglasOperativas(
          criterioOrden: 'COBERTURA',
          toleranciaTarifa: 20.0,
          comisionPorcentaje: 10.0,
          ventanaCancelacionHoras: 4.0,
          penalizacionCancelacion: 15.0,
          minutosParaAceptarOferta: 30,
        );

        final ok = await cubit.guardar(nuevasReglas);
        expect(ok, isFalse);
        final loaded = cubit.state as TenantRulesLoaded;
        expect(loaded.vigente.version, 2);
        expect(loaded.mensajeError, 'La versión no coincide.');
      },
    );
  });

  group('ReglasOperativasPage UI Widget test', () {
    testWidgets('Renderiza formulario y permite presionar botón guardar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fuente = MockFuenteReglasTenant();
      final cubit = TenantRulesCubit(fuente);
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

      expect(find.text('Reglas de operación'), findsOneWidget);
      expect(find.text('VERSIÓN 0 (POR OMISIÓN)'), findsOneWidget);
      expect(find.byKey(const Key('btn_guardar_reglas')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('btn_guardar_reglas')));
      await tester.tap(find.byKey(const Key('btn_guardar_reglas')));
      await tester.pumpAndSettle();

      expect(find.text('VERSIÓN VIGENTE 1'), findsOneWidget);
    });
  });
}
