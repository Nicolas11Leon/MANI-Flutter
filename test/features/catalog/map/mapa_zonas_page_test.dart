import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/features/catalog/map/data/mapa_remote_datasource.dart';
import 'package:mani/features/catalog/map/domain/entities/geometria_zona.dart';
import 'package:mani/features/catalog/map/presentation/bloc/mapa_cubit.dart';
import 'package:mani/features/catalog/map/presentation/pages/mapa_zonas_page.dart';
import 'package:mani/features/catalog/map/presentation/widgets/mapa_zonas.dart';

const _chapinero = 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13';
const _chico = 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a15';

/// Recorte real de Chicó Norte, en orden longitud-latitud como lo entrega el
/// contrato.
final _anillo = GeometriaZona.anillosDesdeGeoJson({
  'type': 'Polygon',
  'coordinates': [
    [
      [-74.05045, 4.68132],
      [-74.04500, 4.68132],
      [-74.04500, 4.67500],
      [-74.05045, 4.67500],
      [-74.05045, 4.68132],
    ],
  ],
});

/// Otro límite, lo bastante lejos como para que el centro cambie de verdad.
final _otroAnillo = GeometriaZona.anillosDesdeGeoJson({
  'type': 'Polygon',
  'coordinates': [
    [
      [-74.09, 4.74],
      [-74.08, 4.74],
      [-74.08, 4.75],
      [-74.09, 4.75],
      [-74.09, 4.74],
    ],
  ],
});

class _CubitFalso extends Cubit<MapaState> implements MapaCubit {
  _CubitFalso(super.initialState);

  @override
  Future<void> cargar() async {}

  @override
  Future<void> cargarPanoramica() async {
    panoramica = true;
  }

  bool panoramica = false;

  @override
  Future<void> seleccionar(String localidadId) async {
    seleccionada = localidadId;
  }

  String? seleccionada;
}

Widget _app(MapaState estado, {_CubitFalso? cubit}) {
  return MaterialApp(
    home: BlocProvider<MapaCubit>.value(
      value: cubit ?? _CubitFalso(estado),
      child: const MapaZonasPage(),
    ),
  );
}

void main() {
  testWidgets('dibuja el mapa con un polígono por cada anillo del límite', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        MapaState(
          estado: MapaEstado.listo,
          localidades: const [
            {'id': _chapinero, 'name': 'Chapinero', 'level': 'LOCALIDAD'},
          ],
          localidadId: _chapinero,
          geometrias: [
            GeometriaZona(
              zonaId: _chico,
              nombre: 'Chicó Norte',
              nivel: 'BARRIO',
              anillos: _anillo,
              atribucion: 'UAECD, CC BY 4.0',
            ),
          ],
          atribuciones: const ['UAECD, CC BY 4.0'],
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('mapa_zonas')), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);

    final capa = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
    expect(capa.polygons, hasLength(1));
    // El punto llega al mapa como (latitud, longitud): si la conversión se
    // invirtiera, esto caería fuera de Bogotá.
    final p = capa.polygons.first.points.first;
    expect(p.latitude, closeTo(4.68132, 0.00001));
    expect(p.longitude, closeTo(-74.05045, 0.00001));
  });

  testWidgets('sin geometrías muestra el estado vacío y no dibuja un mapa', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const MapaState(estado: MapaEstado.vacio)));
    await tester.pump();

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Sin límites para mostrar'), findsOneWidget);
    // C2: se dice que no se dibuja una forma aproximada, no se insinúa que no haya zonas.
    expect(
      find.textContaining('No se dibuja una forma aproximada'),
      findsOneWidget,
    );
  });

  testWidgets('avisa cuántas zonas quedaron sin límite cargado', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        MapaState(
          estado: MapaEstado.listo,
          geometrias: [
            GeometriaZona(
              zonaId: _chico,
              nombre: 'Chicó Norte',
              nivel: 'BARRIO',
              anillos: _anillo,
              atribucion: 'UAECD',
            ),
          ],
          sinGeometria: const [_chapinero],
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('mapa_sin_geometria')), findsOneWidget);
    expect(find.textContaining('1 zona(s) sin límite cargado'), findsOneWidget);
  });

  testWidgets('marca la sede ubicada y avisa de las que no tienen punto', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        MapaState(
          estado: MapaEstado.listo,
          geometrias: [
            GeometriaZona(
              zonaId: _chico,
              nombre: 'Chicó Norte',
              nivel: 'BARRIO',
              anillos: _anillo,
              atribucion: 'UAECD',
            ),
          ],
          sitios: const [
            SitioUbicado(
              id: 's1',
              nombre: 'Sede Norte',
              zonaId: _chico,
              latitud: 4.68,
              longitud: -74.048,
            ),
          ],
          sitiosSinUbicacion: 2,
        ),
      ),
    );
    await tester.pump();

    final capa = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(capa.markers, hasLength(1));
    // El punto llega como (latitud, longitud): invertirlo lo saca de Bogotá.
    expect(capa.markers.first.point.latitude, closeTo(4.68, 0.0001));
    expect(capa.markers.first.point.longitude, closeTo(-74.048, 0.0001));

    // C2: las sedes sin punto se cuentan, no se ubican en el centroide.
    expect(find.byKey(const Key('mapa_sitios_sin_ubicacion')), findsOneWidget);
    expect(
      find.textContaining('2 sede(s) sin ubicación capturada'),
      findsOneWidget,
    );
  });

  testWidgets('una sede ubicada basta para dibujar el mapa sin ningún límite', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const MapaState(
          estado: MapaEstado.listo,
          sitios: [
            SitioUbicado(
              id: 's1',
              nombre: 'Sede Norte',
              zonaId: _chapinero,
              latitud: 4.65,
              longitud: -74.06,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(
      tester.widget<PolygonLayer>(find.byType(PolygonLayer)).polygons,
      isEmpty,
    );
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(1),
    );
  });

  // El aliado ve resaltada su cobertura. Es lectura: cambiarla es de
  // «Zona de cobertura», por lista y hasta localidad.
  testWidgets(
    'resalta en verde la zona declarada como cobertura y explica que no se edita aquí',
    (tester) async {
      final conCobertura = GeometriaZona(
        zonaId: _chico,
        nombre: 'Chicó Norte',
        nivel: 'BARRIO',
        anillos: _anillo,
        atribucion: 'UAECD',
      );
      await tester.pumpWidget(
        _app(
          MapaState(
            estado: MapaEstado.listo,
            geometrias: [conCobertura],
            coberturaPropia: const {_chico},
          ),
        ),
      );
      await tester.pump();

      final poligono = tester
          .widget<PolygonLayer>(find.byType(PolygonLayer))
          .polygons
          .first;
      expect(
        poligono.borderColor,
        const Color(0xFF166534),
        reason: 'verde de cobertura',
      );
      expect(
        poligono.borderStrokeWidth,
        3,
        reason: 'trazo más marcado que una zona cualquiera',
      );

      expect(find.byKey(const Key('mapa_leyenda_cobertura')), findsOneWidget);
      // Ya no remite a una entrada de menú: el mapa del aliado vive dentro de
      // «Zona de cobertura», y esta pantalla suelta quedó para el catálogo.
      expect(
        find.textContaining('ya declaraste como cobertura'),
        findsOneWidget,
      );
    },
  );

  testWidgets('sin cobertura propia no hay leyenda ni verde', (tester) async {
    await tester.pumpWidget(
      _app(
        MapaState(
          estado: MapaEstado.listo,
          geometrias: [
            GeometriaZona(
              zonaId: _chico,
              nombre: 'Chicó Norte',
              nivel: 'BARRIO',
              anillos: _anillo,
              atribucion: 'UAECD',
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    final poligono = tester
        .widget<PolygonLayer>(find.byType(PolygonLayer))
        .polygons
        .first;
    expect(
      poligono.borderColor,
      const Color(0xFFC2410C),
      reason: 'naranja de barrio',
    );
    expect(find.byKey(const Key('mapa_leyenda_cobertura')), findsNothing);
  });

  testWidgets('el error ofrece reintentar', (tester) async {
    await tester.pumpWidget(
      _app(
        const MapaState(
          estado: MapaEstado.error,
          mensajeError: 'Gateway caído',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No se pudo cargar el mapa'), findsOneWidget);
    expect(find.text('Gateway caído'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('con varias localidades el selector cambia la que se pinta', (
    tester,
  ) async {
    final cubit = _CubitFalso(
      const MapaState(
        estado: MapaEstado.vacio,
        localidades: [
          {'id': _chapinero, 'name': 'Chapinero', 'level': 'LOCALIDAD'},
          {'id': 'otra-id', 'name': 'Suba', 'level': 'LOCALIDAD'},
        ],
        localidadId: _chapinero,
      ),
    );
    await tester.pumpWidget(_app(cubit.state, cubit: cubit));
    await tester.pump();

    expect(find.byKey(const Key('mapa_selector_localidad')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mapa_selector_localidad')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suba').last);
    await tester.pumpAndSettle();

    expect(cubit.seleccionada, 'otra-id');
  });

  testWidgets(
    'al elegir otra localidad la cámara se reencuadra sobre sus límites',
    (tester) async {
      // `initialCameraFit` solo actúa al construir, así que sin reencuadre
      // explícito el mapa se quedaba sobre la localidad anterior.
      final cubit = _CubitFalso(
        MapaState(
          estado: MapaEstado.listo,
          localidadId: _chapinero,
          geometrias: [
            GeometriaZona(
              zonaId: _chico,
              nombre: 'Chicó Norte',
              nivel: 'BARRIO',
              anillos: _anillo,
              atribucion: 'UAECD',
            ),
          ],
        ),
      );
      await tester.pumpWidget(_app(MapaState(), cubit: cubit));
      await tester.pumpAndSettle();

      final centroInicial = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options
          .initialCenter;

      cubit.emit(
        MapaState(
          estado: MapaEstado.listo,
          localidadId: 'otra-id',
          geometrias: [
            GeometriaZona(
              zonaId: 'otra-zona',
              nombre: 'Suba',
              nivel: 'LOCALIDAD',
              anillos: _otroAnillo,
              atribucion: 'UAECD',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final camara = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .camera;

      // La cámara quedó sobre el nuevo límite, no sobre el anterior.
      expect(camara.center.latitude, closeTo(4.745, 0.02));
      expect(camara.center.longitude, closeTo(-74.085, 0.02));
      expect(camara.center, isNot(centroInicial));
    },
  );

  testWidgets(
    'con selección en curso resalta esa, no la cobertura ya guardada',
    (tester) async {
      // Es lo que ve el aliado mientras marca zonas en «Zona de cobertura»:
      // debe pintarse lo que lleva marcado, no lo que guardó la última vez.
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<MapaCubit>.value(
            value: _CubitFalso(
              MapaState(
                estado: MapaEstado.listo,
                coberturaPropia: const {'zona-guardada'},
                geometrias: [
                  GeometriaZona(
                    zonaId: _chico,
                    nombre: 'Chicó Norte',
                    nivel: 'BARRIO',
                    anillos: _anillo,
                    atribucion: 'UAECD',
                  ),
                ],
              ),
            ),
            child: const Scaffold(
              body: MapaZonas(
                coberturaResaltada: {_chico},
                leyendaCobertura: 'En verde, lo que llevas seleccionado.',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final poligono = tester
          .widget<PolygonLayer>(find.byType(PolygonLayer))
          .polygons
          .first;
      expect(poligono.borderColor, const Color(0xFF166534));
      expect(find.textContaining('lo que llevas seleccionado'), findsOneWidget);
    },
  );

  group('modo selector: el mapa marca cobertura (SCRUM-1396)', () {
    Widget selector({
      required Set<String> elegidas,
      required void Function(String) onTocar,
    }) => MaterialApp(
      home: BlocProvider<MapaCubit>.value(
        value: _CubitFalso(
          MapaState(
            estado: MapaEstado.listo,
            localidades: const [
              {'id': _chapinero, 'name': 'Chapinero', 'level': 'LOCALIDAD'},
              {'id': 'otra-id', 'name': 'Suba', 'level': 'LOCALIDAD'},
            ],
            geometrias: [
              GeometriaZona(
                zonaId: _chico,
                nombre: 'Chicó Norte',
                nivel: 'BARRIO',
                anillos: _anillo,
                atribucion: 'UAECD',
              ),
            ],
          ),
        ),
        child: Scaffold(
          body: MapaZonas(coberturaResaltada: elegidas, onZonaTocada: onTocar),
        ),
      ),
    );

    testWidgets('cada zona lleva su nombre encima', (tester) async {
      await tester.pumpWidget(selector(elegidas: const {}, onTocar: (_) {}));
      await tester.pumpAndSettle();

      expect(find.text('Chicó Norte'), findsOneWidget);
      expect(find.byKey(const Key('mapa_marca_Chicó Norte')), findsOneWidget);
    });

    testWidgets('tocar la zona avisa con su id', (tester) async {
      final tocadas = <String>[];
      await tester.pumpWidget(
        selector(elegidas: const {}, onTocar: tocadas.add),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mapa_marca_Chicó Norte')));
      await tester.pumpAndSettle();

      expect(tocadas, [_chico]);
    });

    testWidgets('la marca distingue elegida de no elegida', (tester) async {
      await tester.pumpWidget(selector(elegidas: const {}, onTocar: (_) {}));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.pumpWidget(
        selector(elegidas: const {_chico}, onTocar: (_) {}),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('no ofrece el desplegable de localidad', (tester) async {
      // En panorámica están todas a la vez: elegir una sola sobra y confunde.
      await tester.pumpWidget(selector(elegidas: const {}, onTocar: (_) {}));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mapa_selector_localidad')), findsNothing);
    });

    testWidgets('sin modo selector no hay marcas que tocar', (tester) async {
      await tester.pumpWidget(
        _app(
          MapaState(
            estado: MapaEstado.listo,
            geometrias: [
              GeometriaZona(
                zonaId: _chico,
                nombre: 'Chicó Norte',
                nivel: 'BARRIO',
                anillos: _anillo,
                atribucion: 'UAECD',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mapa_marca_Chicó Norte')), findsNothing);
    });
  });
}
