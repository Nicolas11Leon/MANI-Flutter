import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/platform/selector_fotos.dart';
import 'package:mani/core/platform/url_opener.dart';
import 'package:mani/core/routing/app_router.dart';
import 'package:mani/features/messaging/data/mensajes_datasource.dart';
import 'package:mani/features/messaging/domain/mensaje.dart';
import 'package:mani/features/messaging/presentation/chat_page.dart';
import 'package:mani/features/services/additions/data/adiciones_datasource.dart';
import 'package:mani/features/services/events/data/eventos_datasource.dart';
import 'package:mani/features/services/execution/data/ejecucion_datasource.dart';
import 'package:mani/features/services/quotes/data/cotizaciones_datasource.dart';
import 'package:mani/features/services/quotes/domain/cotizacion.dart';
import 'package:mani/features/services/requests/domain/entities/foto_adjunta.dart';
import 'package:mani/features/services/ratings/data/calificacion_cierre_datasource.dart';
import 'package:mani/features/services/ratings/domain/calificacion_cierre_modelos.dart';
import 'package:mani/features/tariffs/data/tarifas_datasource.dart';
import 'package:mani/features/tariffs/domain/evaluacion_tarifa.dart';
import 'package:mani/features/tariffs/domain/tarifa.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _PkceEnMemoria extends GotrueAsyncStorage {
  final _datos = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _datos[key];
  @override
  Future<void> removeItem({required String key}) async => _datos.remove(key);
  @override
  Future<void> setItem({required String key, required String value}) async =>
      _datos[key] = value;
}

class _Cotizaciones implements FuenteCotizaciones {
  @override
  Future<List<Cotizacion>> listar(String solicitudId) async => [
    Cotizacion.fromJson({
      'id': 'cot-1',
      'solicitudId': solicitudId,
      'version': 1,
      'estado': 'ACEPTADA',
      'valorManoObra': 100,
      'valorMateriales': 0,
      'total': 100,
    }),
  ];

  @override
  Future<Cotizacion> emitir(
    String solicitudId, {
    required String valorManoObra,
    required String valorMateriales,
  }) => throw UnimplementedError();

  @override
  Future<Cotizacion> responder(
    String cotizacionId,
    DecisionCotizacion decision, {
    String? texto,
  }) => throw UnimplementedError();
}

// La categoría de la solicitud tiene tarifa vigente (SCRUM-886).
class _Tarifas implements FuenteTarifas {
  @override
  Future<ReferenciaTarifa> referencia(String solicitudId) async =>
      ReferenciaTarifa.fromJson({
        'disponible': true,
        'tarifa': {
          'id': 'tar-1',
          'categoriaId': 'cat-1',
          'categoriaNombre': 'Plomería',
          'valorMin': 80000,
          'valorTipico': 120000,
          'valorMax': 180000,
          'moneda': 'COP',
          'vigenciaDesde': '2026-01-01',
          'version': 2,
        },
      });

  // SCRUM-866: la cotización vigente (total 100) queda por debajo del mínimo.
  @override
  Future<EvaluacionTarifa> evaluacion(String cotizacionId) async =>
      EvaluacionTarifa.fromJson({
        'cotizacionId': cotizacionId,
        'resultado': 'POR_DEBAJO',
        'total': 100,
        'desviacionPorcentaje': 99.9,
        'tarifa': {
          'valorMin': 80000,
          'valorTipico': 120000,
          'valorMax': 180000,
          'moneda': 'COP',
        },
      });

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// Calificación y cierre (SCRUM-874, 875 y 1418): el estado de la solicitud lo
// fija cada prueba; por omisión, en ejecución (aún no se califica).
class _ModuloM08 implements FuenteModuloM08 {
  String estado = 'EN_EJECUCION';
  int consultas = 0;

  @override
  Future<ResumenCalificacionesSolicitud> obtenerCalificaciones(
    String solicitudId,
  ) async {
    consultas++;
    return ResumenCalificacionesSolicitud(
      solicitudId: solicitudId,
      estado: estado,
      cierre: EstadoCierreSolicitud(
        cerrada: estado == 'CERRADA',
        estadoSolicitud: estado,
        tieneCalificacionCliente: false,
        tieneCalificacionAliado: false,
        pendientes: const ['CLIENTE', 'ALIADO'],
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// Cotización de 100 con una adición aceptada de 30: total vigente 130 (SCRUM-872).
class _Adiciones implements FuenteAdiciones {
  int consultas = 0;

  @override
  Future<AdicionesServicio> listar(String solicitudId) async {
    consultas++;
    return AdicionesServicio(
      adiciones: [
        Adicion.fromJson({
          'id': 'adi-1',
          'motivo': 'Tubería rota detrás del muro',
          'valorManoObra': 30,
          'valorMateriales': 0,
          'total': 30,
          'estado': 'ACEPTADA',
        }),
      ],
      resumen: ResumenAdiciones.desde({
        'totalCotizacion': 100,
        'totalAdicionesAceptadas': 30,
        'totalVigente': 130,
        'disponibleParaAdiciones': 20,
      }),
    );
  }

  @override
  Future<void> solicitar(
    String solicitudId, {
    required String motivo,
    required String valorManoObra,
    required String valorMateriales,
    int? tiempoAdicionalMinutos,
  }) async {}

  @override
  Future<void> responder(
    String adicionId,
    DecisionAdicion decision, {
    String? comentario,
  }) async {}
}

class _Ejecucion implements FuenteEjecucion {
  int consultas = 0;

  @override
  Future<Ejecucion> consultar(String solicitudId) async {
    consultas++;
    return Ejecucion.fromJson({
      'estado': 'EN_EJECUCION',
      'inicio': {'registradoEn': '2026-10-27T15:00:00Z'},
      'fin': null,
    });
  }

  @override
  Future<void> marcar(
    String solicitudId,
    HitoEjecucion hito, {
    String? observacion,
  }) async {}
}

class _Eventos implements FuenteEventos {
  int consultas = 0;

  @override
  Future<List<EventoServicio>> listar(String solicitudId) async {
    consultas++;
    return [
      EventoServicio.fromJson({
        'id': 'e1',
        'tipo': 'INICIO_EJECUCION',
        'registradoEn': '2026-10-27T15:00:00Z',
        'autor': {'id': 'u', 'rol': 'ALIADO'},
        'tieneEvidencia': false,
      }),
    ];
  }

  @override
  Future<EventoServicio> registrar(
    String solicitudId, {
    required TipoEventoAliado tipo,
    required String observacion,
    required String claveIdempotencia,
    FotoAdjunta? foto,
    DateTime? ocurridoEn,
  }) => throw UnimplementedError();

  @override
  Future<Uri> urlEvidencia(String solicitudId, String eventoId) async =>
      Uri.parse('https://firmada/$eventoId');
}

class _Mensajes implements FuenteMensajes {
  @override
  Future<List<Mensaje>> listar(String solicitudId, {String? despuesDe}) async =>
      const [];

  @override
  Future<void> enviar(
    String solicitudId,
    String contenido, {
    required String claveIdempotencia,
  }) async {}
}

class _Opener implements UrlOpener {
  @override
  Future<bool> abrir(Uri url) async => true;
}

class _SinFotos implements SelectorFotos {
  @override
  Future<List<ArchivoLocal>> seleccionar() async => const [];
}

void main() {
  late _Ejecucion ejecucion;
  late _Eventos eventos;
  late _Adiciones adiciones;
  final moduloM08 = _ModuloM08();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'clave-de-prueba',
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _PkceEnMemoria(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
    ejecucion = _Ejecucion();
    eventos = _Eventos();
    adiciones = _Adiciones();
    sl.registerSingleton<FuenteCotizaciones>(_Cotizaciones());
    sl.registerSingleton<FuenteModuloM08>(moduloM08);
    sl.registerSingleton<FuenteTarifas>(_Tarifas());
    sl.registerSingleton<FuenteEjecucion>(ejecucion);
    sl.registerSingleton<FuenteAdiciones>(adiciones);
    sl.registerSingleton<FuenteEventos>(eventos);
    sl.registerSingleton<FuenteMensajes>(_Mensajes());
    sl.registerSingleton<UrlOpener>(_Opener());
    sl.registerSingleton<SelectorFotos>(_SinFotos());
  });

  tearDownAll(sl.reset);

  GoRoute ruta(String nombre) => [
    for (final b
        in appRouter.configuration.routes
            .whereType<StatefulShellRoute>()
            .single
            .branches)
      ...b.routes.whereType<GoRoute>(),
  ].singleWhere((r) => r.name == nombre);

  Future<void> montar(WidgetTester tester, String nombre) async {
    final r = ruta(nombre);
    final ubicacion = r.path.replaceAll(':id', 'sol-1');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => r.builder!(
              context,
              GoRouterState(
                appRouter.configuration,
                uri: Uri.parse(ubicacion),
                matchedLocation: ubicacion,
                fullPath: r.path,
                pathParameters: const {'id': 'sol-1'},
                pageKey: ValueKey(ubicacion),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('pantalla del servicio en columnas', () {
    const columnas = [
      Key('servicio-columna-pagos'),
      Key('servicio-columna-bitacora'),
      Key('servicio-columna-calificacion'),
    ];

    // La de calificación solo aparece si la fuente de M-08 está registrada.
    List<Offset> posiciones(WidgetTester tester) {
      final presentes = [
        for (final k in columnas)
          if (find.byKey(k).evaluate().isNotEmpty) k,
      ];
      expect(presentes.length, greaterThanOrEqualTo(2));
      expect(presentes.take(2), columnas.take(2));
      return [for (final k in presentes) tester.getTopLeft(find.byKey(k))];
    }

    void conTamano(WidgetTester tester, Size tamano) {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    for (final nombre in ['cotizacion-cliente', 'cotizacion-aliado']) {
      testWidgets('$nombre: en escritorio pagos, ejecución y bitácora, y '
          'calificación van lado a lado', (tester) async {
        conTamano(tester, const Size(1400, 1000));
        await montar(tester, nombre);

        final pos = posiciones(tester);
        for (var k = 1; k < pos.length; k++) {
          expect(pos[k - 1].dx < pos[k].dx, isTrue, reason: '$pos');
        }
        expect(pos.map((p) => p.dy).toSet(), hasLength(1));
        expect(find.byKey(const Key('btn-abrir-chat')), findsOneWidget);
      });
    }

    testWidgets('en móvil las columnas se apilan en el mismo orden', (
      tester,
    ) async {
      conTamano(tester, const Size(420, 900));
      await montar(tester, 'cotizacion-cliente');

      final pos = posiciones(tester);
      expect(pos.map((p) => p.dx).toSet(), hasLength(1));
      for (var k = 1; k < pos.length; k++) {
        expect(pos[k - 1].dy < pos[k].dy, isTrue, reason: '$pos');
      }
    });
  });
  // SCRUM-874, 875 y 1418: la calificación vive en la pantalla del servicio y
  // solo aparece con el servicio finalizado o cerrado.
  for (final (ruta, esAliado) in [
    ('cotizacion-cliente', false),
    ('cotizacion-aliado', true),
  ]) {
    testWidgets('$ruta: en ejecución no se ofrece calificar', (tester) async {
      moduloM08.estado = 'EN_EJECUCION';
      await montar(tester, ruta);
      expect(
        find.byKey(const Key('m08-calificacion-cierre-card')),
        findsNothing,
      );
      await _verHasta(tester, const Key('m08-calificacion-oculta'));
      expect(find.byKey(const Key('m08-calificacion-oculta')), findsOneWidget);
    });

    testWidgets('$ruta: con el servicio FINALIZADA aparece la calificación', (
      tester,
    ) async {
      moduloM08.estado = 'FINALIZADA';
      await montar(tester, ruta);
      await tester.scrollUntilVisible(
        find.byKey(const Key('m08-calificacion-cierre-card')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          esAliado
              ? 'Calificar al cliente y estado de cierre'
              : 'Calificar al aliado y estado de cierre',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('m08-estrella-5')), findsOneWidget);
      moduloM08.estado = 'EN_EJECUCION';
    });
  }

  testWidgets('el aliado ve cotización, ejecución y bitácora con formulario '
      'mientras el servicio está en ejecución', (tester) async {
    await montar(tester, 'cotizacion-aliado');

    // SCRUM-886: la tarifa de referencia vigente se ve al cotizar.
    expect(find.byKey(const Key('referencia-disponible')), findsOneWidget);
    expect(find.text('\$ 80.000,00 – \$ 180.000,00 COP'), findsOneWidget);
    expect(find.byKey(const Key('cotizacion-v1')), findsOneWidget);
    // SCRUM-866: bajo la cotización vigente, la alerta de tarifa de Rules.
    expect(find.byKey(const Key('alerta-tarifa-debajo')), findsOneWidget);
    await _verHasta(tester, const Key('seccion-ejecucion'));
    expect(find.byKey(const Key('seccion-ejecucion')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('seccion-adiciones')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('btn-pedir-adicion')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('seccion-eventos')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('btn-registrar-evento')), findsOneWidget);
  });

  testWidgets('el cliente ve la bitácora sin formulario y al deslizar se '
      'recargan la ejecución y los eventos', (tester) async {
    await montar(tester, 'cotizacion-cliente');
    await tester.scrollUntilVisible(
      find.byKey(const Key('seccion-eventos')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('evento-e1')), findsOneWidget);
    expect(find.byKey(const Key('btn-registrar-evento')), findsNothing);

    // RefreshIndicator solo se arma si el gesto empieza arriba. La lista lleva el botón de pago (SCRUM-1432)
    // y la sección de adiciones (SCRUM-872), así que primero se vuelve al inicio, hasta ver la cotización.
    await tester.scrollUntilVisible(
      find.byKey(const Key('cotizacion-v1')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    // El gesto de recargar solo se arma desde el borde superior.
    tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SingleChildScrollView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();

    final antesEjecucion = ejecucion.consultas;
    final antesEventos = eventos.consultas;
    final antesAdiciones = adiciones.consultas;
    await tester.fling(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 2000),
      2000,
    );
    await tester.pumpAndSettle();
    expect(ejecucion.consultas, greaterThan(antesEjecucion));
    expect(eventos.consultas, greaterThan(antesEventos));
    expect(adiciones.consultas, greaterThan(antesAdiciones));
  });

  GoRouterState estado(GoRoute r, String ubicacion) => GoRouterState(
    appRouter.configuration,
    uri: Uri.parse(ubicacion),
    matchedLocation: ubicacion,
    fullPath: r.path,
    pathParameters: const {'id': 'sol-1'},
    pageKey: ValueKey(ubicacion),
  );

  testWidgets('el cliente paga el total vigente: cotización + adiciones '
      'aceptadas (SCRUM-872)', (tester) async {
    final r = ruta('cotizacion-cliente');
    Object? extra;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) =>
              Scaffold(body: r.builder!(context, estado(r, '/ignorada'))),
        ),
        GoRoute(
          path: '/cliente/pagos/:cotizacionId',
          builder: (_, s) {
            extra = s.extra;
            return const Text('pantalla de pago');
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await _verHasta(tester, const Key('btn-pagar-cotizacion'));
    await tester.tap(find.byKey(const Key('btn-pagar-cotizacion')));
    await tester.pumpAndSettle();

    expect(find.text('pantalla de pago'), findsOneWidget);
    expect(extra, 130.0);
  });

  // SCRUM-881: cada participante entra al chat del servicio desde la pantalla del servicio.
  for (final (nombre, destino, etiqueta) in [
    (
      'cotizacion-cliente',
      '/cliente/solicitudes/sol-1/chat',
      'Mensajes con el aliado',
    ),
    (
      'cotizacion-aliado',
      '/aliado/solicitudes/sol-1/chat',
      'Mensajes con el cliente',
    ),
  ]) {
    testWidgets('$nombre: el botón de mensajes abre $destino', (tester) async {
      final r = ruta(nombre);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) =>
                Scaffold(body: r.builder!(context, estado(r, '/ignorada'))),
          ),
          GoRoute(
            path: destino,
            builder: (_, _) => const Text('pantalla de chat'),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await _verHasta(tester, const Key('btn-abrir-chat'));
      expect(find.text(etiqueta), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn-abrir-chat')));
      await tester.pumpAndSettle();

      expect(find.text('pantalla de chat'), findsOneWidget);
    });
  }

  for (final nombre in ['chat-cliente', 'chat-aliado']) {
    testWidgets('$nombre arma la pantalla del chat con su Cubit', (
      tester,
    ) async {
      final r = ruta(nombre);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => r.builder!(context, estado(r, r.path)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChatPage), findsOneWidget);
      expect(find.byKey(const Key('chat-vacio')), findsOneWidget);
    });
  }
}

/// La lista solo construye lo que cabe en pantalla; la alerta de tarifa
/// (SCRUM-866) baja las secciones siguientes, así que se desplaza hasta ellas.
Future<void> _verHasta(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}
