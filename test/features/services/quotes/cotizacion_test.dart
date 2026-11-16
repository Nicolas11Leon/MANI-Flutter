import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/features/services/quotes/data/cotizaciones_datasource.dart';
import 'package:mani/features/services/quotes/domain/cotizacion.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_cubit.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _cotJson({
  String id = 'cot-1',
  int version = 1,
  String estado = 'PENDIENTE',
  Object manoObra = 120000,
  Object materiales = 35500.5,
  Object total = 155500.5,
}) => {
  'id': id,
  'solicitudId': 'sol-1',
  'version': version,
  'estado': estado,
  'valorManoObra': manoObra,
  'valorMateriales': materiales,
  'total': total,
  'creadaEn': '2026-10-27T01:00:00Z',
};

Cotizacion _cot({int version = 1, String estado = 'PENDIENTE'}) =>
    Cotizacion.fromJson(
      _cotJson(id: 'cot-$version', version: version, estado: estado),
    );

/// Fuente en memoria: registra las llamadas y responde lo que se le indique.
class _FuenteFake implements FuenteCotizaciones {
  List<Cotizacion> lista = [];
  Object? falloListar;
  Object? falloAccion;
  final llamadas = <String>[];

  @override
  Future<List<Cotizacion>> listar(String solicitudId) async {
    llamadas.add('listar:$solicitudId');
    if (falloListar != null) throw falloListar!;
    return lista;
  }

  @override
  Future<Cotizacion> emitir(
    String solicitudId, {
    required String valorManoObra,
    required String valorMateriales,
  }) async {
    llamadas.add('emitir:$solicitudId:$valorManoObra:$valorMateriales');
    if (falloAccion != null) throw falloAccion!;
    final c = _cot(version: lista.length + 1);
    lista = [c, ...lista];
    return c;
  }

  @override
  Future<Cotizacion> responder(
    String cotizacionId,
    DecisionCotizacion decision, {
    String? texto,
  }) async {
    llamadas.add('responder:$cotizacionId:${decision.ruta}:${texto ?? ''}');
    if (falloAccion != null) throw falloAccion!;
    final estado = switch (decision) {
      DecisionCotizacion.aceptar => 'ACEPTADA',
      DecisionCotizacion.rechazar => 'RECHAZADA',
      DecisionCotizacion.ajustar => 'AJUSTE_SOLICITADO',
    };
    final c = _cot(version: lista.first.version, estado: estado);
    lista = [c, ...lista.skip(1)];
    return c;
  }
}

/// Devuelve lo que había al consultar, pero tarda hasta que se abra [compuerta].
class _FuenteLenta extends _FuenteFake {
  Completer<void>? compuerta;

  @override
  Future<List<Cotizacion>> listar(String solicitudId) async {
    final c = compuerta;
    final foto = await super.listar(solicitudId);
    if (c != null) await c.future;
    return foto;
  }
}

void main() {
  group('Cotización · modelo', () {
    test('lee importes como número o texto y el estado de Core', () {
      final c = Cotizacion.fromJson(
        _cotJson(manoObra: '120000.00', materiales: 35500.5),
      );
      expect(c.valorManoObra, 120000);
      expect(c.valorMateriales, 35500.5);
      expect(c.total, 155500.5);
      expect(c.pendiente, isTrue);
      expect(c.etiquetaEstado, 'Pendiente de respuesta');
    });

    test('un estado desconocido se muestra como lo envía Core', () {
      final c = Cotizacion.fromJson(_cotJson(estado: 'NUEVO_ESTADO'));
      expect(c.estado, EstadoCotizacion.otro);
      expect(c.etiquetaEstado, 'NUEVO_ESTADO');
    });

    test('formatearPesos usa puntos de miles y coma decimal', () {
      expect(formatearPesos(1234567.5), '\$ 1.234.567,50');
      expect(formatearPesos(0), '\$ 0,00');
    });
  });

  group('Cotización · fuente por el Gateway', () {
    late List<http.Request> peticiones;
    late http.Response Function(http.Request) responder;

    GatewayFuenteCotizaciones fuente() => GatewayFuenteCotizaciones(
      GatewayClient(
        baseUrl: 'http://gateway.local',
        tokenProvider: () async => 'jwt',
        correlationId: () => 'corr',
        initialRetryDelay: Duration.zero,
        httpClient: MockClient((r) async {
          peticiones.add(r);
          return responder(r);
        }),
      ),
    );

    setUp(() {
      peticiones = [];
      responder = (_) => http.Response(
        jsonEncode({
          'cotizaciones': [_cotJson()],
        }),
        200,
        headers: _json,
      );
    });

    test('GET /api/v1/core/solicitudes/{id}/cotizaciones', () async {
      final lista = await fuente().listar('sol-1');
      expect(peticiones.single.method, 'GET');
      expect(
        peticiones.single.url.path,
        '/api/v1/core/solicitudes/sol-1/cotizaciones',
      );
      expect(lista.single.version, 1);
    });

    test('SCRUM-865: el aliado envía los importes como texto, sin ids '
        'de aliado ni tenant', () async {
      responder = (_) => http.Response(
        jsonEncode({'cotizacion': _cotJson()}),
        201,
        headers: _json,
      );
      await fuente().emitir(
        'sol-1',
        valorManoObra: '120000',
        valorMateriales: '35500.50',
      );
      final p = peticiones.single;
      expect(p.method, 'POST');
      expect(p.url.path, '/api/v1/core/solicitudes/sol-1/cotizaciones');
      expect(jsonDecode(p.body), {
        'valorManoObra': '120000',
        'valorMateriales': '35500.50',
      });
    });

    test('SCRUM-867: cada decisión va a su ruta; el rechazo envía «motivo» '
        'y el ajuste «comentario»', () async {
      responder = (_) => http.Response(
        jsonEncode({'cotizacion': _cotJson()}),
        200,
        headers: _json,
      );
      final f = fuente();
      await f.responder('cot-1', DecisionCotizacion.aceptar);
      await f.responder(
        'cot-1',
        DecisionCotizacion.rechazar,
        texto: ' Muy costosa ',
      );
      await f.responder(
        'cot-1',
        DecisionCotizacion.ajustar,
        texto: 'Bajar materiales',
      );
      expect(peticiones.map((p) => p.url.path), [
        '/api/v1/core/cotizaciones/cot-1/aceptar',
        '/api/v1/core/cotizaciones/cot-1/rechazar',
        '/api/v1/core/cotizaciones/cot-1/ajustar',
      ]);
      expect(jsonDecode(peticiones[0].body), <String, dynamic>{});
      expect(jsonDecode(peticiones[1].body), {'motivo': 'Muy costosa'});
      expect(jsonDecode(peticiones[2].body), {
        'comentario': 'Bajar materiales',
      });
    });

    test('un 409 conserva el texto de Core sin el código MANI-COT', () async {
      responder = (_) => http.Response(
        jsonEncode({
          'error':
              'MANI-COT-409R: la cotización ya fue respondida (estado ACEPTADA)',
          'code': 'MANI-COT-409R',
        }),
        409,
        headers: _json,
      );
      await expectLater(
        fuente().responder('cot-1', DecisionCotizacion.aceptar),
        throwsA(
          isA<CotizacionFailure>()
              .having((f) => f.tipo, 'tipo', CotizacionErrorTipo.conflicto)
              .having(
                (f) => f.mensajeUsuario,
                'mensaje',
                'La cotización ya fue respondida (estado ACEPTADA)',
              ),
        ),
      );
    });

    test('401, 403, 404, 503 y sin red tienen su propio tipo; nunca lista '
        'vacía', () async {
      final casos = {
        401: CotizacionErrorTipo.sinSesion,
        403: CotizacionErrorTipo.sinPermiso,
        404: CotizacionErrorTipo.noEncontrada,
        503: CotizacionErrorTipo.servicioNoDisponible,
      };
      for (final MapEntry(key: status, value: tipo) in casos.entries) {
        responder = (_) =>
            http.Response('{"error":"x"}', status, headers: _json);
        await expectLater(
          fuente().listar('sol-1'),
          throwsA(isA<CotizacionFailure>().having((f) => f.tipo, 'tipo', tipo)),
        );
      }
      final sinRed = GatewayFuenteCotizaciones(
        GatewayClient(
          baseUrl: 'http://gateway.local',
          tokenProvider: () async => 'jwt',
          correlationId: () => 'corr',
          initialRetryDelay: Duration.zero,
          maxRetries: 0,
          httpClient: MockClient((_) async => throw http.ClientException('x')),
        ),
      );
      await expectLater(
        sinRed.listar('sol-1'),
        throwsA(
          isA<CotizacionFailure>().having(
            (f) => f.tipo,
            'tipo',
            CotizacionErrorTipo.sinConexion,
          ),
        ),
      );
    });

    test('una respuesta sin la lista es un error', () async {
      responder = (_) => http.Response('{}', 200, headers: _json);
      await expectLater(
        fuente().listar('sol-1'),
        throwsA(isA<CotizacionFailure>()),
      );
    });
  });

  group('Cotización · cubit', () {
    test(
      'cargar trae las versiones; un fallo sin datos muestra el error',
      () async {
        final f = _FuenteFake()..lista = [_cot()];
        final cubit = CotizacionCubit(f, 'sol-1');
        await cubit.cargar();
        expect(cubit.state.vigente?.version, 1);

        final fallida = _FuenteFake()
          ..falloListar = const CotizacionFailure(
            CotizacionErrorTipo.sinConexion,
          );
        final c2 = CotizacionCubit(fallida, 'sol-1');
        await c2.cargar();
        expect(c2.state.error, contains('Sin conexión'));
      },
    );

    test('emitir envía los importes y relee la lista', () async {
      final f = _FuenteFake();
      final cubit = CotizacionCubit(f, 'sol-1');
      await cubit.emitir(valorManoObra: '100', valorMateriales: '0');
      expect(f.llamadas, ['emitir:sol-1:100:0', 'listar:sol-1']);
      expect(cubit.state.aviso, 'Cotización v1 enviada al cliente.');
      expect(cubit.state.avisoEsError, isFalse);
    });

    test('responder usa la versión vigente', () async {
      final f = _FuenteFake()..lista = [_cot(version: 2), _cot()];
      final cubit = CotizacionCubit(f, 'sol-1');
      await cubit.cargar();
      await cubit.responder(DecisionCotizacion.ajustar, texto: 'Bajar');
      expect(f.llamadas, contains('responder:cot-2:ajustar:Bajar'));
      expect(cubit.state.vigente?.estado, EstadoCotizacion.ajusteSolicitado);
    });

    test(
      'un fallo de la acción se avisa como error y conserva la lista',
      () async {
        final f = _FuenteFake()
          ..lista = [_cot()]
          ..falloAccion = const CotizacionFailure(
            CotizacionErrorTipo.conflicto,
            'La cotización ya fue respondida',
          );
        final cubit = CotizacionCubit(f, 'sol-1');
        await cubit.cargar();
        await cubit.responder(DecisionCotizacion.aceptar);
        expect(cubit.state.avisoEsError, isTrue);
        expect(cubit.state.aviso, 'La cotización ya fue respondida');
        expect(cubit.state.cotizaciones, hasLength(1));
        expect(cubit.state.enviando, isFalse);
      },
    );

    test('si la acción se registró pero falla la relectura, no se reporta '
        'como fallo', () async {
      final f = _FuenteFake()..lista = [_cot()];
      final cubit = CotizacionCubit(f, 'sol-1');
      await cubit.cargar();
      f.falloListar = const CotizacionFailure(
        CotizacionErrorTipo.servicioNoDisponible,
      );
      await cubit.responder(DecisionCotizacion.aceptar);
      expect(cubit.state.avisoEsError, isFalse);
      expect(cubit.state.aviso, startsWith('Aceptaste la cotización.'));
      expect(cubit.state.vigente?.estado, EstadoCotizacion.aceptada);
    });

    test('SCRUM-1644: el sondeo silencioso trae la versión nueva sin pasar '
        'por cargando', () async {
      final f = _FuenteFake()..lista = [_cot()];
      final cubit = CotizacionCubit(f, 'sol-1');
      await cubit.cargar();
      final estados = <CotizacionState>[];
      final sub = cubit.stream.listen(estados.add);

      f.lista = [_cot(version: 2), _cot()];
      await cubit.cargar(silencioso: true);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.vigente?.version, 2);
      expect(estados.any((e) => e.cargando), isFalse);
      await sub.cancel();
      await cubit.close();
    });

    test(
      'SCRUM-1644: un sondeo fallido conserva la lista y no avisa',
      () async {
        final f = _FuenteFake()..lista = [_cot()];
        final cubit = CotizacionCubit(f, 'sol-1');
        await cubit.cargar();
        f.falloListar = const CotizacionFailure(
          CotizacionErrorTipo.sinConexion,
        );

        await cubit.cargar(silencioso: true);

        expect(cubit.state.cotizaciones, hasLength(1));
        expect(cubit.state.aviso, isNull);
        expect(cubit.state.error, isNull);
        await cubit.close();
      },
    );

    test(
      'SCRUM-1644: el sondeo no consulta ni pisa una acción en curso',
      () async {
        final f = _FuenteFake()..lista = [_cot()];
        final cubit = CotizacionCubit(f, 'sol-1');
        await cubit.cargar();
        f.llamadas.clear();

        final accion = cubit.responder(DecisionCotizacion.aceptar);
        await cubit.cargar(silencioso: true);
        await accion;

        expect(f.llamadas.where((l) => l.startsWith('listar')), hasLength(1));
        expect(cubit.state.aviso, startsWith('Aceptaste la cotización.'));
        await cubit.close();
      },
    );
  });

  group('Cotización · pantalla', () {
    Future<_FuenteFake> montar(
      WidgetTester tester, {
      required bool esAliado,
      List<Cotizacion> lista = const [],
    }) async {
      final f = _FuenteFake()..lista = lista;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => CotizacionCubit(f, 'sol-1')..cargar(),
              child: CotizacionPage(esAliado: esAliado),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return f;
    }

    testWidgets('SCRUM-865: el aliado ve el total mientras escribe y envía '
        'los dos renglones', (tester) async {
      final f = await montar(tester, esAliado: true);

      await tester.enterText(
        find.byKey(const Key('campo-mano-obra')),
        '120000',
      );
      await tester.enterText(
        find.byKey(const Key('campo-materiales')),
        '35500,5',
      );
      await tester.pump();
      expect(find.text('Total: \$ 155.500,50'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-enviar-cotizacion')));
      await tester.pumpAndSettle();
      expect(f.llamadas, contains('emitir:sol-1:120000:35500.5'));
      expect(find.byKey(const Key('cotizacion-v1')), findsOneWidget);
      expect(find.byKey(const Key('estado-cotizacion-aliado')), findsOneWidget);
    });

    testWidgets('SCRUM-865: importes inválidos o total en cero no se envían', (
      tester,
    ) async {
      final f = await montar(tester, esAliado: true);

      await tester.enterText(
        find.byKey(const Key('campo-mano-obra')),
        '10.555',
      );
      await tester.tap(find.byKey(const Key('btn-enviar-cotizacion')));
      await tester.pump();
      expect(
        find.text('Valor no negativo con máximo dos decimales'),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const Key('campo-mano-obra')), '0');
      await tester.tap(find.byKey(const Key('btn-enviar-cotizacion')));
      await tester.pump();
      expect(find.text('El total debe ser mayor que cero'), findsOneWidget);
      expect(f.llamadas.where((l) => l.startsWith('emitir')), isEmpty);
    });

    testWidgets('SCRUM-865: con ajuste solicitado el aliado puede enviar la '
        'siguiente versión', (tester) async {
      await montar(
        tester,
        esAliado: true,
        lista: [_cot(estado: 'AJUSTE_SOLICITADO')],
      );
      expect(
        find.textContaining('El cliente pidió un ajuste: envía la versión 2'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('btn-enviar-cotizacion')), findsOneWidget);
    });

    testWidgets('SCRUM-867: el cliente acepta la cotización pendiente', (
      tester,
    ) async {
      final f = await montar(tester, esAliado: false, lista: [_cot()]);

      expect(find.text('\$ 155.500,50'), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn-aceptar-cotizacion')));
      await tester.pumpAndSettle();
      expect(f.llamadas, contains('responder:cot-1:aceptar:'));
      expect(find.text('Aceptaste esta cotización.'), findsOneWidget);
    });

    testWidgets('SCRUM-867: rechazar exige un motivo de 5 caracteres', (
      tester,
    ) async {
      final f = await montar(tester, esAliado: false, lista: [_cot()]);

      await tester.tap(find.byKey(const Key('btn-rechazar-cotizacion')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('campo-texto-decision')),
        'no',
      );
      await tester.pump();
      final confirmar = tester.widget<FilledButton>(
        find.byKey(const Key('btn-confirmar-decision')),
      );
      expect(confirmar.onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('campo-texto-decision')),
        'Muy costosa',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn-confirmar-decision')));
      await tester.pumpAndSettle();
      expect(f.llamadas, contains('responder:cot-1:rechazar:Muy costosa'));
      expect(find.text('Rechazaste esta cotización.'), findsOneWidget);
    });

    testWidgets('SCRUM-867: pedir ajuste muestra el historial de versiones', (
      tester,
    ) async {
      final f = await montar(
        tester,
        esAliado: false,
        lista: [
          _cot(version: 2),
          _cot(estado: 'AJUSTE_SOLICITADO'),
        ],
      );

      expect(find.text('Versiones anteriores'), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn-ajustar-cotizacion')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('campo-texto-decision')),
        'Bajar materiales',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn-confirmar-decision')));
      await tester.pumpAndSettle();
      expect(f.llamadas, contains('responder:cot-2:ajustar:Bajar materiales'));
    });

    testWidgets('sin cotización el cliente ve que el aliado aún no la envía', (
      tester,
    ) async {
      await montar(tester, esAliado: false);
      expect(find.byKey(const Key('sin-cotizacion')), findsOneWidget);
      expect(find.byKey(const Key('btn-aceptar-cotizacion')), findsNothing);
    });

    testWidgets('un error de carga se muestra con «Reintentar»', (
      tester,
    ) async {
      final f = _FuenteFake()
        ..falloListar = const CotizacionFailure(
          CotizacionErrorTipo.servicioNoDisponible,
        );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => CotizacionCubit(f, 'sol-1')..cargar(),
              child: const CotizacionPage(esAliado: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('error-cotizacion')), findsOneWidget);
      f.falloListar = null;
      f.lista = [_cot()];
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cotizacion-v1')), findsOneWidget);
    });
  });

  test('SCRUM-1644: una respuesta vieja del sondeo no pisa lo que dejó una '
      'acción posterior', () async {
    final f = _FuenteLenta()..lista = [_cot()];
    final cubit = CotizacionCubit(f, 'sol-1');
    await cubit.cargar();

    f.compuerta = Completer<void>();
    final sondeo = cubit.cargar(silencioso: true);
    final compuerta = f.compuerta!;
    f.compuerta = null;
    await cubit.responder(DecisionCotizacion.aceptar);
    expect(cubit.state.vigente?.estado, EstadoCotizacion.aceptada);

    compuerta.complete();
    await sondeo;

    expect(cubit.state.vigente?.estado, EstadoCotizacion.aceptada);
    await cubit.close();
  });
}
