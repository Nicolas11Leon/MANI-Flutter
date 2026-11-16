import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/features/services/execution/data/ejecucion_datasource.dart';
import 'package:mani/features/services/execution/presentation/ejecucion_cubit.dart';
import 'package:mani/features/services/execution/presentation/ejecucion_seccion.dart';
import 'package:mani/features/services/quotes/domain/cotizacion.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _ejecucionJson(
  String estado, {
  bool inicio = false,
  bool fin = false,
}) => {
  'solicitudId': 'sol-1',
  'estado': estado,
  'inicio': inicio
      ? {'registradoEn': '2026-10-27T15:00:00Z', 'observacion': 'Llegué'}
      : null,
  'fin': fin
      ? {'registradoEn': '2026-10-27T17:30:00Z', 'observacion': null}
      : null,
};

class _FuenteFake implements FuenteEjecucion {
  _FuenteFake(this.estado);

  String estado;
  Object? falloMarcar;
  Object? falloConsultar;
  final llamadas = <String>[];

  @override
  Future<Ejecucion> consultar(String solicitudId) async {
    llamadas.add('consultar');
    if (falloConsultar != null) throw falloConsultar!;
    return Ejecucion.fromJson(
      _ejecucionJson(
        estado,
        inicio: estado == 'EN_EJECUCION' || estado == 'FINALIZADA',
        fin: estado == 'FINALIZADA',
      ),
    );
  }

  @override
  Future<void> marcar(
    String solicitudId,
    HitoEjecucion hito, {
    String? observacion,
  }) async {
    llamadas.add('marcar:${hito.ruta}');
    if (falloMarcar != null) throw falloMarcar!;
    estado = hito == HitoEjecucion.inicio ? 'EN_EJECUCION' : 'FINALIZADA';
  }
}

/// Devuelve lo que había al consultar, pero tarda hasta que se abra [compuerta].
class _FuenteLenta extends _FuenteFake {
  _FuenteLenta(super.estado);

  Completer<void>? compuerta;

  @override
  Future<Ejecucion> consultar(String solicitudId) async {
    final c = compuerta;
    final foto = await super.consultar(solicitudId);
    if (c != null) await c.future;
    return foto;
  }
}

void main() {
  group('SCRUM-868 · fuente por el Gateway', () {
    late List<http.Request> peticiones;
    late http.Response Function(http.Request) responder;

    GatewayFuenteEjecucion fuente() => GatewayFuenteEjecucion(
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

    test(
      'GET /solicitudes/{id}/ejecucion lee las dos marcas con la hora del servidor',
      () async {
        responder = (_) => http.Response(
          jsonEncode({
            'ejecucion': _ejecucionJson('FINALIZADA', inicio: true, fin: true),
          }),
          200,
          headers: _json,
        );
        final e = await fuente().consultar('sol-1');
        expect(
          peticiones.single.url.path,
          '/api/v1/core/solicitudes/sol-1/ejecucion',
        );
        expect(e.finalizada, isTrue);
        expect(
          e.inicio!.registradoEn,
          DateTime.utc(2026, 10, 27, 15).toLocal(),
        );
        expect(e.inicio!.observacion, 'Llegué');
        expect(e.fin!.observacion, isNull);
      },
    );

    test('iniciar y finalizar van a su ruta y no envían fechas', () async {
      responder = (_) => http.Response('{"solicitud":{}}', 200, headers: _json);
      final f = fuente();
      await f.marcar('sol-1', HitoEjecucion.inicio, observacion: ' Llegué ');
      await f.marcar('sol-1', HitoEjecucion.fin);
      expect(peticiones.map((p) => p.url.path), [
        '/api/v1/core/solicitudes/sol-1/iniciar',
        '/api/v1/core/solicitudes/sol-1/finalizar',
      ]);
      expect(jsonDecode(peticiones[0].body), {'observacion': 'Llegué'});
      expect(jsonDecode(peticiones[1].body), <String, dynamic>{});
    });

    test('un 409 de Core llega con su texto, sin el código', () async {
      responder = (_) => http.Response(
        jsonEncode({
          'error':
              'MANI-EJE-409N: no se puede finalizar un servicio que no ha iniciado',
        }),
        409,
        headers: _json,
      );
      await expectLater(
        fuente().marcar('sol-1', HitoEjecucion.fin),
        throwsA(
          isA<CotizacionFailure>().having(
            (f) => f.mensajeUsuario,
            'mensaje',
            'No se puede finalizar un servicio que no ha iniciado',
          ),
        ),
      );
    });
  });

  group('SCRUM-868 · sección en la pantalla', () {
    Future<_FuenteFake> montar(
      WidgetTester tester,
      String estado, {
      required bool esAliado,
    }) async {
      final f = _FuenteFake(estado);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => EjecucionCubit(f, 'sol-1')..cargar(),
              child: EjecucionSeccion(esAliado: esAliado),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return f;
    }

    testWidgets(
      'el aliado inicia con la cotización aceptada y luego finaliza',
      (tester) async {
        final f = await montar(tester, 'ACEPTADA', esAliado: true);
        expect(find.text('Inicio: pendiente'), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn-iniciar-servicio')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Inicio: '), findsOneWidget);
        expect(find.text('Inicio: pendiente'), findsNothing);
        expect(find.byKey(const Key('btn-finalizar-servicio')), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn-finalizar-servicio')));
        await tester.pumpAndSettle();
        expect(find.text('Servicio finalizado.'), findsOneWidget);
        expect(f.llamadas.where((l) => l.startsWith('marcar')), [
          'marcar:iniciar',
          'marcar:finalizar',
        ]);
      },
    );

    testWidgets('con la cotización sin aceptar el aliado no ve «Iniciar»', (
      tester,
    ) async {
      await montar(tester, 'COTIZANDO', esAliado: true);
      expect(find.byKey(const Key('btn-iniciar-servicio')), findsNothing);
      expect(
        find.text('Podrás iniciar cuando el cliente acepte la cotización.'),
        findsOneWidget,
      );
    });

    testWidgets('el cliente ve las horas pero no los botones', (tester) async {
      await montar(tester, 'FINALIZADA', esAliado: false);
      expect(find.byKey(const Key('marca-inicio')), findsOneWidget);
      expect(find.textContaining('Llegué'), findsOneWidget);
      expect(find.text('Fin: pendiente'), findsNothing);
      expect(find.byKey(const Key('btn-iniciar-servicio')), findsNothing);
      expect(find.byKey(const Key('btn-finalizar-servicio')), findsNothing);
    });

    testWidgets('un 409 de Core se avisa y no cambia lo que se ve', (
      tester,
    ) async {
      final f = await montar(tester, 'ASIGNADA', esAliado: true);
      f.falloMarcar = const CotizacionFailure(
        CotizacionErrorTipo.conflicto,
        'La solicitud en estado ASIGNADA no puede iniciarse; necesita la cotización aceptada',
      );
      await tester.tap(find.byKey(const Key('btn-iniciar-servicio')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('necesita la cotización aceptada'),
        findsOneWidget,
      );
      expect(find.text('Inicio: pendiente'), findsOneWidget);
    });
  });

  test(
    'si la marca quedó pero falla la relectura, no se reporta como fallo',
    () async {
      final f = _FuenteFake('ACEPTADA');
      final cubit = EjecucionCubit(f, 'sol-1');
      await cubit.cargar();
      f.falloConsultar = const CotizacionFailure(
        CotizacionErrorTipo.servicioNoDisponible,
      );
      await cubit.marcar(HitoEjecucion.inicio);
      expect(cubit.state.avisoEsError, isFalse);
      expect(
        cubit.state.aviso,
        startsWith('Registraste el inicio del servicio.'),
      );
    },
  );

  group('SCRUM-1644 · sondeo silencioso', () {
    test('trae el estado nuevo sin pasar por cargando', () async {
      final f = _FuenteFake('ACEPTADA');
      final cubit = EjecucionCubit(f, 'sol-1');
      await cubit.cargar();
      final estados = <EjecucionState>[];
      final sub = cubit.stream.listen(estados.add);

      f.estado = 'EN_EJECUCION';
      await cubit.cargar(silencioso: true);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.ejecucion?.enEjecucion, isTrue);
      expect(estados.any((e) => e.cargando), isFalse);
      await sub.cancel();
      await cubit.close();
    });

    test('un fallo conserva lo que se ve y no muestra error', () async {
      final f = _FuenteFake('ACEPTADA');
      final cubit = EjecucionCubit(f, 'sol-1');
      await cubit.cargar();
      f.falloConsultar = const CotizacionFailure(
        CotizacionErrorTipo.sinConexion,
      );

      await cubit.cargar(silencioso: true);

      expect(cubit.state.ejecucion, isNotNull);
      expect(cubit.state.error, isNull);
      expect(cubit.state.aviso, isNull);
      await cubit.close();
    });

    test('no consulta mientras se registra una marca', () async {
      final f = _FuenteFake('ACEPTADA');
      final cubit = EjecucionCubit(f, 'sol-1');
      await cubit.cargar();
      f.llamadas.clear();

      final marca = cubit.marcar(HitoEjecucion.inicio);
      await cubit.cargar(silencioso: true);
      await marca;

      expect(f.llamadas, ['marcar:${HitoEjecucion.inicio.ruta}', 'consultar']);
      await cubit.close();
    });
  });

  test('SCRUM-1644: una respuesta vieja del sondeo no pisa la marca '
      'posterior', () async {
    final f = _FuenteLenta('ACEPTADA');
    final cubit = EjecucionCubit(f, 'sol-1');
    await cubit.cargar();

    f.compuerta = Completer<void>();
    final sondeo = cubit.cargar(silencioso: true);
    final compuerta = f.compuerta!;
    f.compuerta = null;
    await cubit.marcar(HitoEjecucion.inicio);
    expect(cubit.state.ejecucion?.enEjecucion, isTrue);

    compuerta.complete();
    await sondeo;

    expect(cubit.state.ejecucion?.enEjecucion, isTrue);
    await cubit.close();
  });
}
