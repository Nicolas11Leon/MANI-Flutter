import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/features/services/additions/data/adiciones_datasource.dart';
import 'package:mani/features/services/additions/presentation/adiciones_cubit.dart';
import 'package:mani/features/services/additions/presentation/adiciones_seccion.dart';
import 'package:mani/features/services/quotes/domain/cotizacion.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _adicionJson(
  String id, {
  String estado = 'PENDIENTE',
  int? tiempo,
  String? comentario,
}) => {
  'id': id,
  'solicitudId': 'sol-1',
  'cotizacionId': 'cot-1',
  'motivo': 'Tubería rota detrás del muro',
  'valorManoObra': 100,
  'valorMateriales': '50.5',
  'total': 150.5,
  'tiempoAdicionalMinutos': tiempo,
  'estado': estado,
  'comentarioCliente': comentario,
};

const _resumenJson = {
  'cotizacionId': 'cot-1',
  'totalCotizacion': 1000,
  'totalAdicionesAceptadas': 0,
  'totalVigente': 1000,
  'topeAdiciones': 500,
  'disponibleParaAdiciones': 500,
};

AdicionesServicio _datos(
  List<Map<String, dynamic>> adiciones, {
  bool conResumen = true,
}) => AdicionesServicio(
  adiciones: adiciones.map(Adicion.fromJson).toList(),
  resumen: conResumen ? ResumenAdiciones.desde(_resumenJson) : null,
);

class _FuenteFake implements FuenteAdiciones {
  _FuenteFake(this.datos);

  AdicionesServicio datos;
  Object? falloListar;
  Object? falloAccion;
  bool falloListarTrasAccion = false;
  final llamadas = <String>[];
  Map<String, Object?>? ultimoPedido;
  String? ultimoComentario;

  @override
  Future<AdicionesServicio> listar(String solicitudId) async {
    llamadas.add('listar');
    if (falloListar != null) throw falloListar!;
    if (falloListarTrasAccion && llamadas.length > 2) {
      throw const CotizacionFailure(CotizacionErrorTipo.sinConexion);
    }
    return datos;
  }

  @override
  Future<void> solicitar(
    String solicitudId, {
    required String motivo,
    required String valorManoObra,
    required String valorMateriales,
    int? tiempoAdicionalMinutos,
  }) async {
    llamadas.add('solicitar');
    if (falloAccion != null) throw falloAccion!;
    ultimoPedido = {
      'motivo': motivo,
      'valorManoObra': valorManoObra,
      'valorMateriales': valorMateriales,
      'tiempoAdicionalMinutos': tiempoAdicionalMinutos,
    };
    datos = _datos([_adicionJson('adi-1')]);
  }

  @override
  Future<void> responder(
    String adicionId,
    DecisionAdicion decision, {
    String? comentario,
  }) async {
    llamadas.add('responder:${decision.ruta}');
    if (falloAccion != null) throw falloAccion!;
    ultimoComentario = comentario;
    datos = _datos([
      _adicionJson(
        adicionId,
        estado: decision == DecisionAdicion.aceptar ? 'ACEPTADA' : 'RECHAZADA',
      ),
    ]);
  }
}

/// Devuelve lo que había al consultar, pero tarda hasta que se abra [compuerta].
class _FuenteLenta extends _FuenteFake {
  _FuenteLenta(super.datos);

  Completer<void>? compuerta;

  @override
  Future<AdicionesServicio> listar(String solicitudId) async {
    final c = compuerta;
    final foto = await super.listar(solicitudId);
    if (c != null) await c.future;
    return foto;
  }
}

void main() {
  group('SCRUM-872 · fuente por el Gateway', () {
    late List<http.Request> peticiones;
    late http.Response Function(http.Request) responder;

    GatewayFuenteAdiciones fuente() => GatewayFuenteAdiciones(
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

    setUp(() => peticiones = []);

    test('GET lee las adiciones y el total vigente', () async {
      responder = (_) => http.Response(
        jsonEncode({
          'adiciones': [
            _adicionJson('adi-1', tiempo: 90, comentario: 'ok'),
            'basura',
          ],
          'resumen': _resumenJson,
        }),
        200,
        headers: _json,
      );
      final d = await fuente().listar('sol-1');
      expect(
        peticiones.single.url.path,
        '/api/v1/core/solicitudes/sol-1/adiciones',
      );
      expect(d.adiciones.single.valorMateriales, 50.5);
      expect(d.adiciones.single.tiempoAdicionalMinutos, 90);
      expect(d.adiciones.single.comentarioCliente, 'ok');
      expect(d.hayPendiente, isTrue);
      expect(d.resumen!.totalVigente, 1000);
      expect(d.resumen!.disponibleParaAdiciones, 500);
    });

    test('sin cotización aceptada el resumen es null; sin lista es un '
        'error', () async {
      responder = (_) => http.Response(
        jsonEncode({'adiciones': [], 'resumen': null}),
        200,
        headers: _json,
      );
      expect((await fuente().listar('sol-1')).resumen, isNull);

      responder = (_) => http.Response('{}', 200, headers: _json);
      await expectLater(
        fuente().listar('sol-1'),
        throwsA(isA<CotizacionFailure>()),
      );
    });

    test(
      'pedir envía los importes como texto y el tiempo solo si hay',
      () async {
        responder = (_) => http.Response('{"adicion":{}}', 201, headers: _json);
        final f = fuente();
        await f.solicitar(
          'sol-1',
          motivo: '  Tubería rota detrás del muro ',
          valorManoObra: '100.5',
          valorMateriales: '0',
          tiempoAdicionalMinutos: 60,
        );
        await f.solicitar(
          'sol-1',
          motivo: 'Tubería rota detrás del muro',
          valorManoObra: '10',
          valorMateriales: '0',
        );
        expect(
          peticiones.first.url.path,
          '/api/v1/core/solicitudes/sol-1/adiciones',
        );
        expect(jsonDecode(peticiones[0].body), {
          'motivo': 'Tubería rota detrás del muro',
          'valorManoObra': '100.5',
          'valorMateriales': '0',
          'tiempoAdicionalMinutos': 60,
        });
        expect(
          (jsonDecode(peticiones[1].body) as Map).containsKey(
            'tiempoAdicionalMinutos',
          ),
          isFalse,
        );
      },
    );

    test(
      'aceptar y rechazar van a su ruta con el comentario opcional',
      () async {
        responder = (_) => http.Response('{"adicion":{}}', 200, headers: _json);
        final f = fuente();
        await f.responder('adi-1', DecisionAdicion.aceptar);
        await f.responder(
          'adi-1',
          DecisionAdicion.rechazar,
          comentario: ' No pactado ',
        );
        expect(peticiones.map((p) => p.url.path), [
          '/api/v1/core/adiciones/adi-1/aceptar',
          '/api/v1/core/adiciones/adi-1/rechazar',
        ]);
        expect(jsonDecode(peticiones[0].body), <String, dynamic>{});
        expect(jsonDecode(peticiones[1].body), {'comentario': 'No pactado'});
      },
    );

    test('el tope de Core (400T) llega con su texto, sin el código', () async {
      responder = (_) => http.Response(
        jsonEncode({
          'error':
              'MANI-ADI-400T: la adición supera el tope: las adiciones aceptadas no pueden pasar del 50 %',
        }),
        400,
        headers: _json,
      );
      await expectLater(
        fuente().solicitar(
          'sol-1',
          motivo: 'Tubería rota detrás del muro',
          valorManoObra: '600',
          valorMateriales: '0',
        ),
        throwsA(
          isA<CotizacionFailure>().having(
            (f) => f.mensajeUsuario,
            'mensaje',
            startsWith('La adición supera el tope'),
          ),
        ),
      );
    });

    test('los errores de listar y responder se traducen igual', () async {
      responder = (_) => http.Response('{"error":"x"}', 404, headers: _json);
      await expectLater(
        fuente().listar('sol-1'),
        throwsA(
          isA<CotizacionFailure>().having(
            (f) => f.tipo,
            'tipo',
            CotizacionErrorTipo.noEncontrada,
          ),
        ),
      );
      responder = (_) => http.Response(
        '{"error":"MANI-ADI-409R: la adición ya fue decidida"}',
        409,
        headers: _json,
      );
      await expectLater(
        fuente().responder('adi-1', DecisionAdicion.aceptar),
        throwsA(
          isA<CotizacionFailure>().having(
            (f) => f.tipo,
            'tipo',
            CotizacionErrorTipo.conflicto,
          ),
        ),
      );
    });

    test('un estado desconocido no rompe la lectura', () {
      final a = Adicion.fromJson({'id': 'x', 'estado': 'OTRO', 'total': 'abc'});
      expect(a.estado, EstadoAdicion.desconocido);
      expect(a.total, 0);
      expect(ResumenAdiciones.desde('no-mapa'), isNull);
    });
  });

  group('SCRUM-872 · Cubit', () {
    test('cargar guarda los datos y un fallo deja el mensaje', () async {
      final f = _FuenteFake(_datos([]));
      final c = AdicionesCubit(f, 'sol-1');
      await c.cargar();
      expect(c.state.datos, isNotNull);

      f.falloListar = const CotizacionFailure(
        CotizacionErrorTipo.servicioNoDisponible,
      );
      await c.cargar();
      expect(c.state.error, contains('no está disponible'));
      expect(c.state.datos, isNotNull, reason: 'conserva lo que ya tenía');
      await c.close();
    });

    test(
      'pedir: éxito recarga; un fallo de Core avisa y devuelve false',
      () async {
        final f = _FuenteFake(_datos([]));
        final c = AdicionesCubit(f, 'sol-1');
        expect(
          await c.solicitar(
            motivo: 'Tubería rota detrás del muro',
            valorManoObra: '10',
            valorMateriales: '0',
          ),
          isTrue,
        );
        expect(c.state.datos!.hayPendiente, isTrue);
        expect(c.state.aviso, startsWith('Enviaste la adición'));

        f.falloAccion = const CotizacionFailure(
          CotizacionErrorTipo.conflicto,
          'Ya hay una adición pendiente',
        );
        expect(
          await c.solicitar(
            motivo: 'Otro imprevisto grande',
            valorManoObra: '10',
            valorMateriales: '0',
          ),
          isFalse,
        );
        expect(c.state.aviso, 'Ya hay una adición pendiente');
        expect(c.state.avisoEsError, isTrue);
        await c.close();
      },
    );

    test('si la acción se registró pero no se pudo recargar, no es un '
        'fallo', () async {
      final f = _FuenteFake(_datos([_adicionJson('adi-1')]))
        ..falloListarTrasAccion = true;
      final c = AdicionesCubit(f, 'sol-1');
      await c.cargar();
      expect(await c.responder('adi-1', DecisionAdicion.rechazar), isTrue);
      expect(c.state.aviso, contains('desliza para refrescar'));
      expect(c.state.avisoEsError, isFalse);
      await c.close();
    });

    test('no envía dos acciones a la vez', () async {
      final f = _FuenteFake(_datos([_adicionJson('adi-1')]));
      final c = AdicionesCubit(f, 'sol-1');
      final primera = c.responder('adi-1', DecisionAdicion.aceptar);
      expect(await c.responder('adi-1', DecisionAdicion.aceptar), isFalse);
      expect(await primera, isTrue);
      expect(f.llamadas.where((l) => l.startsWith('responder')).length, 1);
      await c.close();
    });

    test('SCRUM-1644: el sondeo silencioso trae la adición nueva sin cargando '
        'y un fallo no avisa', () async {
      final f = _FuenteFake(_datos([]));
      final c = AdicionesCubit(f, 'sol-1');
      await c.cargar();
      final estados = <AdicionesState>[];
      final sub = c.stream.listen(estados.add);

      f.datos = _datos([_adicionJson('adi-1')]);
      await c.cargar(silencioso: true);
      await Future<void>.delayed(Duration.zero);
      expect(c.state.datos!.hayPendiente, isTrue);
      expect(estados.any((e) => e.cargando), isFalse);

      f.falloListar = const CotizacionFailure(CotizacionErrorTipo.sinConexion);
      await c.cargar(silencioso: true);
      expect(c.state.datos!.hayPendiente, isTrue, reason: 'conserva lo visto');
      expect(c.state.error, isNull);
      expect(c.state.aviso, isNull);
      await sub.cancel();
      await c.close();
    });

    test('SCRUM-1644: el sondeo no consulta durante una acción', () async {
      final f = _FuenteFake(_datos([_adicionJson('adi-1')]));
      final c = AdicionesCubit(f, 'sol-1');
      await c.cargar();
      f.llamadas.clear();

      final accion = c.responder('adi-1', DecisionAdicion.aceptar);
      await c.cargar(silencioso: true);
      await accion;

      expect(f.llamadas, [
        'responder:${DecisionAdicion.aceptar.ruta}',
        'listar',
      ]);
      await c.close();
    });
  });

  group('SCRUM-872 · sección en la pantalla', () {
    Future<_FuenteFake> montar(
      WidgetTester tester,
      AdicionesServicio datos, {
      required bool esAliado,
      bool puedePedir = true,
      Object? falloListar,
    }) async {
      final f = _FuenteFake(datos)..falloListar = falloListar;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider(
                create: (_) => AdicionesCubit(f, 'sol-1')..cargar(),
                child: AdicionesSeccion(
                  esAliado: esAliado,
                  puedePedir: esAliado && puedePedir,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return f;
    }

    testWidgets('sin cotización aceptada ni adiciones no muestra nada', (
      tester,
    ) async {
      await montar(tester, _datos([], conResumen: false), esAliado: true);
      expect(find.byKey(const Key('seccion-adiciones')), findsNothing);
    });

    testWidgets('muestra el total vigente y el detalle de cada adición', (
      tester,
    ) async {
      await montar(
        tester,
        _datos([
          _adicionJson('adi-1', estado: 'RECHAZADA', comentario: 'No pactado'),
          _adicionJson('adi-2', estado: 'ACEPTADA', tiempo: 45),
        ]),
        esAliado: false,
      );
      expect(find.byKey(const Key('resumen-adiciones')), findsOneWidget);
      expect(find.text('Total vigente'), findsOneWidget);
      expect(find.text(r'$ 1.000,00'), findsWidgets);
      expect(find.textContaining('Rechazada'), findsOneWidget);
      expect(find.textContaining('No pactado'), findsOneWidget);
      expect(find.textContaining('45 min adicionales'), findsOneWidget);
      expect(find.byKey(const Key('btn-aceptar-adicion')), findsNothing);
    });

    testWidgets('un error al cargar ofrece reintentar', (tester) async {
      final f = await montar(
        tester,
        _datos([]),
        esAliado: false,
        falloListar: const CotizacionFailure(CotizacionErrorTipo.sinConexion),
      );
      expect(find.textContaining('Sin conexión'), findsOneWidget);
      f.falloListar = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resumen-adiciones')), findsOneWidget);
    });

    testWidgets('el aliado pide la adición: valida, envía y el formulario se '
        'cierra', (tester) async {
      final f = await montar(tester, _datos([]), esAliado: true);

      await tester.tap(find.byKey(const Key('btn-pedir-adicion')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('disponible-adicion'))).data,
        r'Disponible para adiciones: $ 500,00',
      );

      // Vacío: motivo corto e importes obligatorios.
      await tester.tap(find.byKey(const Key('btn-enviar-adicion')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Describe el imprevisto'), findsOneWidget);
      expect(find.text('Obligatorio (puede ser 0)'), findsNWidgets(2));
      expect(f.llamadas.contains('solicitar'), isFalse);

      await tester.enterText(
        find.byKey(const Key('campo-motivo-adicion')),
        'Tubería rota detrás del muro',
      );
      await tester.enterText(
        find.byKey(const Key('campo-mano-obra-adicion')),
        '0',
      );
      await tester.enterText(
        find.byKey(const Key('campo-materiales-adicion')),
        '0',
      );
      await tester.enterText(
        find.byKey(const Key('campo-tiempo-adicion')),
        '0',
      );
      await tester.tap(find.byKey(const Key('btn-enviar-adicion')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Minutos entre 1'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('campo-tiempo-adicion')), '');
      await tester.tap(find.byKey(const Key('btn-enviar-adicion')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('error-total-adicion')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('campo-mano-obra-adicion')),
        '100,5',
      );
      await tester.enterText(
        find.byKey(const Key('campo-tiempo-adicion')),
        '90',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(r'$ 100,50'), findsWidgets);
      await tester.tap(find.byKey(const Key('btn-enviar-adicion')));
      await tester.pumpAndSettle();

      expect(f.ultimoPedido, {
        'motivo': 'Tubería rota detrás del muro',
        'valorManoObra': '100.5',
        'valorMateriales': '0',
        'tiempoAdicionalMinutos': 90,
      });
      expect(find.byKey(const Key('btn-enviar-adicion')), findsNothing);
      expect(find.byKey(const Key('adicion-pendiente-aliado')), findsOneWidget);
      expect(find.byKey(const Key('btn-pedir-adicion')), findsNothing);
    });

    testWidgets('si Core rechaza el pedido el formulario sigue abierto con lo '
        'escrito', (tester) async {
      final f = await montar(tester, _datos([]), esAliado: true);
      f.falloAccion = const CotizacionFailure(
        CotizacionErrorTipo.datosInvalidos,
        'La adición supera el tope',
      );
      await tester.tap(find.byKey(const Key('btn-pedir-adicion')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('campo-motivo-adicion')),
        'Tubería rota detrás del muro',
      );
      await tester.enterText(
        find.byKey(const Key('campo-mano-obra-adicion')),
        '600',
      );
      await tester.enterText(
        find.byKey(const Key('campo-materiales-adicion')),
        '0',
      );
      await tester.tap(find.byKey(const Key('btn-enviar-adicion')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn-enviar-adicion')), findsOneWidget);
      expect(find.text('600'), findsOneWidget);
      expect(find.text('La adición supera el tope'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('btn-enviar-adicion')), findsNothing);
    });

    testWidgets('fuera de ejecución el aliado no ve el botón de pedir', (
      tester,
    ) async {
      await montar(tester, _datos([]), esAliado: true, puedePedir: false);
      expect(find.byKey(const Key('seccion-adiciones')), findsOneWidget);
      expect(find.byKey(const Key('btn-pedir-adicion')), findsNothing);
    });

    testWidgets('el cliente acepta con confirmación y rechaza con '
        'comentario', (tester) async {
      final f = await montar(
        tester,
        _datos([_adicionJson('adi-1')]),
        esAliado: false,
      );
      expect(find.textContaining('Pendiente de tu decisión'), findsOneWidget);

      // Cancelar no envía nada.
      await tester.tap(find.byKey(const Key('btn-aceptar-adicion')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Se sumarán'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(f.llamadas.any((l) => l.startsWith('responder')), isFalse);

      await tester.tap(find.byKey(const Key('btn-rechazar-adicion')));
      await tester.pumpAndSettle();
      expect(find.textContaining('sigue en ejecución'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('campo-comentario-adicion')),
        'No estaba pactado',
      );
      await tester.tap(find.byKey(const Key('btn-confirmar-decision-adicion')));
      await tester.pumpAndSettle();

      expect(f.llamadas, contains('responder:rechazar'));
      expect(f.ultimoComentario, 'No estaba pactado');
      expect(find.textContaining('Rechazaste la adición'), findsOneWidget);
      expect(find.byKey(const Key('btn-aceptar-adicion')), findsNothing);
    });

    testWidgets('el cliente acepta la adición pendiente', (tester) async {
      final f = await montar(
        tester,
        _datos([_adicionJson('adi-1')]),
        esAliado: false,
      );
      await tester.tap(find.byKey(const Key('btn-aceptar-adicion')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn-confirmar-decision-adicion')));
      await tester.pumpAndSettle();
      expect(f.llamadas, contains('responder:aceptar'));
      expect(find.textContaining('Aceptaste la adición'), findsOneWidget);
      expect(find.textContaining('Aceptada'), findsOneWidget);
    });

    testWidgets('el aliado ve su adición esperando al cliente', (tester) async {
      await montar(tester, _datos([_adicionJson('adi-1')]), esAliado: true);
      expect(
        find.textContaining('Esperando decisión del cliente'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('adicion-pendiente-aliado')), findsOneWidget);
    });
  });

  test('SCRUM-1644: una respuesta vieja del sondeo no pisa la decisión '
      'posterior', () async {
    final f = _FuenteLenta(_datos([_adicionJson('adi-1')]));
    final c = AdicionesCubit(f, 'sol-1');
    await c.cargar();
    expect(c.state.datos!.hayPendiente, isTrue);

    f.compuerta = Completer<void>();
    final sondeo = c.cargar(silencioso: true);
    final compuerta = f.compuerta!;
    f.compuerta = null;
    await c.responder('adi-1', DecisionAdicion.aceptar);
    expect(c.state.datos!.hayPendiente, isFalse);

    compuerta.complete();
    await sondeo;

    expect(c.state.datos!.hayPendiente, isFalse);
    await c.close();
  });
}
