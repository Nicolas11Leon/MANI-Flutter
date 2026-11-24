import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/features/services/tracking/data/seguimiento_datasource.dart';
import 'package:mani/features/services/tracking/domain/solicitud_seguimiento.dart';
import 'package:mani/features/services/tracking/presentation/mis_solicitudes_cubit.dart';
import 'package:mani/features/services/tracking/presentation/mis_solicitudes_page.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _solicitudJson({
  String id = 'sol-1',
  String estado = 'ASIGNADA',
  String? zonaPadre = 'Bogotá',
}) => {
  'id': id,
  'estado': estado,
  'categoria': 'Plomería',
  'zonaDeclarada': {
    'nombre': 'Chapinero',
    'nivel': 'LOCALIDAD',
    'zonaPadre': zonaPadre,
  },
  'creadaEn': '2026-10-25T14:00:00Z',
  'actualizadaEn': '2026-10-26T21:05:00Z',
};

class _FuenteFija implements FuenteSeguimiento {
  _FuenteFija(this.respuestas);

  /// Cada llamada consume la siguiente respuesta: una lista o una excepción.
  final List<Object> respuestas;
  int llamadas = 0;

  @override
  Future<List<SolicitudSeguimiento>> listar() async {
    final r = respuestas[llamadas++ % respuestas.length];
    if (r is Exception) throw r;
    return r as List<SolicitudSeguimiento>;
  }

  @override
  Future<SolicitudSeguimiento> cancelar(String solicitudId, {String? motivo}) =>
      throw UnimplementedError();
}

/// La lista de solicitudes es un `ListView` perezoso: con la ventana de prueba
/// por defecto (800x600) las secciones de abajo y la paginación no se
/// construyen. Estas pruebas necesitan ver la lista completa.
void _usarPantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('HU-M07-04 (SCRUM-871) · modelo', () {
    test('lee estado, categoría, zona declarada y fecha de actualización', () {
      final s = SolicitudSeguimiento.fromJson(_solicitudJson());

      expect(s.estado, EstadoSeguimiento.asignada);
      expect(s.etiquetaEstado, 'Aliado asignado');
      expect(s.categoria, 'Plomería');
      expect(s.zonaCompleta, 'Chapinero · Bogotá');
      expect(s.actualizadaEn, DateTime.utc(2026, 10, 26, 21, 5).toLocal());
    });

    test('un estado desconocido se muestra como lo envía Core', () {
      final s = SolicitudSeguimiento.fromJson(
        _solicitudJson(estado: 'EN_REVISION_QA'),
      );

      expect(s.estado, EstadoSeguimiento.otro);
      expect(s.etiquetaEstado, 'EN_REVISION_QA');
    });

    test('sin zona padre ni zona no inventa texto', () {
      final sinPadre = SolicitudSeguimiento.fromJson(
        _solicitudJson(zonaPadre: null),
      );
      final sinZona = SolicitudSeguimiento.fromJson({
        'id': 'x',
        'estado': 'PENDIENTE',
        'creadaEn': '2026-10-25T14:00:00Z',
      });

      expect(sinPadre.zonaCompleta, 'Chapinero');
      expect(sinZona.zonaCompleta, isEmpty);
      expect(sinZona.categoria, 'Servicio');
      expect(sinZona.actualizadaEn, DateTime.utc(2026, 10, 25, 14).toLocal());
    });

    test('dos lecturas del mismo JSON son iguales; otra no', () {
      expect(
        SolicitudSeguimiento.fromJson(_solicitudJson()),
        SolicitudSeguimiento.fromJson(_solicitudJson()),
      );
      expect(
        SolicitudSeguimiento.fromJson(_solicitudJson()),
        isNot(SolicitudSeguimiento.fromJson(_solicitudJson(id: 'otra'))),
      );
    });

    test('sin fechas no revienta: usa el inicio de la época', () {
      final s = SolicitudSeguimiento.fromJson({'id': 'x', 'estado': 'X'});

      expect(s.actualizadaEn, DateTime.fromMillisecondsSinceEpoch(0));
      expect(s.creadaEn, isNull);
    });

    test('estados conocidos', () {
      expect(EstadoSeguimiento.desde('pendiente'), EstadoSeguimiento.pendiente);
      expect(
        EstadoSeguimiento.desde('EN_EJECUCION'),
        EstadoSeguimiento.enEjecucion,
      );
      expect(
        EstadoSeguimiento.desde('FINALIZADA'),
        EstadoSeguimiento.finalizada,
      );
      expect(EstadoSeguimiento.desde('CANCELADA'), EstadoSeguimiento.cancelada);
    });
  });

  group('HU-M07-04 (SCRUM-871) · fuente por el Gateway', () {
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

    test('GET /core/solicitudes/me sin enviar ids del cliente', () async {
      final lista = await fuente(
        (_) async => http.Response(
          jsonEncode({
            'solicitudes': [_solicitudJson(), _solicitudJson(id: 'sol-2')],
          }),
          200,
          headers: _json,
        ),
      ).listar();

      expect(lista.map((s) => s.id), ['sol-1', 'sol-2']);
      final req = peticiones.single;
      expect(req.method, 'GET');
      expect(req.url.path, '/api/v1/core/solicitudes/me');
      expect(req.url.queryParameters, isEmpty);
    });

    test(
      'una respuesta sin lista es un error, no «sin solicitudes» (T2)',
      () async {
        await expectLater(
          fuente(
            (_) async => http.Response('{}', 200, headers: _json),
          ).listar(),
          throwsA(
            isA<SeguimientoFailure>().having(
              (f) => f.tipo,
              'tipo',
              SeguimientoErrorTipo.desconocido,
            ),
          ),
        );
      },
    );

    test('401, 403, 5xx y sin red se traducen sin disfrazarse', () async {
      Future<http.Response> error(int status, String code) async =>
          http.Response(
            jsonEncode({'error': code, 'code': code}),
            status,
            headers: _json,
          );

      await expectLater(
        fuente((_) => error(401, 'MANI-SOL-401')).listar(),
        falla(SeguimientoErrorTipo.sinSesion),
      );
      await expectLater(
        fuente((_) => error(403, 'MANI-SOL-403C')).listar(),
        falla(SeguimientoErrorTipo.noEsCliente),
      );
      await expectLater(
        fuente((_) => error(503, 'SERVICE_UNAVAILABLE')).listar(),
        falla(SeguimientoErrorTipo.servicioNoDisponible),
      );
      await expectLater(
        fuente((_) => error(418, 'X')).listar(),
        falla(SeguimientoErrorTipo.desconocido),
      );
      await expectLater(
        fuente((_) async => throw http.ClientException('sin red')).listar(),
        falla(SeguimientoErrorTipo.sinConexion),
      );
    });

    test('cada error tiene mensaje para el usuario', () {
      for (final t in SeguimientoErrorTipo.values) {
        expect(SeguimientoFailure(t).mensajeUsuario, isNotEmpty);
        expect(SeguimientoFailure(t, 'd').toString(), contains(t.name));
      }
    });
  });

  group('HU-M07-04 (SCRUM-871) · cubit', () {
    final una = [SolicitudSeguimiento.fromJson(_solicitudJson())];
    final reloj = DateTime(2026, 10, 26, 16, 30);

    /// Ejecuta [accion] y devuelve los estados que emitió el cubit.
    Future<List<MisSolicitudesState>> estados(
      MisSolicitudesCubit cubit,
      Future<void> Function(MisSolicitudesCubit) accion,
    ) async {
      final emitidos = <MisSolicitudesState>[];
      final sub = cubit.stream.listen(emitidos.add);
      await accion(cubit);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await cubit.close();
      return emitidos;
    }

    test('carga y marca cuándo se consultó', () async {
      final r = await estados(
        MisSolicitudesCubit(_FuenteFija([una]), reloj: () => reloj),
        (c) => c.cargar(),
      );

      expect(r, [
        const MisSolicitudesState(cargando: true),
        MisSolicitudesState(solicitudes: una, consultadoEn: reloj),
      ]);
    });

    test('si una nueva consulta falla, conserva lo anterior y avisa', () async {
      final r = await estados(
        MisSolicitudesCubit(
          _FuenteFija([
            una,
            const SeguimientoFailure(SeguimientoErrorTipo.servicioNoDisponible),
          ]),
          reloj: () => reloj,
        ),
        (c) async {
          await c.cargar();
          await c.cargar();
        },
      );

      expect(r.skip(2), [
        MisSolicitudesState(
          cargando: true,
          solicitudes: una,
          consultadoEn: reloj,
        ),
        MisSolicitudesState(
          solicitudes: una,
          consultadoEn: reloj,
          error: const SeguimientoFailure(
            SeguimientoErrorTipo.servicioNoDisponible,
          ).mensajeUsuario,
        ),
      ]);
    });

    test('un error inesperado se muestra como desconocido', () async {
      final r = await estados(
        MisSolicitudesCubit(_FuenteFija([Exception('x')])),
        (c) => c.cargar(),
      );

      expect(
        r.last,
        MisSolicitudesState(
          error: const SeguimientoFailure(
            SeguimientoErrorTipo.desconocido,
          ).mensajeUsuario,
        ),
      );
    });

    test('si se cierra mientras consulta, no emite después', () async {
      final cubit = MisSolicitudesCubit(_FuenteFija([una]));
      final futuro = cubit.cargar();
      await cubit.close();
      await futuro;
      expect(cubit.isClosed, isTrue);
    });
  });

  group('HU-M07-04 (SCRUM-871) · pantalla', () {
    Future<_FuenteFija> montar(
      WidgetTester tester,
      List<Object> respuestas, {
      VoidCallback? onNueva,
    }) async {
      final f = _FuenteFija(respuestas);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => MisSolicitudesCubit(f)..cargar(),
              child: MisSolicitudesPage(onNuevaSolicitud: onNueva),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return f;
    }

    testWidgets('muestra estado, zona declarada y fecha, con el aviso de que '
        'no es la ubicación del aliado', (tester) async {
      await montar(tester, [
        [SolicitudSeguimiento.fromJson(_solicitudJson())],
      ]);

      expect(find.text('Plomería'), findsOneWidget);
      expect(find.text('Aliado asignado'), findsOneWidget);
      expect(find.text('Zona declarada: Chapinero · Bogotá'), findsOneWidget);
      expect(
        find.textContaining('Estado actualizado: 26 oct 2026'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('seguimiento-aviso-zona')), findsOneWidget);
      expect(find.byKey(const Key('seguimiento-consultado')), findsOneWidget);
    });

    testWidgets('«Actualizar» vuelve a consultar', (tester) async {
      final f = await montar(tester, [
        [SolicitudSeguimiento.fromJson(_solicitudJson(estado: 'PENDIENTE'))],
        [SolicitudSeguimiento.fromJson(_solicitudJson())],
      ]);
      expect(find.text('Buscando aliado'), findsOneWidget);

      await tester.tap(find.byKey(const Key('seguimiento-actualizar')));
      await tester.pumpAndSettle();

      expect(f.llamadas, 2);
      expect(find.text('Aliado asignado'), findsOneWidget);
    });

    testWidgets('sin solicitudes invita a publicar una', (tester) async {
      var abrio = false;
      await montar(tester, [
        <SolicitudSeguimiento>[],
      ], onNueva: () => abrio = true);

      expect(find.text('Aún no has publicado solicitudes.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('seguimiento-nueva')));
      expect(abrio, isTrue);
    });

    testWidgets('un error se muestra y se puede reintentar', (tester) async {
      final f = await montar(tester, [
        const SeguimientoFailure(SeguimientoErrorTipo.sinConexion),
        [SolicitudSeguimiento.fromJson(_solicitudJson())],
      ]);

      expect(find.byKey(const Key('seguimiento-error')), findsOneWidget);
      expect(find.text('Aún no has publicado solicitudes.'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(f.llamadas, 2);
      expect(find.byKey(const Key('seguimiento-error')), findsNothing);
      expect(find.text('Plomería'), findsOneWidget);
    });

    testWidgets(
      'agrupa por tipo de solicitud (publicadas, en curso, finalizadas, canceladas) y filtra por pestañas',
      (tester) async {
        _usarPantallaAlta(tester);
        await montar(tester, [
          [
            SolicitudSeguimiento.fromJson(
              _solicitudJson(id: 'sol-pub', estado: 'PENDIENTE'),
            ),
            SolicitudSeguimiento.fromJson(
              _solicitudJson(id: 'sol-cur', estado: 'ASIGNADA'),
            ),
            SolicitudSeguimiento.fromJson(
              _solicitudJson(id: 'sol-fin', estado: 'FINALIZADA'),
            ),
            SolicitudSeguimiento.fromJson(
              _solicitudJson(id: 'sol-can', estado: 'CANCELADA'),
            ),
          ],
        ]);

        expect(
          find.byKey(const Key('seccion-solicitudes-publicadas')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('seccion-solicitudes-enCurso')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('seccion-solicitudes-finalizadas')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('seccion-solicitudes-canceladas')),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.byKey(const Key('tab-solicitudes-canceladas')),
        );
        await tester.tap(find.byKey(const Key('tab-solicitudes-canceladas')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('seccion-solicitudes-canceladas')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('seccion-solicitudes-publicadas')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'pagina las solicitudes cuando superan itemsPorPagina y permite abrir detalle',
      (tester) async {
        _usarPantallaAlta(tester);
        String? abierta;
        final f = _FuenteFija([
          [
            for (var i = 1; i <= 5; i++)
              SolicitudSeguimiento.fromJson(
                _solicitudJson(id: 'sol-$i', estado: 'PENDIENTE'),
              ),
          ],
        ]);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BlocProvider(
                create: (_) => MisSolicitudesCubit(f)..cargar(),
                child: MisSolicitudesPage(
                  itemsPorPagina: 2,
                  onVerCotizacion: (id) => abierta = id,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('paginacion-solicitudes')), findsOneWidget);
        expect(find.byKey(const Key('ver-detalle-sol-1')), findsOneWidget);
        expect(find.byKey(const Key('ver-detalle-sol-3')), findsNothing);

        await tester.ensureVisible(find.byKey(const Key('ver-detalle-sol-1')));
        await tester.tap(find.byKey(const Key('ver-detalle-sol-1')));
        expect(abierta, 'sol-1');

        await tester.ensureVisible(
          find.byKey(const Key('pagina-solicitudes-2')),
        );
        await tester.tap(find.byKey(const Key('pagina-solicitudes-2')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('ver-detalle-sol-3')), findsOneWidget);
      },
    );
  });

  test('formatearFecha usa día, mes corto, año y hora local', () {
    expect(formatearFecha(DateTime(2026, 1, 5, 9, 7)), '5 ene 2026, 09:07');
  });
}
