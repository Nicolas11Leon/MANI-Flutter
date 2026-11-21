import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/features/catalog/map/domain/entities/geometria_zona.dart';
import 'package:mani/features/catalog/map/presentation/bloc/mapa_cubit.dart';
import 'package:mani/features/profiles/coverage/presentation/controllers/cobertura_controller.dart';
import 'package:mani/features/profiles/coverage/presentation/pages/declarar_cobertura_page.dart';

import 'fakes.dart';

Widget _app(CoberturaController c) => MaterialApp(
  home: DeclararCoberturaPage(controller: c, debounce: Duration.zero),
);

FilledButton _botonGuardar(WidgetTester t) =>
    t.widget<FilledButton>(find.byKey(const ValueKey('btn-guardar-cobertura')));

void main() {
  testWidgets('muestra localidades y el botón Guardar inicia deshabilitado', (
    t,
  ) async {
    await t.pumpWidget(_app(CoberturaController(FakeCoberturaRepository())));
    await t.pumpAndSettle();

    expect(find.text('Toda Bogotá'), findsOneWidget);
    expect(find.text('Chapinero'), findsOneWidget);
    expect(find.text('Suba'), findsOneWidget);
    expect(find.text('Aún no has seleccionado zonas'), findsOneWidget);
    expect(_botonGuardar(t).onPressed, isNull);
  });

  testWidgets('seleccionar un barrio y guardar llama a la RPC con ese id', (
    t,
  ) async {
    final repo = FakeCoberturaRepository();
    await t.pumpWidget(_app(CoberturaController(repo)));
    await t.pumpAndSettle();

    await t.tap(find.text('Suba')); // expande y carga barrios
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('zona-niz')));
    await t.pump();

    expect(find.text('1 zona seleccionada'), findsOneWidget);
    expect(_botonGuardar(t).onPressed, isNotNull);

    await t.tap(find.byKey(const ValueKey('btn-guardar-cobertura')));
    await t.pumpAndSettle();

    expect(repo.ultimoEnvio, {'niz'});
    expect(find.textContaining('Cobertura guardada'), findsOneWidget);
  });

  testWidgets('localidad completa marca sus barrios como incluidos', (t) async {
    await t.pumpWidget(_app(CoberturaController(FakeCoberturaRepository())));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('grupo-check-cha')));
    await t.pump();
    // 'Chapinero' ya aparece también como chip; se expande tocando el subtítulo.
    await t.tap(find.text('Localidad completa'));
    await t.pumpAndSettle();

    expect(find.text('Incluida en Chapinero'), findsNWidgets(2));
  });

  testWidgets('la búsqueda muestra resultados con su ruta', (t) async {
    await t.pumpWidget(_app(CoberturaController(FakeCoberturaRepository())));
    await t.pumpAndSettle();

    await t.enterText(find.byKey(const ValueKey('buscar-zona')), 'ros');
    await t.pumpAndSettle();

    expect(find.text('Rosales'), findsOneWidget);
    expect(find.textContaining('Barrio · Chapinero · Bogotá'), findsOneWidget);
  });

  group('mapa dentro de la pantalla (HU-M04-07 / SCRUM-1396)', () {
    /// La pantalla con mapa necesita un `MapaCubit` en el contexto; se le da
    /// uno falso con una localidad dibujable que corresponde al catálogo.
    Widget conMapa(CoberturaController c, {required Size tamano}) =>
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: tamano),
            child: BlocProvider<MapaCubit>.value(
              value: _MapaFalso(
                MapaState(
                  estado: MapaEstado.listo,
                  geometrias: [
                    GeometriaZona(
                      zonaId: 'cha',
                      nombre: 'Chapinero',
                      nivel: 'LOCALIDAD',
                      anillos: _anilloPrueba,
                      atribucion: 'UAECD',
                    ),
                  ],
                ),
              ),
              child: DeclararCoberturaPage(
                controller: c,
                debounce: Duration.zero,
                conMapa: true,
              ),
            ),
          ),
        );

    testWidgets('en pantalla ancha el mapa va al lado de la lista', (t) async {
      t.view.physicalSize = const Size(1400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      await t.pumpWidget(
        conMapa(
          CoberturaController(FakeCoberturaRepository()),
          tamano: const Size(1400, 900),
        ),
      );
      await t.pumpAndSettle();

      expect(find.byKey(const Key('cobertura_mapa')), findsOneWidget);
      // Al lado: sin plegable y con la lista todavía visible.
      expect(find.byKey(const Key('cobertura_mapa_plegable')), findsNothing);
      expect(find.text('Chapinero'), findsWidgets);
    });

    testWidgets('en pantalla estrecha el mapa va plegado', (t) async {
      t.view.physicalSize = const Size(420, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      await t.pumpWidget(
        conMapa(
          CoberturaController(FakeCoberturaRepository()),
          tamano: const Size(420, 900),
        ),
      );
      await t.pumpAndSettle();

      // Plegado: un mapa fijo encima dejaría la lista de zonas sin sitio.
      expect(find.byKey(const Key('cobertura_mapa_plegable')), findsOneWidget);
      expect(find.text('Ver en el mapa'), findsOneWidget);
    });

    testWidgets('tocar una zona del mapa la agrega a la selección', (t) async {
      t.view.physicalSize = const Size(1400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final c = CoberturaController(FakeCoberturaRepository());
      await t.pumpWidget(conMapa(c, tamano: const Size(1400, 900)));
      await t.pumpAndSettle();

      expect(c.seleccion.ids, isEmpty);

      await t.tap(find.byKey(const Key('mapa_marca_Chapinero')));
      await t.pumpAndSettle();

      // Misma selección que daría marcar su casilla en la lista.
      expect(c.seleccion.ids, {'cha'});
      expect(_botonGuardar(t).onPressed, isNotNull);
    });

    testWidgets('volver a tocarla la quita', (t) async {
      t.view.physicalSize = const Size(1400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final c = CoberturaController(FakeCoberturaRepository());
      await t.pumpWidget(conMapa(c, tamano: const Size(1400, 900)));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('mapa_marca_Chapinero')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('mapa_marca_Chapinero')));
      await t.pumpAndSettle();

      expect(c.seleccion.ids, isEmpty);
    });

    testWidgets('mientras cargan las localidades muestra el indicador', (
      t,
    ) async {
      final repo = FakeCoberturaRepository()..esperaHijas = Completer<void>();
      await t.pumpWidget(
        conMapa(CoberturaController(repo), tamano: const Size(1400, 900)),
      );
      await t.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      repo.esperaHijas!.complete();
      await t.pumpAndSettle();
      expect(find.text('Chapinero'), findsWidgets);
    });

    testWidgets('una ciudad sin localidades invita a elegirla completa', (
      t,
    ) async {
      // KI-08: el catálogo puede no tener localidades todavía.
      final repo = FakeCoberturaRepository();
      repo.catalogo['bog'] = const [];
      await t.pumpWidget(
        conMapa(CoberturaController(repo), tamano: const Size(1400, 900)),
      );
      await t.pumpAndSettle();

      expect(find.textContaining('aún no tiene localidades'), findsOneWidget);
    });

    testWidgets('sin la bandera no se monta el mapa', (t) async {
      // Por omisión la pantalla no depende del MapaCubit.
      await t.pumpWidget(_app(CoberturaController(FakeCoberturaRepository())));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('cobertura_mapa')), findsNothing);
    });
  });
}

/// Cubit de mapa con estado fijo: la pantalla de cobertura no debe depender de
/// la red para probarse.
class _MapaFalso extends Cubit<MapaState> implements MapaCubit {
  _MapaFalso(super.initialState);

  @override
  Future<void> cargar() async {}

  @override
  Future<void> cargarPanoramica() async {}

  @override
  Future<void> seleccionar(String localidadId) async {}
}

final _anilloPrueba = GeometriaZona.anillosDesdeGeoJson({
  'type': 'Polygon',
  'coordinates': [
    [
      [-74.05, 4.68],
      [-74.04, 4.68],
      [-74.04, 4.67],
      [-74.05, 4.67],
      [-74.05, 4.68],
    ],
  ],
});
