import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/widgets/refresco_periodico.dart';
import 'package:mani/features/services/tracking/data/seguimiento_datasource.dart';
import 'package:mani/features/services/tracking/domain/solicitud_seguimiento.dart';
import 'package:mani/features/services/tracking/presentation/mis_solicitudes_cubit.dart';
import 'package:mani/features/services/tracking/presentation/mis_solicitudes_page.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _solicitudJson({
  String id = 'sol-1',
  String estado = 'PENDIENTE',
}) => {
  'id': id,
  'estado': estado,
  'categoria': 'Plomería',
  'zonaDeclarada': {'nombre': 'Chapinero', 'zonaPadre': 'Bogotá'},
  'creadaEn': '2026-10-25T14:00:00Z',
  'actualizadaEn': '2026-10-26T21:05:00Z',
};

SolicitudSeguimiento _solicitud({
  String id = 'sol-1',
  String estado = 'PENDIENTE',
}) => SolicitudSeguimiento.fromJson(_solicitudJson(id: id, estado: estado));

/// Fuente en memoria: [listas] se consumen en orden en cada `listar` y
/// [cancelacion] es la respuesta de `cancelar` (solicitud o excepción).
class _Fuente implements FuenteSeguimiento {
  _Fuente(this.listas, {this.cancelacion});

  final List<List<SolicitudSeguimiento>> listas;
  Object? cancelacion;
  int consultas = 0;
  final List<(String, String?)> cancelaciones = [];

  @override
  Future<List<SolicitudSeguimiento>> listar() async =>
      listas[consultas++ % listas.length];

  @override
  Future<SolicitudSeguimiento> cancelar(
    String solicitudId, {
    String? motivo,
  }) async {
    cancelaciones.add((solicitudId, motivo));
    final r = cancelacion;
    if (r is Exception) throw r;
    return r as SolicitudSeguimiento;
  }
}

/// Fuente cuya consulta falla mientras [falla] devuelva true.
class _FuenteConFalla implements FuenteSeguimiento {
  _FuenteConFalla(this.falla, this.lista);

  final bool Function() falla;
  final List<SolicitudSeguimiento> lista;

  @override
  Future<List<SolicitudSeguimiento>> listar() async {
    if (falla()) {
      throw const SeguimientoFailure(SeguimientoErrorTipo.sinConexion);
    }
    return lista;
  }

  @override
  Future<SolicitudSeguimiento> cancelar(String solicitudId, {String? motivo}) =>
      throw UnimplementedError();
}

/// Devuelve lo que había al consultar, pero tarda hasta que se abra [compuerta].
class _FuenteLenta extends _Fuente {
  _FuenteLenta(super.listas, {super.cancelacion});

  Completer<void>? compuerta;

  @override
  Future<List<SolicitudSeguimiento>> listar() async {
    final c = compuerta;
    final foto = await super.listar();
    if (c != null) await c.future;
    return foto;
  }
}

void main() {
  group('US-04.5.1 (SCRUM-877) · modelo', () {
    test('se ofrece cancelar en todo estado anterior a la ejecución', () {
      for (final e in [
        'PENDIENTE',
        'ASIGNADA',
        'COTIZANDO',
        'ACEPTADA',
        'RECHAZADA',
      ]) {
        expect(_solicitud(estado: e).puedeCancelar, isTrue, reason: e);
      }
      for (final e in ['EN_EJECUCION', 'FINALIZADA', 'CANCELADA', 'RARO']) {
        expect(_solicitud(estado: e).puedeCancelar, isFalse, reason: e);
      }
    });
  });

  group('US-04.5.1 (SCRUM-877) · fuente por el Gateway', () {
    late List<http.Request> peticiones;

    GatewayFuenteSeguimiento fuente(
      Future<http.Response> Function(http.Request) h,
    ) {
      peticiones = [];
      return GatewayFuenteSeguimiento(
        GatewayClient(
          baseUrl: 'http://gateway.test',
          tokenProvider: () async => 'token',
          maxRetries: 0,
          httpClient: MockClient((req) {
            peticiones.add(req);
            return h(req);
          }),
        ),
      );
    }

    Matcher falla(SeguimientoErrorTipo tipo) =>
        throwsA(isA<SeguimientoFailure>().having((f) => f.tipo, 'tipo', tipo));

    test(
      'PATCH /core/solicitudes/me/{id}/cancelar con el motivo y sin ids del cliente',
      () async {
        final r = await fuente(
          (_) async => http.Response(
            jsonEncode({
              'solicitud': _solicitudJson(estado: 'CANCELADA'),
              'cancelada': true,
            }),
            200,
            headers: _json,
          ),
        ).cancelar('sol-1', motivo: '  Ya lo resolví  ');

        expect(r.estado, EstadoSeguimiento.cancelada);
        final req = peticiones.single;
        expect(req.method, 'PATCH');
        expect(req.url.path, '/api/v1/core/solicitudes/me/sol-1/cancelar');
        expect(jsonDecode(req.body), {'motivo': 'Ya lo resolví'});
      },
    );

    test('sin motivo envía un cuerpo vacío', () async {
      await fuente(
        (_) async => http.Response(
          jsonEncode({'solicitud': _solicitudJson(estado: 'CANCELADA')}),
          200,
          headers: _json,
        ),
      ).cancelar('sol-1', motivo: '   ');

      expect(jsonDecode(peticiones.single.body), isEmpty);
    });

    test('404, 409, 422 y una respuesta sin solicitud se traducen', () async {
      Future<http.Response> error(int status, String code) async =>
          http.Response(
            jsonEncode({'error': code, 'code': code}),
            status,
            headers: _json,
          );

      await expectLater(
        fuente((_) => error(404, 'MANI-SOL-404')).cancelar('x'),
        falla(SeguimientoErrorTipo.noEncontrada),
      );
      await expectLater(
        fuente((_) => error(409, 'MANI-SOL-409C')).cancelar('x'),
        falla(SeguimientoErrorTipo.noCancelable),
      );
      await expectLater(
        fuente((_) => error(422, 'MANI-SOL-422M')).cancelar('x'),
        falla(SeguimientoErrorTipo.motivoInvalido),
      );
      await expectLater(
        fuente(
          (_) async => http.Response('{}', 200, headers: _json),
        ).cancelar('x'),
        falla(SeguimientoErrorTipo.desconocido),
      );
    });
  });

  group('US-04.5.1 (SCRUM-877) · cubit', () {
    test('reemplaza la tarjeta por la solicitud cancelada', () async {
      final f = _Fuente([
        [_solicitud(), _solicitud(id: 'sol-2', estado: 'ASIGNADA')],
      ], cancelacion: _solicitud(estado: 'CANCELADA'));
      final cubit = MisSolicitudesCubit(f);
      await cubit.cargar();

      final ok = await cubit.cancelar('sol-1', motivo: 'm');

      expect(ok, isTrue);
      expect(f.cancelaciones, [('sol-1', 'm')]);
      expect(cubit.state.cancelandoId, isNull);
      expect(cubit.state.error, isNull);
      expect(cubit.state.solicitudes.map((s) => s.estadoCrudo), [
        'CANCELADA',
        'ASIGNADA',
      ]);
      await cubit.close();
    });

    test(
      'si ya empezó la ejecución avisa y vuelve a consultar el estado real',
      () async {
        final f = _Fuente(
          [
            [_solicitud(estado: 'ASIGNADA')],
            [_solicitud(estado: 'EN_EJECUCION')],
          ],
          cancelacion: const SeguimientoFailure(
            SeguimientoErrorTipo.noCancelable,
          ),
        );
        final cubit = MisSolicitudesCubit(f);
        await cubit.cargar();

        final ok = await cubit.cancelar('sol-1');

        expect(ok, isFalse);
        expect(f.consultas, 2);
        expect(cubit.state.solicitudes.single.estadoCrudo, 'EN_EJECUCION');
        expect(
          cubit.state.error,
          const SeguimientoFailure(
            SeguimientoErrorTipo.noCancelable,
          ).mensajeUsuario,
        );
        await cubit.close();
      },
    );

    test(
      'un fallo de red conserva la lista y avisa, sin reconsultar',
      () async {
        final f = _Fuente(
          [
            [_solicitud()],
          ],
          cancelacion: const SeguimientoFailure(
            SeguimientoErrorTipo.sinConexion,
          ),
        );
        final cubit = MisSolicitudesCubit(f);
        await cubit.cargar();

        expect(await cubit.cancelar('sol-1'), isFalse);
        expect(f.consultas, 1);
        expect(cubit.state.solicitudes.single.estadoCrudo, 'PENDIENTE');
        expect(cubit.state.error, isNotNull);
        await cubit.close();
      },
    );
  });

  group('US-04.5.1 (SCRUM-877) · pantalla', () {
    Future<_Fuente> montar(WidgetTester tester, _Fuente f) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => MisSolicitudesCubit(f)..cargar(),
              child: const MisSolicitudesPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return f;
    }

    testWidgets('solo ofrece cancelar antes de la ejecución', (tester) async {
      await montar(
        tester,
        _Fuente([
          [
            _solicitud(id: 'a'),
            _solicitud(id: 'b', estado: 'EN_EJECUCION'),
            _solicitud(id: 'c', estado: 'CANCELADA'),
          ],
        ]),
      );

      expect(find.byKey(const Key('cancelar-solicitud-a')), findsOneWidget);
      expect(find.byKey(const Key('cancelar-solicitud-b')), findsNothing);
      expect(find.byKey(const Key('cancelar-solicitud-c')), findsNothing);
    });

    testWidgets('pide confirmación; «Volver» no cancela', (tester) async {
      final f = await montar(
        tester,
        _Fuente([
          [_solicitud()],
        ], cancelacion: _solicitud(estado: 'CANCELADA')),
      );

      await tester.tap(find.byKey(const Key('cancelar-solicitud-sol-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dialogo-cancelar')), findsOneWidget);
      expect(find.textContaining('no se puede deshacer'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cancelar-volver')));
      await tester.pumpAndSettle();
      expect(f.cancelaciones, isEmpty);
      expect(find.text('Buscando aliado'), findsOneWidget);
    });

    testWidgets(
      'al confirmar cancela con el motivo y la tarjeta queda Cancelada',
      (tester) async {
        final f = await montar(
          tester,
          _Fuente([
            [_solicitud(estado: 'ASIGNADA')],
          ], cancelacion: _solicitud(estado: 'CANCELADA')),
        );

        await tester.tap(find.byKey(const Key('cancelar-solicitud-sol-1')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Le avisaremos al aliado asignado'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('cancelar-motivo')),
          'Ya no lo necesito',
        );
        await tester.tap(find.byKey(const Key('cancelar-confirmar')));
        await tester.pumpAndSettle();

        expect(f.cancelaciones, [('sol-1', 'Ya no lo necesito')]);
        expect(find.text('Cancelada'), findsOneWidget);
        expect(find.byKey(const Key('cancelar-solicitud-sol-1')), findsNothing);
        expect(find.byKey(const Key('cancelacion-ok')), findsOneWidget);
      },
    );

    testWidgets('si Core la rechaza muestra el motivo del error', (
      tester,
    ) async {
      await montar(
        tester,
        _Fuente(
          [
            [_solicitud(estado: 'ASIGNADA')],
            [_solicitud(estado: 'EN_EJECUCION')],
          ],
          cancelacion: const SeguimientoFailure(
            SeguimientoErrorTipo.noCancelable,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('cancelar-solicitud-sol-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancelar-confirmar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('seguimiento-error')), findsOneWidget);
      expect(find.textContaining('no se puede cancelar'), findsOneWidget);
      expect(find.text('En ejecución'), findsOneWidget);
      expect(find.byKey(const Key('cancelacion-ok')), findsNothing);
    });
  });

  group('SCRUM-1710 · sondeo de Mis solicitudes', () {
    test('trae el estado nuevo sin pasar por cargando y actualiza la hora '
        'de consulta', () async {
      var ahora = DateTime(2026, 11, 13, 10);
      final f = _Fuente([
        [_solicitud()],
        [_solicitud(estado: 'ASIGNADA')],
      ]);
      final cubit = MisSolicitudesCubit(f, reloj: () => ahora);
      await cubit.cargar();
      final estados = <MisSolicitudesState>[];
      final sub = cubit.stream.listen(estados.add);

      ahora = DateTime(2026, 11, 13, 10, 0, 20);
      await cubit.cargar(silencioso: true);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.solicitudes.single.estadoCrudo, 'ASIGNADA');
      expect(cubit.state.consultadoEn, ahora);
      expect(estados.any((e) => e.cargando), isFalse);
      await sub.cancel();
      await cubit.close();
    });

    test('un fallo conserva la lista y no muestra error', () async {
      var falla = false;
      final f = _FuenteConFalla(() => falla, [_solicitud()]);
      final cubit = MisSolicitudesCubit(f);
      await cubit.cargar();
      falla = true;

      await cubit.cargar(silencioso: true);

      expect(cubit.state.solicitudes, hasLength(1));
      expect(cubit.state.error, isNull);
      await cubit.close();
    });

    test('un sondeo exitoso borra el error de una carga fallida', () async {
      var falla = false;
      final f = _FuenteConFalla(() => falla, [_solicitud()]);
      final cubit = MisSolicitudesCubit(f);
      await cubit.cargar();
      falla = true;
      await cubit.cargar();
      expect(cubit.state.error, isNotNull);

      falla = false;
      await cubit.cargar(silencioso: true);

      expect(cubit.state.error, isNull);
      await cubit.close();
    });

    test('no borra el motivo de una cancelación rechazada', () async {
      final f = _Fuente(
        [
          [_solicitud(estado: 'ASIGNADA')],
          [_solicitud(estado: 'EN_EJECUCION')],
        ],
        cancelacion: const SeguimientoFailure(
          SeguimientoErrorTipo.noCancelable,
        ),
      );
      final cubit = MisSolicitudesCubit(f);
      await cubit.cargar();
      await cubit.cancelar('sol-1');
      final motivo = cubit.state.error;
      expect(motivo, isNotNull);

      await cubit.cargar(silencioso: true);

      expect(cubit.state.error, motivo);
      await cubit.close();
    });

    test('no consulta mientras hay una cancelación en curso', () async {
      final f = _Fuente([
        [_solicitud()],
      ], cancelacion: _solicitud(estado: 'CANCELADA'));
      final cubit = MisSolicitudesCubit(f);
      await cubit.cargar();

      final cancelacion = cubit.cancelar('sol-1');
      await cubit.cargar(silencioso: true);
      await cancelacion;

      expect(f.consultas, 1);
      expect(cubit.state.solicitudes.single.estadoCrudo, 'CANCELADA');
      await cubit.close();
    });
  });

  group('SCRUM-1710 · pantalla de Mis solicitudes con sondeo', () {
    testWidgets('a los 20 s muestra el estado nuevo sin recargar', (
      tester,
    ) async {
      final f = _Fuente([
        [_solicitud(estado: 'ASIGNADA')],
        [_solicitud(estado: 'EN_EJECUCION')],
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => MisSolicitudesCubit(f)..cargar(),
              child: const MisSolicitudesPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('En ejecución'), findsNothing);

      await tester.pump(RefrescoPeriodico.intervaloPorDefecto);
      await tester.pumpAndSettle();

      expect(f.consultas, 2);
      expect(find.text('En ejecución'), findsOneWidget);
    });

    testWidgets('sin intervalo no vuelve a consultar', (tester) async {
      final f = _Fuente([
        [_solicitud()],
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => MisSolicitudesCubit(f)..cargar(),
              child: const MisSolicitudesPage(intervaloRefresco: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(RefrescoPeriodico.intervaloPorDefecto * 3);

      expect(f.consultas, 1);
    });
  });

  test('SCRUM-1710: una respuesta vieja del sondeo no deshace una '
      'cancelación posterior', () async {
    final f = _FuenteLenta([
      [_solicitud()],
    ], cancelacion: _solicitud(estado: 'CANCELADA'));
    final cubit = MisSolicitudesCubit(f);
    await cubit.cargar();

    f.compuerta = Completer<void>();
    final sondeo = cubit.cargar(silencioso: true);
    final compuerta = f.compuerta!;
    f.compuerta = null;
    expect(await cubit.cancelar('sol-1'), isTrue);

    compuerta.complete();
    await sondeo;

    expect(cubit.state.solicitudes.single.estadoCrudo, 'CANCELADA');
    await cubit.close();
  });
}
