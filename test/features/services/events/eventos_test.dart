import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/platform/selector_fotos.dart';
import 'package:mani/core/platform/url_opener.dart';
import 'package:mani/features/services/events/data/eventos_datasource.dart';
import 'package:mani/features/services/events/presentation/eventos_cubit.dart';
import 'package:mani/features/services/events/presentation/eventos_seccion.dart';
import 'package:mani/features/services/quotes/domain/cotizacion.dart';
import 'package:mani/features/services/requests/domain/entities/foto_adjunta.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

// PNG mínimo válido (cabecera), suficiente para FotoAdjunta.
final _png = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
]);

Map<String, dynamic> _eventoJson(String id, String tipo, {bool foto = false}) =>
    {
      'id': id,
      'tipo': tipo,
      'descripcion': 'Cambié la tubería',
      'registradoEn': '2026-10-27T16:00:00Z',
      'autor': {'id': 'u-1', 'rol': 'ALIADO'},
      'tieneEvidencia': foto,
    };

class _FuenteFake implements FuenteEventos {
  List<EventoServicio> lista = [];
  Object? falloRegistrar;
  final claves = <String>[];
  final registros = <String>[];
  Object? falloEvidencia;
  final evidenciasPedidas = <String>[];

  @override
  Future<Uri> urlEvidencia(String solicitudId, String eventoId) async {
    evidenciasPedidas.add(eventoId);
    if (falloEvidencia != null) throw falloEvidencia!;
    return Uri.parse('https://firmada/$eventoId.png');
  }

  @override
  Future<List<EventoServicio>> listar(String solicitudId) async => lista;

  @override
  Future<EventoServicio> registrar(
    String solicitudId, {
    required TipoEventoAliado tipo,
    required String observacion,
    required String claveIdempotencia,
    FotoAdjunta? foto,
    DateTime? ocurridoEn,
  }) async {
    claves.add(claveIdempotencia);
    if (falloRegistrar != null) throw falloRegistrar!;
    registros.add('${tipo.valor}:$observacion:${foto != null}');
    final e = EventoServicio.fromJson(
      _eventoJson(
        'e${lista.length + 1}',
        'EJECUCION_${tipo.valor}',
        foto: foto != null,
      ),
    );
    lista = [...lista, e];
    return e;
  }
}

class _OpenerFake implements UrlOpener {
  final abiertas = <Uri>[];

  @override
  Future<bool> abrir(Uri url) async {
    abiertas.add(url);
    return true;
  }
}

class _SelectorFijo implements SelectorFotos {
  @override
  Future<List<ArchivoLocal>> seleccionar() async => [
    ArchivoLocal(nombre: 'fuga.png', bytes: _png),
  ];
}

void main() {
  test(
    'el modelo traduce los tipos conocidos y vuelve legible el código de los desconocidos',
    () {
      expect(
        EventoServicio.fromJson(
          _eventoJson('a', 'INICIO_EJECUCION'),
        ).etiquetaTipo,
        'Inicio del servicio',
      );
      expect(
        EventoServicio.fromJson(
          _eventoJson('a', 'EJECUCION_NOVEDAD'),
        ).etiquetaTipo,
        'Novedad',
      );
      // Un tipo que la app aún no conoce no se muestra como código de Core.
      expect(
        EventoServicio.fromJson(_eventoJson('a', 'OTRO_TIPO')).etiquetaTipo,
        'Otro tipo',
      );
      // SOLICITUD_ASIGNADA salía como código crudo en la bitácora.
      expect(
        EventoServicio.fromJson(
          _eventoJson('a', 'SOLICITUD_ASIGNADA'),
        ).etiquetaTipo,
        'Aliado asignado',
      );
      // SCRUM-1432: el pago aprobado aparece en la bitácora con un texto legible.
      expect(
        EventoServicio.fromJson(
          _eventoJson('a', 'PAGO_REGISTRADO'),
        ).etiquetaTipo,
        'Pago aprobado',
      );
    },
  );

  group('SCRUM-869 · fuente por el Gateway', () {
    late List<http.BaseRequest> peticiones;
    late http.Response Function(http.BaseRequest) responder;

    GatewayFuenteEventos fuente() => GatewayFuenteEventos(
      GatewayClient(
        baseUrl: 'http://gateway.local',
        tokenProvider: () async => 'jwt',
        correlationId: () => 'corr',
        initialRetryDelay: Duration.zero,
        httpClient: MockClient.streaming((r, body) async {
          peticiones.add(r);
          await body.drain<void>();
          final res = responder(r);
          return http.StreamedResponse(
            Stream.value(res.bodyBytes),
            res.statusCode,
            headers: res.headers,
          );
        }),
      ),
    );

    setUp(() => peticiones = []);

    test(
      'registrar va en multipart con tipo, observación, foto y la clave también en la cabecera',
      () async {
        responder = (_) => http.Response(
          jsonEncode({
            'evento': _eventoJson('e1', 'EJECUCION_AVANCE', foto: true),
          }),
          201,
          headers: _json,
        );
        final e = await fuente().registrar(
          'sol-1',
          tipo: TipoEventoAliado.avance,
          observacion: 'Cambié la tubería',
          claveIdempotencia: 'clave-1',
          foto: FotoAdjunta.crear(nombre: 'fuga.png', bytes: _png),
        );
        final r = peticiones.single as http.MultipartRequest;
        expect(r.url.path, '/api/v1/core/solicitudes/sol-1/eventos');
        expect(r.fields, {
          'tipo': 'AVANCE',
          'observacion': 'Cambié la tubería',
          'claveIdempotencia': 'clave-1',
        });
        expect(r.files.single.field, 'foto');
        expect(r.headers[GatewayClient.headerIdempotencyKey], 'clave-1');
        expect(e.tieneEvidencia, isTrue);
      },
    );

    test('SCRUM-873: un evento de la cola envía su hora de captura en UTC y la '
        'respuesta trae las dos horas', () async {
      responder = (_) => http.Response(
        jsonEncode({
          'evento': {
            ..._eventoJson('e1', 'EJECUCION_AVANCE'),
            'ocurridoEn': '2026-10-27T15:10:00Z',
          },
        }),
        201,
        headers: _json,
      );
      final e = await fuente().registrar(
        'sol-1',
        tipo: TipoEventoAliado.avance,
        observacion: 'Sin señal',
        claveIdempotencia: 'clave-1',
        ocurridoEn: DateTime.utc(2026, 10, 27, 15, 10, 0, 120),
      );
      final r = peticiones.single as http.MultipartRequest;
      expect(r.fields['ocurridoEn'], '2026-10-27T15:10:00.120Z');
      expect(e.ocurridoEn, DateTime.utc(2026, 10, 27, 15, 10).toLocal());
      expect(e.registradoEn, DateTime.utc(2026, 10, 27, 16).toLocal());
      expect(e.llegoTarde, isTrue);
    });

    test(
      'un 503 se reintenta con la misma clave: el registro es idempotente',
      () async {
        var n = 0;
        responder = (_) => ++n == 1
            ? http.Response('{"error":"caído"}', 503)
            : http.Response(
                jsonEncode({'evento': _eventoJson('e1', 'EJECUCION_AVANCE')}),
                200,
                headers: _json,
              );
        await fuente().registrar(
          'sol-1',
          tipo: TipoEventoAliado.avance,
          observacion: 'Hola',
          claveIdempotencia: 'clave-1',
        );
        expect(peticiones, hasLength(2));
      },
    );

    test('un 409 de Core se traduce con su texto, sin el código', () async {
      responder = (_) => http.Response(
        jsonEncode({
          'error':
              'MANI-EVT-409E: solo se registran eventos durante la ejecución (estado FINALIZADA)',
        }),
        409,
        headers: _json,
      );
      await expectLater(
        fuente().registrar(
          'sol-1',
          tipo: TipoEventoAliado.avance,
          observacion: 'Hola',
          claveIdempotencia: 'c',
        ),
        throwsA(
          isA<CotizacionFailure>().having(
            (f) => f.mensajeUsuario,
            'mensaje',
            'Solo se registran eventos durante la ejecución (estado FINALIZADA)',
          ),
        ),
      );
    });

    test(
      'listar lee la secuencia; una respuesta sin la lista es un error',
      () async {
        responder = (_) => http.Response(
          jsonEncode({
            'eventos': [
              _eventoJson('e1', 'INICIO_EJECUCION'),
              _eventoJson('e2', 'EJECUCION_AVANCE'),
            ],
          }),
          200,
          headers: _json,
        );
        final lista = await fuente().listar('sol-1');
        expect(lista.map((e) => e.id), ['e1', 'e2']);
        expect(lista.first.autorRol, 'ALIADO');

        responder = (_) => http.Response('{}', 200, headers: _json);
        await expectLater(
          fuente().listar('sol-1'),
          throwsA(isA<CotizacionFailure>()),
        );
      },
    );
  });

  group('SCRUM-869 · cubit', () {
    test(
      'la clave se conserva si el envío falla y se renueva cuando queda registrado',
      () async {
        var n = 0;
        final f = _FuenteFake()
          ..falloRegistrar = const CotizacionFailure(
            CotizacionErrorTipo.sinConexion,
          );
        final cubit = EventosCubit(
          f,
          'sol-1',
          generarClave: () => 'clave-${++n}',
        );

        expect(
          await cubit.registrar(
            tipo: TipoEventoAliado.avance,
            observacion: 'Hola',
          ),
          isFalse,
        );
        expect(cubit.state.avisoEsError, isTrue);
        f.falloRegistrar = null;
        expect(
          await cubit.registrar(
            tipo: TipoEventoAliado.avance,
            observacion: 'Hola',
          ),
          isTrue,
        );

        expect(f.claves, ['clave-1', 'clave-1']);
        expect(cubit.state.clave, 'clave-2');
        expect(cubit.state.eventos, hasLength(1));
        expect(cubit.state.aviso, 'Evento registrado.');
      },
    );
  });

  group('SCRUM-869 · sección', () {
    Future<_FuenteFake> montar(
      WidgetTester tester, {
      required bool puedeRegistrar,
    }) async {
      final f = _FuenteFake();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider(
                create: (_) => EventosCubit(f, 'sol-1')..cargar(),
                child: EventosSeccion(
                  puedeRegistrar: puedeRegistrar,
                  urlOpener: _OpenerFake(),
                  selectorFotos: _SelectorFijo(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return f;
    }

    testWidgets(
      'en ejecución el aliado registra una novedad con foto y la ve en la bitácora',
      (tester) async {
        final f = await montar(tester, puedeRegistrar: true);
        expect(find.text('Aún no hay eventos registrados.'), findsOneWidget);

        await tester.tap(find.text('Novedad'));
        await tester.enterText(
          find.byKey(const Key('campo-observacion-evento')),
          'Fuga adicional',
        );
        await tester.tap(find.byKey(const Key('btn-foto-evento')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('foto-evento-elegida')), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn-registrar-evento')));
        await tester.pumpAndSettle();
        expect(f.registros, ['NOVEDAD:Fuga adicional:true']);
        expect(find.text('Novedad'), findsWidgets);
        expect(find.byKey(const Key('evento-e1')), findsOneWidget);
        // El formulario queda limpio para el siguiente evento.
        expect(find.byKey(const Key('foto-evento-elegida')), findsNothing);
      },
    );

    testWidgets('con menos de 3 caracteres no se puede registrar', (
      tester,
    ) async {
      await montar(tester, puedeRegistrar: true);
      await tester.enterText(
        find.byKey(const Key('campo-observacion-evento')),
        'no',
      );
      await tester.pump();
      final boton = find.byKey(const Key('btn-registrar-evento'));
      await tester.tap(boton);
      await tester.pump();
      expect(find.text('Aún no hay eventos registrados.'), findsOneWidget);
    });

    testWidgets(
      'fuera de la ejecución solo se ve la bitácora, sin formulario',
      (tester) async {
        await montar(tester, puedeRegistrar: false);
        expect(find.byKey(const Key('seccion-eventos')), findsOneWidget);
        expect(find.byKey(const Key('btn-registrar-evento')), findsNothing);
      },
    );
  });

  group('SCRUM-870 · el cliente consulta la bitácora', () {
    test(
      'la fuente pide la evidencia a su ruta y exige una URL válida',
      () async {
        late http.Request pedida;
        var cuerpo = jsonEncode({
          'evidencia': {
            'url': 'https://firmada/e1.png',
            'expiraEnSegundos': 300,
          },
        });
        final fuente = GatewayFuenteEventos(
          GatewayClient(
            baseUrl: 'http://gateway.local',
            tokenProvider: () async => 'jwt',
            correlationId: () => 'corr',
            initialRetryDelay: Duration.zero,
            httpClient: MockClient((r) async {
              pedida = r;
              return http.Response(cuerpo, 200, headers: _json);
            }),
          ),
        );
        final url = await fuente.urlEvidencia('sol-1', 'e1');
        expect(
          pedida.url.path,
          '/api/v1/core/solicitudes/sol-1/eventos/e1/evidencia',
        );
        expect(url.toString(), 'https://firmada/e1.png');

        cuerpo = '{"evidencia":{}}';
        await expectLater(
          fuente.urlEvidencia('sol-1', 'e1'),
          throwsA(isA<CotizacionFailure>()),
        );
      },
    );

    Future<(_FuenteFake, _OpenerFake)> montarCliente(
      WidgetTester tester,
    ) async {
      final f = _FuenteFake()
        ..lista = [
          EventoServicio.fromJson(_eventoJson('e1', 'INICIO_EJECUCION')),
          EventoServicio.fromJson(
            _eventoJson('e2', 'EJECUCION_AVANCE', foto: true),
          ),
        ];
      final opener = _OpenerFake();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider(
                create: (_) => EventosCubit(f, 'sol-1')..cargar(),
                child: EventosSeccion(puedeRegistrar: false, urlOpener: opener),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (f, opener);
    }

    testWidgets('ve la secuencia en orden y en solo lectura', (tester) async {
      await montarCliente(tester);
      expect(find.text('Inicio del servicio'), findsOneWidget);
      expect(find.text('Avance'), findsOneWidget);
      final y1 = tester.getTopLeft(find.byKey(const Key('evento-e1'))).dy;
      final y2 = tester.getTopLeft(find.byKey(const Key('evento-e2'))).dy;
      expect(y1, lessThan(y2));
      expect(find.byKey(const Key('btn-registrar-evento')), findsNothing);
      expect(find.byKey(const Key('ver-foto-e1')), findsNothing);
    });

    testWidgets('«Ver foto» pide una URL nueva cada vez y la abre', (
      tester,
    ) async {
      final (f, opener) = await montarCliente(tester);
      await tester.tap(find.byKey(const Key('ver-foto-e2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ver-foto-e2')));
      await tester.pumpAndSettle();
      expect(f.evidenciasPedidas, ['e2', 'e2']);
      expect(opener.abiertas.map((u) => u.toString()), [
        'https://firmada/e2.png',
        'https://firmada/e2.png',
      ]);
    });

    testWidgets('si Core no da la foto, se avisa y no se abre nada', (
      tester,
    ) async {
      final (f, opener) = await montarCliente(tester);
      f.falloEvidencia = const CotizacionFailure(
        CotizacionErrorTipo.noEncontrada,
      );
      await tester.tap(find.byKey(const Key('ver-foto-e2')));
      await tester.pumpAndSettle();
      expect(opener.abiertas, isEmpty);
      expect(
        find.text('No encontramos esta solicitud o cotización.'),
        findsOneWidget,
      );
    });
  });

  group('SCRUM-870 · ramas de error al ver la foto', () {
    test(
      'un 404 de Core al pedir la foto llega como fallo de no encontrada',
      () async {
        final fuente = GatewayFuenteEventos(
          GatewayClient(
            baseUrl: 'http://gateway.local',
            tokenProvider: () async => 'jwt',
            correlationId: () => 'corr',
            initialRetryDelay: Duration.zero,
            httpClient: MockClient(
              (_) async => http.Response(
                '{"error":"MANI-EVT-404E: el evento no tiene evidencia"}',
                404,
                headers: _json,
              ),
            ),
          ),
        );
        await expectLater(
          fuente.urlEvidencia('sol-1', 'e1'),
          throwsA(
            isA<CotizacionFailure>().having(
              (f) => f.tipo,
              'tipo',
              CotizacionErrorTipo.noEncontrada,
            ),
          ),
        );
      },
    );

    testWidgets('si el sistema no puede abrir la URL, se avisa', (
      tester,
    ) async {
      final f = _FuenteFake()
        ..lista = [
          EventoServicio.fromJson(
            _eventoJson('e2', 'EJECUCION_AVANCE', foto: true),
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider(
                create: (_) => EventosCubit(f, 'sol-1')..cargar(),
                child: EventosSeccion(
                  puedeRegistrar: false,
                  urlOpener: _OpenerQueFalla(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ver-foto-e2')));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo abrir la foto.'), findsOneWidget);
    });
  });
}

class _OpenerQueFalla implements UrlOpener {
  @override
  Future<bool> abrir(Uri url) async => false;
}
