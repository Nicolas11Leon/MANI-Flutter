import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/features/asignacion/domain/entities/motivo_rechazo.dart';
import 'package:mani/features/asignacion/domain/entities/regla_sitio.dart';
import 'package:mani/features/asignacion/domain/entities/solicitud_entity.dart';
import 'package:mani/features/asignacion/domain/failures/asignacion_failure.dart';
import 'package:mani/features/asignacion/presentation/pages/solicitudes_aliado_page.dart';

import '../fakes.dart';

const _movil = Size(420, 900);
const _escritorio = Size(1300, 900);

Future<void> _montar(
  WidgetTester t,
  FakeAsignacionRepository repo, {
  Size tamano = _movil,
  VoidCallback? onAbrirCobertura,
  VoidCallback? onAbrirCategorias,
}) async {
  t.view.physicalSize = tamano;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  final cubit = crearCubit(repo);
  addTearDown(cubit.close);
  await t.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: SolicitudesAliadoPage(
          intervaloRefresco: null,
          onAbrirCobertura: onAbrirCobertura,
          onAbrirCategorias: onAbrirCategorias,
        ),
      ),
    ),
  );
  await cubit.cargar();
  await t.pumpAndSettle();
}

Future<void> _tocar(WidgetTester t, Key key) async {
  await t.ensureVisible(find.byKey(key));
  await t.pumpAndSettle();
  await t.tap(find.byKey(key));
  await t.pumpAndSettle();
}

FakeAsignacionRepository _repoBase() => FakeAsignacionRepository([
  solicitud(
    's1',
    categoria: 'Plomería',
    minutosAtras: 45,
    reglas: const [
      ReglaSitio('mascotas', true),
      ReglaSitio('parqueadero', false),
      ReglaSitio('horario_acceso', '8-17'),
    ],
  ),
  solicitud('s2', categoria: 'Electricidad', minutosAtras: 3),
]);

class _RepoQueCuenta extends FakeAsignacionRepository {
  _RepoQueCuenta() : super([solicitud('s1', categoria: 'Plomería')]);

  int listados = 0;

  @override
  Future<List<SolicitudEntity>> listar() {
    listados++;
    return super.listar();
  }
}

void main() {
  testWidgets('con la bandeja oculta no consulta; al volver se pone al día', (
    t,
  ) async {
    final repo = _RepoQueCuenta();
    final cubit = crearCubit(repo);
    addTearDown(cubit.close);
    Widget arbol({required bool seVe}) => MaterialApp(
      home: TickerMode(
        enabled: seVe,
        child: BlocProvider.value(
          value: cubit,
          child: const SolicitudesAliadoPage(
            intervaloRefresco: Duration(seconds: 30),
          ),
        ),
      ),
    );

    await t.pumpWidget(arbol(seVe: true));
    await t.pump(const Duration(seconds: 61));
    expect(repo.listados, 2, reason: 'a la vista consulta cada 30 s');

    await t.pumpWidget(arbol(seVe: false));
    await t.pump(const Duration(minutes: 10));
    expect(repo.listados, 2, reason: 'oculta no gasta consultas');

    await t.pumpWidget(arbol(seVe: true));
    await t.pump();
    expect(repo.listados, 3, reason: 'al volver consulta de una vez');
    await t.pump(const Duration(seconds: 31));
    expect(repo.listados, 4, reason: 'y retoma el ciclo');

    await t.pumpWidget(const SizedBox());
  });

  testWidgets('muestra las solicitudes disponibles con conteos y la regla', (
    t,
  ) async {
    await _montar(t, _repoBase());

    // En celular el título lo pinta la barra del armazón; la pantalla solo se lo declara.
    await t.pump();
    expect(titulosDePantalla.actual, 'Solicitudes');
    expect(find.bySemanticsLabel('Disponibles: 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Mis trabajos: 0'), findsOneWidget);
    expect(
      find.textContaining('el primero en aceptar se queda con el trabajo'),
      findsOneWidget,
    );
    expect(find.text('Plomería'), findsOneWidget);
    expect(find.text('Electricidad'), findsOneWidget);
  });

  testWidgets(
    'antes de aceptar muestra zona, modalidad y TODAS las reglas del sitio, '
    'pero no la dirección',
    (t) async {
      await _montar(t, _repoBase());

      expect(find.text('Roma Norte · Cuauhtémoc'), findsNWidgets(2));
      expect(
        find.text('Requiere cotización antes de empezar'),
        findsNWidgets(2),
      );
      expect(find.text('Hay mascotas'), findsOneWidget);
      expect(find.text('Sin parqueadero'), findsOneWidget);
      expect(find.text('Horario acceso: 8-17'), findsOneWidget);
      expect(find.byKey(const ValueKey('direccion-solicitud')), findsNothing);
    },
  );

  testWidgets(
    'muestra el problema descrito por el cliente y sus fotos (US-04.1.1)',
    (t) async {
      await _montar(
        t,
        FakeAsignacionRepository([
          solicitud(
            's1',
            descripcion: 'Gotea la llave del lavamanos desde ayer.',
            cantidadFotos: 2,
          ),
          solicitud('s2'),
        ]),
      );

      expect(
        find.text('Gotea la llave del lavamanos desde ayer.'),
        findsOneWidget,
      );
      expect(find.text('2 fotos adjuntas'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('problema-solicitud')),
        findsOneWidget,
        reason: 'sin descripción no se muestra el recuadro',
      );
    },
  );

  testWidgets('marca como urgente a quien espera 30+ minutos', (t) async {
    await _montar(t, _repoBase());

    expect(find.text('Solicitada hace 45 min'), findsOneWidget);
    expect(find.text('Solicitada hace 3 min'), findsOneWidget);
  });

  testWidgets(
    'aceptar asegura el trabajo, pasa a Mis trabajos y revela la dirección',
    (t) async {
      final repo = _repoBase();
      await _montar(t, repo);

      await _tocar(t, const ValueKey('btn-aceptar-s1'));

      expect(repo.porId('s1')?.esMia, isTrue);
      expect(find.bySemanticsLabel('Mis trabajos: 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Disponibles: 1'), findsOneWidget);
      expect(find.text('NUEVA'), findsOneWidget);
      expect(find.byKey(const ValueKey('direccion-solicitud')), findsOneWidget);
      expect(find.text('Calle Colima 120, Apto 401'), findsOneWidget);
      expect(find.textContaining('es tuya'), findsOneWidget);
    },
  );

  testWidgets('si otro aliado ganó, la tarjeta desaparece y se explica', (
    t,
  ) async {
    final repo = _repoBase();
    await _montar(t, repo);
    repo.tomadaPorOtroAliado('s1');

    await _tocar(t, const ValueKey('btn-aceptar-s1'));

    expect(find.byKey(const ValueKey('card-solicitud-s1')), findsNothing);
    expect(find.textContaining('Otro aliado tomó'), findsOneWidget);
    expect(find.bySemanticsLabel('Disponibles: 1'), findsOneWidget);
  });

  testWidgets('rechazar pide confirmación y un motivo obligatorio', (t) async {
    final repo = _repoBase();
    await _montar(t, repo);

    await _tocar(t, const ValueKey('btn-rechazar-s2'));
    expect(find.text('¿Rechazar Electricidad?'), findsOneWidget);
    expect(find.textContaining('Seguirá disponible'), findsOneWidget);
    expect(find.text('¿Por qué la rechazas?'), findsOneWidget);
    for (final etiqueta in [
      'No estoy disponible',
      'Fuera de mi zona',
      'No hago este tipo de trabajo',
      'Otro',
    ]) {
      expect(find.text(etiqueta), findsOneWidget);
    }

    // Sin motivo, «Rechazar» está deshabilitado: tocarlo no rechaza nada.
    expect(find.byKey(const ValueKey('rechazo-sin-motivo')), findsOneWidget);
    await _tocar(t, const ValueKey('dlg-confirmar-rechazo'));
    expect(repo.llamadasRechazar, 0);
    expect(find.text('¿Rechazar Electricidad?'), findsOneWidget);

    await _tocar(t, const ValueKey('motivo-SIN_DISPONIBILIDAD'));
    await _tocar(t, const ValueKey('dlg-confirmar-rechazo'));

    expect(repo.rechazadas['s2'], MotivoRechazo.sinDisponibilidad);
    expect(repo.detallesRechazo['s2'], isNull);
    expect(find.byKey(const ValueKey('card-solicitud-s2')), findsNothing);
    expect(find.textContaining('Solicitud descartada'), findsOneWidget);
  });

  testWidgets(
    '«Otro» pide el texto y no deja rechazar hasta tener 3 caracteres',
    (t) async {
      final repo = _repoBase();
      await _montar(t, repo);

      await _tocar(t, const ValueKey('btn-rechazar-s2'));
      expect(find.byKey(const ValueKey('detalle-rechazo')), findsNothing);

      await _tocar(t, const ValueKey('motivo-OTRO'));
      expect(find.byKey(const ValueKey('detalle-rechazo')), findsOneWidget);

      await t.enterText(find.byKey(const ValueKey('detalle-rechazo')), 'no');
      await t.pump();
      await _tocar(t, const ValueKey('dlg-confirmar-rechazo'));
      expect(repo.llamadasRechazar, 0);

      await t.enterText(
        find.byKey(const ValueKey('detalle-rechazo')),
        '  Mi herramienta está en reparación ',
      );
      await t.pump();
      await _tocar(t, const ValueKey('dlg-confirmar-rechazo'));

      expect(repo.rechazadas['s2'], MotivoRechazo.otro);
      expect(repo.detallesRechazo['s2'], 'Mi herramienta está en reparación');
      expect(find.byKey(const ValueKey('card-solicitud-s2')), findsNothing);
    },
  );

  testWidgets('cambiar de «Otro» a otro motivo no envía el texto escrito', (
    t,
  ) async {
    final repo = _repoBase();
    await _montar(t, repo);

    await _tocar(t, const ValueKey('btn-rechazar-s2'));
    await _tocar(t, const ValueKey('motivo-OTRO'));
    await t.enterText(
      find.byKey(const ValueKey('detalle-rechazo')),
      'Texto escrito',
    );
    await t.pump();
    await _tocar(t, const ValueKey('motivo-FUERA_DE_ZONA'));
    expect(find.byKey(const ValueKey('detalle-rechazo')), findsNothing);
    await _tocar(t, const ValueKey('dlg-confirmar-rechazo'));

    expect(repo.rechazadas['s2'], MotivoRechazo.fueraDeZona);
    expect(repo.detallesRechazo['s2'], isNull);
  });

  testWidgets('volver del diálogo no rechaza nada', (t) async {
    final repo = _repoBase();
    await _montar(t, repo);

    await _tocar(t, const ValueKey('btn-rechazar-s2'));
    await _tocar(t, const ValueKey('dlg-cancelar-rechazo'));

    expect(repo.llamadasRechazar, 0);
    expect(find.byKey(const ValueKey('card-solicitud-s2')), findsOneWidget);
  });

  testWidgets('mientras acepta, deshabilita las demás acciones', (t) async {
    final repo = _repoBase()..pausa = Completer<void>();
    await _montar(t, repo);

    await t.tap(find.byKey(const ValueKey('btn-aceptar-s1')));
    await t.pump();

    expect(find.text('Asegurando…'), findsOneWidget);
    final otro = t.widget<ManiButton>(
      find.byKey(const ValueKey('btn-aceptar-s2')),
    );
    expect(otro.onPressed, isNull);

    repo.pausa!.complete();
    await t.pumpAndSettle();
  });

  testWidgets('sin solicitudes invita a revisar zonas y especialidades', (
    t,
  ) async {
    var zonas = 0;
    var especialidades = 0;
    await _montar(
      t,
      FakeAsignacionRepository(),
      onAbrirCobertura: () => zonas++,
      onAbrirCategorias: () => especialidades++,
    );

    expect(find.text('No hay solicitudes nuevas'), findsOneWidget);
    await _tocar(t, const ValueKey('btn-vacio-cobertura'));
    await _tocar(t, const ValueKey('btn-vacio-categorias'));
    expect((zonas, especialidades), (1, 1));
  });

  testWidgets('un aliado en revisión ve por qué no puede tomar trabajos', (
    t,
  ) async {
    final repo = _repoBase()
      ..fallarAlListar = const AsignacionFailure(
        AsignacionErrorTipo.aliadoNoVerificado,
      );
    await _montar(t, repo);

    expect(
      find.textContaining('Tu registro aún está en revisión'),
      findsOneWidget,
    );

    repo.fallarAlListar = null;
    await _tocar(t, const ValueKey('btn-reintentar-solicitudes'));
    expect(find.text('Plomería'), findsOneWidget);
  });

  testWidgets('en escritorio la lista se centra con ancho legible', (t) async {
    await _montar(t, _repoBase(), tamano: _escritorio);

    final ancho = t.getSize(find.byKey(const ValueKey('card-solicitud-s1')));
    expect(ancho.width, lessThanOrEqualTo(760));
  });

  group('SCRUM-1388: reglas del sitio en la tarjeta', () {
    const reglas = [
      ReglaSitio('contactoAcceso', {
        'nombre': 'Portería',
        'telefono': '3000000000',
      }),
      ReglaSitio('elementosProteccion', ['Casco']),
      ReglaSitio('horario', {
        'inicio': '08:00',
        'fin': '17:00',
        'diasPermitidos': ['LUN', 'MAR', 'MIE', 'JUE', 'VIE'],
      }),
      ReglaSitio('instruccionesIngreso', 'Pedir llave en recepción'),
      ReglaSitio('permisosRequeridos', ['ARL']),
    ];

    testWidgets('en la oferta: requisitos legibles, sin contacto ni ingreso', (
      t,
    ) async {
      await _montar(
        t,
        FakeAsignacionRepository([solicitud('o1', reglas: reglas)]),
      );

      expect(
        find.text('Horario: lunes a viernes, de 8:00 a 17:00'),
        findsOneWidget,
      );
      expect(find.text('Protección obligatoria: Casco'), findsOneWidget);
      expect(find.text('Permisos requeridos: ARL'), findsOneWidget);
      expect(find.textContaining('Contacto de acceso'), findsNothing);
      expect(find.textContaining('Instrucciones de ingreso'), findsNothing);
      expect(find.textContaining('{'), findsNothing, reason: 'sin JSON');
    });

    testWidgets('asignada: también el contacto y las instrucciones', (t) async {
      await _montar(
        t,
        FakeAsignacionRepository([
          solicitud(
            'a1',
            estado: EstadoSolicitud.asignada,
            esMia: true,
            reglas: reglas,
            direccion: 'Calle 1 # 2-3',
          ),
        ]),
      );
      await _tocar(t, const ValueKey('tab-misTrabajos'));

      expect(
        find.text('Contacto de acceso: Portería · 3000000000'),
        findsOneWidget,
      );
      expect(
        find.text('Instrucciones de ingreso: Pedir llave en recepción'),
        findsOneWidget,
      );
      expect(find.text('Protección obligatoria: Casco'), findsOneWidget);
    });
  });

  test('las solicitudes asignadas no ofrecen acciones', () {
    final s = solicitud('x', estado: EstadoSolicitud.asignada, esMia: true);
    expect(s.estaDisponible, isFalse);
  });
}
