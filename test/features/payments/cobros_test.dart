import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/widgets/refresco_periodico.dart';
import 'package:mani/features/payments/data/cobros_datasource.dart';
import 'package:mani/features/payments/domain/cobros.dart';
import 'package:mani/features/payments/domain/pago.dart';
import 'package:mani/features/payments/presentation/cobros_aliado_cubit.dart';
import 'package:mani/features/payments/presentation/cobros_aliado_page.dart';
import 'package:mani/features/payments/presentation/retencion_pago_card.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _cobro({
  String pagoId = 'pago-1',
  String estado = 'RETENIDA',
  Map<String, dynamic>? liquidacion,
}) => {
  'id': 'ret-1',
  'pagoId': pagoId,
  'solicitudId': 'sol-1',
  'monto': 150000.5,
  'moneda': 'COP',
  'estado': estado,
  'simulada': true,
  'creadaEn': '2026-11-03T10:00:00.000Z',
  'liberadaEn': estado == 'LIBERADA' ? '2026-11-03T12:00:00.000Z' : null,
  'liquidacion': liquidacion,
};

const _liq = {
  'id': 'liq-1',
  'montoBruto': 150000.5,
  'porcentajeComision': 10,
  'comision': 15000.05,
  'montoNeto': 135000.45,
};

class _FuenteFalsa implements FuenteCobros {
  _FuenteFalsa({this.cobros = const [], this.falla});

  List<CobroAliado> cobros;
  Object? falla;
  int llamadas = 0;

  @override
  Future<List<CobroAliado>> cobrosDelAliado() async {
    llamadas++;
    if (falla != null) throw falla!;
    return cobros;
  }

  @override
  Future<RetencionPago> retencion(String pagoId) async {
    llamadas++;
    if (falla != null) throw falla!;
    return cobros.first.retencion;
  }
}

/// SCRUM-891 a 894: la retención y los cobros salen por el Gateway hacia Core.
void main() {
  late List<http.Request> alGateway;
  late http.Response Function(http.Request) responder;

  GatewayFuenteCobros fuente() => GatewayFuenteCobros(
    GatewayClient(
      baseUrl: 'http://gateway.local',
      tokenProvider: () async => 'jwt-aliado',
      correlationId: () => 'corr-test',
      maxRetries: 0,
      httpClient: MockClient((r) async {
        alGateway.add(r);
        return responder(r);
      }),
    ),
  );

  setUp(() {
    alGateway = [];
    responder = (_) => http.Response(jsonEncode({}), 200, headers: _json);
  });

  group('GatewayFuenteCobros', () {
    test('lee los cobros del aliado: retención y liquidación', () async {
      responder = (_) => http.Response(
        jsonEncode({
          'cobros': [
            _cobro(estado: 'LIBERADA', liquidacion: _liq),
            _cobro(pagoId: 'pago-2'),
          ],
          'simulado': true,
        }),
        200,
        headers: _json,
      );

      final cobros = await fuente().cobrosDelAliado();

      expect(cobros, hasLength(2));
      expect(cobros.first.retencion.estado, EstadoRetencion.liberada);
      expect(cobros.first.retencion.liberadaEn, isNotNull);
      expect(cobros.first.liquidacion?.comision, 15000.05);
      expect(cobros.first.liquidacion?.montoNeto, 135000.45);
      expect(cobros.last.liquidacion, isNull);
      final r = alGateway.single;
      expect(r.method, 'GET');
      expect(r.url.toString(), 'http://gateway.local/api/v1/core/pagos/aliado');
      expect(r.headers['Authorization'], 'Bearer jwt-aliado');
    });

    test('lee la retención de un pago sin enviar cuerpo', () async {
      responder = (_) => http.Response(
        jsonEncode({'retencion': _cobro()}),
        200,
        headers: _json,
      );

      final r = await fuente().retencion('pago-1');

      expect(r.estado, EstadoRetencion.retenida);
      expect(r.simulada, isTrue);
      expect(r.monto, 150000.5);
      expect(alGateway.single.url.path, '/api/v1/core/pagos/pago-1/retencion');
      expect(alGateway.single.body, isEmpty);
    });

    test(
      'una respuesta sin la forma esperada es un fallo controlado',
      () async {
        responder = (_) =>
            http.Response(jsonEncode({'otra': 1}), 200, headers: _json);
        await expectLater(
          fuente().cobrosDelAliado(),
          throwsA(
            isA<PagoFailure>().having(
              (f) => f.tipo,
              'tipo',
              PagoErrorTipo.desconocido,
            ),
          ),
        );
        await expectLater(fuente().retencion('p'), throwsA(isA<PagoFailure>()));
      },
    );

    test('traduce 401, 403, 404 y 500 a un fallo de pago', () async {
      const esperados = {
        401: PagoErrorTipo.sinSesion,
        403: PagoErrorTipo.sinPermiso,
        404: PagoErrorTipo.noEncontrado,
        500: PagoErrorTipo.servicioNoDisponible,
      };
      for (final e in esperados.entries) {
        responder = (_) => http.Response(
          jsonEncode({'error': 'x', 'code': 'MANI-FON-404'}),
          e.key,
          headers: _json,
        );
        await expectLater(
          fuente().retencion('pago-1'),
          throwsA(isA<PagoFailure>().having((f) => f.tipo, 'tipo', e.value)),
          reason: '${e.key}',
        );
      }
    });
  });

  group('modelos', () {
    test('un estado desconocido no rompe y los números llegan como texto', () {
      final r = RetencionPago.fromJson({
        'pagoId': 'p',
        'monto': '100.5',
        'estado': 'OTRO',
      });
      expect(r.estado, EstadoRetencion.otro);
      expect(r.estado.etiqueta, 'Desconocido');
      expect(r.monto, 100.5);
      expect(r.moneda, 'COP');
      expect(r.simulada, isTrue);
    });
  });

  group('CobrosAliadoCubit y pantalla', () {
    Future<void> montar(WidgetTester tester, _FuenteFalsa f) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => CobrosAliadoCubit(f)..cargar(),
            child: const CobrosAliadoView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    CobroAliado cobro({bool liberado = false}) => CobroAliado.fromJson(
      _cobro(
        estado: liberado ? 'LIBERADA' : 'RETENIDA',
        liquidacion: liberado ? _liq : null,
      ),
    );

    testWidgets('sin cobros muestra el estado vacío y el aviso simulado', (
      tester,
    ) async {
      await montar(tester, _FuenteFalsa());
      expect(find.byKey(const Key('cobros-vacio')), findsOneWidget);
      expect(find.byKey(const Key('aviso-simulado-cobros')), findsOneWidget);
    });

    testWidgets('un cobro retenido dice que se liquida al finalizar', (
      tester,
    ) async {
      await montar(tester, _FuenteFalsa(cobros: [cobro()]));
      expect(find.text('Retenido en garantía'), findsOneWidget);
      expect(find.byKey(const Key('sin-liquidar')), findsOneWidget);
      expect(find.byKey(const Key('comision-pago-1')), findsNothing);
    });

    testWidgets('un cobro liberado muestra comisión y neto', (tester) async {
      await montar(tester, _FuenteFalsa(cobros: [cobro(liberado: true)]));
      expect(find.text('Liberado'), findsOneWidget);
      expect(find.byKey(const Key('comision-pago-1')), findsOneWidget);
      expect(find.byKey(const Key('neto-pago-1')), findsOneWidget);
      expect(find.textContaining('10 %'), findsOneWidget);
    });

    testWidgets('un fallo muestra el error y permite reintentar', (
      tester,
    ) async {
      final f = _FuenteFalsa(
        falla: const PagoFailure(PagoErrorTipo.sinConexion),
      );
      await montar(tester, f);
      expect(find.byKey(const Key('error-cobros')), findsOneWidget);

      f
        ..falla = null
        ..cobros = [cobro()];
      await tester.tap(find.byKey(const Key('reintentar-cobros')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('error-cobros')), findsNothing);
      expect(find.text('Retenido en garantía'), findsOneWidget);
    });

    testWidgets('la comisión con decimales se muestra con dos decimales', (
      tester,
    ) async {
      final c = CobroAliado.fromJson(
        _cobro(
          estado: 'LIBERADA',
          liquidacion: {..._liq, 'porcentajeComision': 12.5},
        ),
      );
      await montar(tester, _FuenteFalsa(cobros: [c]));
      expect(find.textContaining('12.50 %'), findsOneWidget);
    });
  });

  group('RetencionPagoCard', () {
    testWidgets('muestra el estado y avisa que es simulado', (tester) async {
      final f = _FuenteFalsa(cobros: [CobroAliado.fromJson(_cobro())]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetencionPagoCard(fuente: f, pagoId: 'pago-1'),
          ),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('estado-retencion')), findsOneWidget);
      expect(find.byKey(const Key('leyenda-retencion')), findsOneWidget);
    });

    testWidgets('si falla, lo dice sin romper la pantalla de pago', (
      tester,
    ) async {
      final f = _FuenteFalsa(
        cobros: [CobroAliado.fromJson(_cobro())],
        falla: const PagoFailure(PagoErrorTipo.noEncontrado),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetencionPagoCard(fuente: f, pagoId: 'pago-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sin-retencion')), findsOneWidget);
    });

    testWidgets('un error que no es de pago usa un mensaje genérico', (
      tester,
    ) async {
      final f = _FuenteFalsa(
        cobros: [CobroAliado.fromJson(_cobro())],
        falla: StateError('x'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetencionPagoCard(fuente: f, pagoId: 'pago-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No pudimos consultar la retención.'), findsOneWidget);
    });
  });

  group('SCRUM-1710 · sondeo de Mis cobros', () {
    test('la retención pasa a liquidación sin volver a cargando', () async {
      final f = _FuenteFalsa(cobros: [CobroAliado.fromJson(_cobro())]);
      final cubit = CobrosAliadoCubit(f);
      await cubit.cargar();
      final estados = <CobrosAliadoState>[];
      final sub = cubit.stream.listen(estados.add);

      f.cobros = [
        CobroAliado.fromJson(_cobro(estado: 'LIBERADA', liquidacion: _liq)),
      ];
      await cubit.cargar(silencioso: true);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.cobros.single, f.cobros.single);
      expect(estados.any((e) => e.fase == FaseCobros.cargando), isFalse);
      await sub.cancel();
      await cubit.close();
    });

    test('un fallo conserva los cobros y no muestra error', () async {
      final f = _FuenteFalsa(cobros: [CobroAliado.fromJson(_cobro())]);
      final cubit = CobrosAliadoCubit(f);
      await cubit.cargar();
      f.falla = const PagoFailure(PagoErrorTipo.servicioNoDisponible);

      await cubit.cargar(silencioso: true);

      expect(cubit.state.fase, FaseCobros.listo);
      expect(cubit.state.cobros, hasLength(1));
      await cubit.close();
    });

    test('no consulta mientras la primera carga sigue en curso', () async {
      final f = _FuenteFalsa();
      final cubit = CobrosAliadoCubit(f);

      await cubit.cargar(silencioso: true);

      expect(f.llamadas, 0);
      await cubit.close();
    });
  });

  group('SCRUM-1710 · pantalla de Mis cobros con sondeo', () {
    testWidgets('a los 20 s la retención aparece liberada sin recargar', (
      tester,
    ) async {
      final f = _FuenteFalsa(cobros: [CobroAliado.fromJson(_cobro())]);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => CobrosAliadoCubit(f)..cargar(),
            child: const CobrosAliadoView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retenido en garantía'), findsOneWidget);

      f.cobros = [
        CobroAliado.fromJson(_cobro(estado: 'LIBERADA', liquidacion: _liq)),
      ];
      await tester.pump(RefrescoPeriodico.intervaloPorDefecto);
      await tester.pumpAndSettle();

      expect(f.llamadas, 2);
      expect(find.text('Retenido en garantía'), findsNothing);
      expect(find.text('Liberado'), findsOneWidget);
    });
  });
}
