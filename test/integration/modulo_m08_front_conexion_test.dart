import 'dart:async';
// Prueba maestra frontend de la conexión del módulo M-08 que QA devolvió (SCRUM-874, 875, 1418, 878, 879 y 880): cada
// historia se recorre en la pantalla real, con una fuente en memoria que responde como Core (cierre automático cuando
// califican los dos, MANI-CAL-409D al repetir). Lo que se prueba es que la app ofrece cada flujo y muestra lo que
// devuelve Core; las reglas definitivas se prueban contra PostgreSQL en MANI-Node (moduloM08.pg.test.js).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/session/guardas_ruta.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/menu_por_rol.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/features/services/ratings/data/calificacion_cierre_datasource.dart';
import 'package:mani/features/services/ratings/data/politica_cancelacion_datasource.dart';
import 'package:mani/features/services/ratings/domain/calificacion_cierre_modelos.dart';
import 'package:mani/features/services/ratings/presentation/calificacion_cierre_cubit.dart';
import 'package:mani/features/services/ratings/presentation/calificacion_cierre_widgets.dart';
import 'package:mani/features/services/ratings/presentation/politica_cancelacion_page.dart';
import 'package:mani/features/services/tracking/data/seguimiento_datasource.dart';
import 'package:mani/features/services/tracking/domain/solicitud_seguimiento.dart';
import 'package:mani/features/services/tracking/presentation/mis_solicitudes_cubit.dart';
import 'package:mani/features/services/tracking/presentation/mis_solicitudes_page.dart';

const _sol = 'sol-1';

CalificacionServicio _calif(String rol, int puntaje) => CalificacionServicio(
  id: 'cal-$rol',
  solicitudId: _sol,
  autorId: rol == 'CLIENT' ? 'u-cliente' : 'u-aliado',
  destinatarioId: rol == 'CLIENT' ? 'u-aliado' : 'u-cliente',
  rolAutor: rol,
  puntaje: puntaje,
  creadaEn: DateTime(2026, 11, 4),
);

/// Core en memoria para una solicitud FINALIZADA: cada parte califica una vez y, cuando califica la segunda, la
/// solicitud pasa a CERRADA (PgRatingsRepository). La fuente se comparte entre la sesión del cliente y la del aliado.
class _CoreM08 implements FuenteModuloM08 {
  String estado = 'FINALIZADA';
  CalificacionServicio? cliente;
  CalificacionServicio? aliado;
  String rolSesion = 'CLIENT';

  EstadoCierreSolicitud get _cierre => EstadoCierreSolicitud(
    cerrada: estado == 'CERRADA',
    estadoSolicitud: estado,
    tieneCalificacionCliente: cliente != null,
    tieneCalificacionAliado: aliado != null,
    pendientes: [if (cliente == null) 'CLIENTE', if (aliado == null) 'ALIADO'],
  );

  @override
  Future<ResumenCalificacionesSolicitud> obtenerCalificaciones(
    String solicitudId,
  ) async => ResumenCalificacionesSolicitud(
    solicitudId: solicitudId,
    estado: estado,
    cierre: _cierre,
    clienteAAliado: cliente,
    aliadoACliente: aliado,
  );

  @override
  Future<ResumenCalificacionesSolicitud> registrarCalificacion({
    required String solicitudId,
    required int puntaje,
    String? comentario,
  }) async {
    final esCliente = rolSesion == 'CLIENT';
    if ((esCliente ? cliente : aliado) != null) {
      throw const ModuloM08Failure(ModuloM08ErrorTipo.calificacionDuplicada);
    }
    if (esCliente) {
      cliente = _calif('CLIENT', puntaje);
    } else {
      aliado = _calif('ALLY', puntaje);
    }
    if (cliente != null && aliado != null) estado = 'CERRADA';
    return obtenerCalificaciones(solicitudId);
  }

  @override
  Future<EstadoCierreSolicitud> cerrarSolicitud(String solicitudId) async {
    if (cliente == null || aliado == null) {
      throw const ModuloM08Failure(ModuloM08ErrorTipo.cierreIncompleto);
    }
    return _cierre;
  }

  final historial = <RegistroHistorialServicio>[];

  @override
  Future<List<RegistroHistorialServicio>> listarHistorialCliente() async =>
      historial;

  @override
  Future<List<RegistroHistorialServicio>> listarHistorialAliado() async =>
      historial;

  VistaPreviaPenalizacion? preview;

  @override
  Future<VistaPreviaPenalizacion> previsualizarCancelacion(
    String solicitudId,
  ) async => preview!;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Cuenta las lecturas de calificaciones y puede fallar a pedido.
class _CoreContado extends _CoreM08 {
  int lecturas = 0;
  bool falla = false;

  /// Si está puesta, la lectura devuelve lo que había al consultar pero tarda
  /// hasta que se abra.
  Completer<void>? compuerta;

  @override
  Future<ResumenCalificacionesSolicitud> obtenerCalificaciones(
    String solicitudId,
  ) async {
    final c = compuerta;
    lecturas++;
    if (falla) {
      throw const ModuloM08Failure(ModuloM08ErrorTipo.desconocido);
    }
    final foto = await super.obtenerCalificaciones(solicitudId);
    if (c != null) await c.future;
    return foto;
  }
}

class _Politicas implements FuentePoliticaCancelacion {
  PoliticaCancelacion actual = const PoliticaCancelacion(
    activa: false,
    ventanaGratuitaMinutos: 15,
    tipoCobro: TipoCobroPenalizacion.montoFijo,
    valor: 0,
  );
  final guardadas = <PoliticaCancelacion>[];

  @override
  Future<PoliticaCancelacion> obtener() async => actual;

  @override
  Future<PoliticaCancelacion> guardar(PoliticaCancelacion politica) async {
    guardadas.add(politica);
    return actual = PoliticaCancelacion(
      activa: politica.activa,
      ventanaGratuitaMinutos: politica.ventanaGratuitaMinutos,
      tipoCobro: politica.tipoCobro,
      valor: politica.valor,
      configurada: true,
    );
  }
}

class _Seguimiento implements FuenteSeguimiento {
  _Seguimiento(this.solicitudes);

  final List<SolicitudSeguimiento> solicitudes;
  final cancelaciones = <String>[];

  @override
  Future<List<SolicitudSeguimiento>> listar() async => solicitudes;

  @override
  Future<SolicitudSeguimiento> cancelar(
    String solicitudId, {
    String? motivo,
  }) async {
    cancelaciones.add(solicitudId);
    return SolicitudSeguimiento.fromJson({
      'id': solicitudId,
      'estado': 'CANCELADA',
      'categoria': 'Plomería',
      'zonaDeclarada': {'nombre': 'Chapinero'},
      'actualizadaEn': '2026-11-04T10:00:00Z',
    });
  }
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _seccion(_CoreM08 core, {required bool esAliado}) => _app(
  BlocProvider(
    create: (_) => CalificacionCierreCubit(core, solicitudId: _sol)..cargar(),
    child: SingleChildScrollView(
      child: CalificacionServicioFinalizado(esAliado: esAliado),
    ),
  ),
);

Future<void> _calificar(WidgetTester tester, int estrellas) async {
  await tester.tap(find.byKey(Key('m08-estrella-$estrellas')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('m08-enviar-calificacion-btn')));
  await tester.pumpAndSettle();
}

void main() {
  // ============================================================== SCRUM-874 / 875 / 1418
  group('874, 875 y 1418 · calificación bidireccional y cierre', () {
    testWidgets(
      'C1: el cliente califica; la solicitud sigue FINALIZADA y pendiente del aliado',
      (tester) async {
        final core = _CoreM08();
        await tester.pumpWidget(_seccion(core, esAliado: false));
        await tester.pumpAndSettle();
        expect(
          find.text('Pendiente de calificación de cliente y aliado'),
          findsOneWidget,
        );

        await _calificar(tester, 5);

        expect(core.cliente!.puntaje, 5);
        expect(
          core.estado,
          'FINALIZADA',
          reason: 'con una sola calificación no se cierra',
        );
        expect(find.text('Tu calificación enviada: ★ 5/5'), findsOneWidget);
        expect(
          find.text('Pendiente de calificación del aliado'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Pendiente la calificación de la otra parte'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '1418 C1: cuando el aliado califica después, la solicitud pasa a CERRADA',
      (tester) async {
        final core = _CoreM08()..cliente = _calif('CLIENT', 5);
        core.rolSesion = 'ALLY';
        await tester.pumpWidget(_seccion(core, esAliado: true));
        await tester.pumpAndSettle();
        // La calificación del cliente es privada: el aliado sabe que existe
        // pero no ve el puntaje, aunque la respuesta lo trajera.
        expect(find.textContaining('5/5'), findsNothing);
        expect(
          find.text('El cliente ya registró su calificación.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('m08-aviso-calificacion-privada')),
          findsOneWidget,
        );

        await _calificar(tester, 4);

        expect(core.estado, 'CERRADA');
        expect(
          find.text('Cerrada (ambas calificaciones registradas)'),
          findsOneWidget,
        );
        expect(
          find.text('Calificación registrada. El servicio quedó cerrado.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '1418 C2: verificar el cierre con una sola calificación lo rechaza Core y no cierra',
      (tester) async {
        final core = _CoreM08()..cliente = _calif('CLIENT', 3);
        await tester.pumpWidget(_seccion(core, esAliado: false));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('m08-cerrar-solicitud-btn')));
        await tester.pumpAndSettle();

        expect(core.estado, 'FINALIZADA');
        expect(find.byKey(const Key('m08-calificacion-error')), findsOneWidget);
        expect(
          find.textContaining('no puede declararse cerrado'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '874/875 C2: sin estrellas no se envía y, ya calificado, no se ofrece calificar otra vez',
      (tester) async {
        final core = _CoreM08();
        await tester.pumpWidget(_seccion(core, esAliado: false));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('m08-enviar-calificacion-btn')));
        await tester.pumpAndSettle();
        expect(core.cliente, isNull);
        expect(
          find.text(
            'Selecciona una calificación válida entre 1 y 5 estrellas.',
          ),
          findsOneWidget,
        );

        await _calificar(tester, 2);
        expect(
          find.byKey(const Key('m08-enviar-calificacion-btn')),
          findsNothing,
        );
      },
    );

    testWidgets('no se muestra mientras el servicio no ha finalizado', (
      tester,
    ) async {
      final core = _CoreM08()..estado = 'EN_EJECUCION';
      await tester.pumpWidget(_seccion(core, esAliado: false));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('m08-calificacion-cierre-card')),
        findsNothing,
      );
    });
  });

  // ============================================================== SCRUM-879 / 880
  group('879 y 880 · historial con ruta, menú y guarda de rol', () {
    RegistroHistorialServicio registro(
      String id,
      String estado, {
      CalificacionServicio? emitida,
    }) => RegistroHistorialServicio(
      id: id,
      estado: estado,
      categoriaId: 'cat-1',
      categoria: 'Plomería',
      descripcion: 'Fuga en el baño',
      direccion: 'Calle 1',
      zona: 'Chapinero',
      creadaEn: DateTime(2026, 11, 1),
      nombreContraparte: 'Ana',
      calificacionEmitida: emitida,
    );

    testWidgets(
      'el cliente ve su historial y abre el servicio finalizado para calificarlo',
      (tester) async {
        final core = _CoreM08()
          ..historial.addAll([
            registro('sol-a', 'FINALIZADA'),
            registro('sol-b', 'CERRADA', emitida: _calif('CLIENT', 4)),
          ]);
        final abiertos = <String>[];
        await tester.pumpWidget(
          _app(
            BlocProvider(
              create: (_) =>
                  HistorialServiciosCubit(core, esAliado: false)..cargar(),
              child: HistorialServiciosPage(onAbrirServicio: abiertos.add),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Historial de servicios'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('m08-historial-abrir-sol-a')),
            matching: find.text('Calificar servicio'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('m08-historial-abrir-sol-b')),
            matching: find.text('Ver servicio'),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('m08-historial-abrir-sol-a')));
        expect(abiertos, ['sol-a']);
      },
    );

    testWidgets(
      'el aliado ve «Historial de trabajos» y un historial vacío lo dice',
      (tester) async {
        await tester.pumpWidget(
          _app(
            BlocProvider(
              create: (_) =>
                  HistorialServiciosCubit(_CoreM08(), esAliado: true)..cargar(),
              child: const HistorialServiciosPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Historial de trabajos'), findsOneWidget);
        expect(find.byKey(const Key('m08-historial-vacio')), findsOneWidget);
      },
    );

    test(
      'cada rol tiene su historial en el menú y no puede abrir el del otro',
      () {
        expect(
          entradasMenuPara(RolUsuario.cliente).map((e) => e.ruta),
          contains('/cliente/historial'),
        );
        expect(
          entradasMenuPara(RolUsuario.aliado).map((e) => e.ruta),
          contains('/aliado/historial'),
        );
        expect(rolPuedeAbrir(RolUsuario.cliente, '/cliente/historial'), isTrue);
        expect(rolPuedeAbrir(RolUsuario.aliado, '/aliado/historial'), isTrue);
        expect(rolPuedeAbrir(RolUsuario.aliado, '/cliente/historial'), isFalse);
        expect(rolPuedeAbrir(RolUsuario.cliente, '/aliado/historial'), isFalse);
        expect(
          rolPuedeAbrir(RolUsuario.adminTenant, '/cliente/historial'),
          isFalse,
        );
      },
    );
  });

  // ============================================================== SCRUM-878
  group('878 · penalización por cancelación tardía', () {
    SolicitudSeguimiento asignada() => SolicitudSeguimiento.fromJson({
      'id': _sol,
      'estado': 'ASIGNADA',
      'categoria': 'Plomería',
      'zonaDeclarada': {'nombre': 'Chapinero'},
      'actualizadaEn': '2026-11-04T10:00:00Z',
    });

    Future<_Seguimiento> abrirCancelacion(
      WidgetTester tester,
      _CoreM08 core,
    ) async {
      final fuente = _Seguimiento([asignada()]);
      await tester.pumpWidget(
        _app(
          BlocProvider(
            create: (_) => MisSolicitudesCubit(fuente)..cargar(),
            child: MisSolicitudesPage(
              previsualizarCancelacion: core.previsualizarCancelacion,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancelar-solicitud-$_sol')));
      await tester.pumpAndSettle();
      return fuente;
    }

    testWidgets(
      'C1: antes de confirmar, el cliente ve la penalización que calculó Core',
      (tester) async {
        final core = _CoreM08()
          ..preview = const VistaPreviaPenalizacion(
            solicitudId: _sol,
            estadoActual: 'ASIGNADA',
            cancelable: true,
            aplicaPenalizacion: true,
            montoPenalizacion: 20000,
            politicaActiva: true,
          );
        final fuente = await abrirCancelacion(tester, core);

        expect(
          find.byKey(const Key('m08-penalizacion-preview-banner')),
          findsOneWidget,
        );
        expect(
          find.text('Penalización por cancelación tardía: \$20000'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('cancelar-confirmar')));
        await tester.pumpAndSettle();
        expect(fuente.cancelaciones, [_sol]);
      },
    );

    testWidgets(
      'C2: sin política activa el resumen dice que no hay penalización',
      (tester) async {
        final core = _CoreM08()
          ..preview = const VistaPreviaPenalizacion(
            solicitudId: _sol,
            estadoActual: 'ASIGNADA',
            cancelable: true,
            aplicaPenalizacion: false,
            montoPenalizacion: 0,
            politicaActiva: false,
          );
        await abrirCancelacion(tester, core);
        expect(
          find.text('Sin penalización por cancelación (\$0).'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'el admin activa la política con un porcentaje y la ve guardada; la desactiva después',
      (tester) async {
        final politicas = _Politicas();
        await tester.pumpWidget(
          _app(
            BlocProvider(
              create: (_) => PoliticaCancelacionCubit(politicas)..cargar(),
              child: const PoliticaCancelacionPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Desactivada'), findsOneWidget);

        await tester.tap(find.byKey(const Key('politica-activa')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('politica-tipo')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Porcentaje de la cotización').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('politica-ventana')), '30');
        await tester.enterText(find.byKey(const Key('politica-valor')), '20');
        await tester.tap(find.byKey(const Key('politica-guardar')));
        await tester.pumpAndSettle();

        expect(politicas.guardadas.single.toJson(), {
          'activa': true,
          'ventanaGratuitaMinutos': 30,
          'tipoCobro': 'PORCENTAJE',
          'valor': 20.0,
        });
        expect(find.text('Activa'), findsOneWidget);
        expect(find.textContaining('Política activada'), findsOneWidget);

        await tester.tap(find.byKey(const Key('politica-activa')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('politica-guardar')));
        await tester.pumpAndSettle();
        expect(politicas.actual.activa, isFalse);
        expect(find.text('Desactivada'), findsOneWidget);
      },
    );

    testWidgets('un porcentaje mayor que 100 no se envía', (tester) async {
      final politicas = _Politicas();
      await tester.pumpWidget(
        _app(
          BlocProvider(
            create: (_) => PoliticaCancelacionCubit(politicas)..cargar(),
            child: const PoliticaCancelacionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('politica-tipo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Porcentaje de la cotización').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('politica-valor')), '150');
      await tester.tap(find.byKey(const Key('politica-guardar')));
      await tester.pumpAndSettle();
      expect(politicas.guardadas, isEmpty);
      expect(find.text('El porcentaje no puede superar 100.'), findsOneWidget);
      expect(
        tester
            .widget<ManiButton>(find.byKey(const Key('politica-guardar')))
            .onPressed,
        isNotNull,
      );
    });

    test('solo el admin del tenant tiene la opción en el menú y la ruta', () {
      expect(
        entradasMenuPara(RolUsuario.adminTenant).map((e) => e.ruta),
        contains('/admin/politica-cancelacion'),
      );
      expect(
        rolPuedeAbrir(RolUsuario.adminTenant, '/admin/politica-cancelacion'),
        isTrue,
      );
      expect(
        rolPuedeAbrir(RolUsuario.cliente, '/admin/politica-cancelacion'),
        isFalse,
      );
      expect(
        rolPuedeAbrir(RolUsuario.aliado, '/admin/politica-cancelacion'),
        isFalse,
      );
    });
  });

  group('SCRUM-1710 · sondeo de la calificación', () {
    test('el cliente ve que el aliado calificó y la solicitud se cerró, sin '
        'pasar por cargando', () async {
      final core = _CoreM08();
      final cliente = CalificacionCierreCubit(core, solicitudId: _sol);
      await cliente.cargar();
      await core.registrarCalificacion(solicitudId: _sol, puntaje: 5);
      core.rolSesion = 'ALLY';
      await core.registrarCalificacion(solicitudId: _sol, puntaje: 4);
      final estados = <CalificacionCierreState>[];
      final sub = cliente.stream.listen(estados.add);

      await cliente.cargar(silencioso: true);
      await Future<void>.delayed(Duration.zero);

      expect(cliente.state.resumen!.estado, 'CERRADA');
      expect(cliente.state.resumen!.aliadoACliente!.puntaje, 4);
      expect(estados.any((e) => e.cargando), isFalse);
      await sub.cancel();
      await cliente.close();
    });

    test('no borra el aviso visible ni consulta durante un envío', () async {
      final core = _CoreContado();
      final cubit = CalificacionCierreCubit(core, solicitudId: _sol);
      await cubit.cargar();
      await cubit.calificar(puntaje: 0);
      final error = cubit.state.error;
      expect(error, isNotNull);

      await cubit.cargar(silencioso: true);
      expect(cubit.state.error, error, reason: 'el aviso sigue a la vista');

      final lecturas = core.lecturas;
      final envio = cubit.calificar(puntaje: 5);
      await cubit.cargar(silencioso: true);
      await envio;
      // El envío lee 2 veces: dentro de registrarCalificacion (este Core en
      // memoria) y en la relectura de calificar. El sondeo no suma ninguna.
      expect(
        core.lecturas - lecturas,
        2,
        reason: 'el sondeo no consulta mientras se envía',
      );
      await cubit.close();
    });

    test('un fallo conserva lo que se ve sin mostrar error', () async {
      final core = _CoreContado();
      final cubit = CalificacionCierreCubit(core, solicitudId: _sol);
      await cubit.cargar();
      core.falla = true;

      await cubit.cargar(silencioso: true);

      expect(cubit.state.resumen, isNotNull);
      expect(cubit.state.error, isNull);
      await cubit.close();
    });
  });

  test('SCRUM-1710: una respuesta vieja del sondeo no deshace una '
      'calificación posterior', () async {
    final core = _CoreContado();
    final cubit = CalificacionCierreCubit(core, solicitudId: _sol);
    await cubit.cargar();

    core.compuerta = Completer<void>();
    final sondeo = cubit.cargar(silencioso: true);
    final compuerta = core.compuerta!;
    core.compuerta = null;
    expect(await cubit.calificar(puntaje: 5), isTrue);
    expect(cubit.state.resumen!.clienteAAliado, isNotNull);

    compuerta.complete();
    await sondeo;

    expect(cubit.state.resumen!.clienteAAliado, isNotNull);
    expect(cubit.state.mensajeExito, isNotNull);
    await cubit.close();
  });
}
