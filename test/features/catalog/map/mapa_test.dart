import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/network/gateway_exception.dart';
import 'package:mani/features/catalog/map/data/mapa_remote_datasource.dart';
import 'package:mani/features/catalog/map/domain/entities/geometria_zona.dart';
import 'package:mani/features/catalog/map/presentation/bloc/mapa_cubit.dart';

const _chapinero = 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13';
const _chico = 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a15';

/// Recorte real de Chicó Norte tal como lo entrega el contrato: GeoJSON con
/// las coordenadas en orden longitud, latitud.
Map<String, dynamic> _respuesta({List<String> sinGeometria = const []}) => {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'id': _chico,
      'geometry': {
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
      },
      'properties': {
        'zoneId': _chico,
        'name': 'Chicó Norte',
        'level': 'BARRIO',
        'attribution': 'UAECD, CC BY 4.0',
      },
    },
  ],
  'sinGeometria': sinGeometria,
  'desconocidas': const <String>[],
  'atribuciones': const ['UAECD, CC BY 4.0'],
};

/// Un límite por id pedido, con el mismo recorte: sirve para contar cuántos
/// agrega la panorámica sin depender de la forma.
Map<String, dynamic> _porId(List<String> ids) => {
  'type': 'FeatureCollection',
  'features': [
    for (final id in ids)
      {
        'type': 'Feature',
        'id': id,
        'geometry': {
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
        },
        'properties': {
          'zoneId': id,
          'name': 'Zona $id',
          'level': 'LOCALIDAD',
          'attribution': 'UAECD, CC BY 4.0',
        },
      },
  ],
  'sinGeometria': const <String>[],
  'desconocidas': const <String>[],
  'atribuciones': const ['UAECD, CC BY 4.0'],
};

class _DatosFalsos implements MapaRemoteDataSource {
  _DatosFalsos({
    this.respuesta,
    this.zonas,
    this.sitios,
    this.fallaSitios = false,
  });

  Map<String, dynamic>? respuesta;
  List<Map<String, dynamic>>? zonas;
  List<SitioUbicado>? sitios;

  /// Reproduce lo que recibe un admin: las sedes son del cliente de la sesión.
  bool fallaSitios;

  List<String>? pedidas;

  /// Todas las peticiones, en orden. La panorámica pide por tandas, así que
  /// con la última no se ve si se partió bien.
  final List<List<String>> peticiones = [];

  /// Devuelve un límite por cada id pedido, para poder contar lo agregado.
  bool unLimitePorId = false;

  /// Cobertura declarada del aliado. Para los demás roles el servicio
  /// responde error, que es lo que reproduce `fallaCobertura`.
  List<String>? cobertura;
  bool fallaCobertura = true;

  /// El Gateway no responde al listar el catálogo.
  bool falla = false;

  @override
  Future<List<SitioUbicado>> listarMisSitios() async {
    if (fallaSitios) {
      throw GatewayException(message: 'No tienes permiso', statusCode: 403);
    }
    return sitios ?? const [];
  }

  @override
  Future<List<String>> listarMiCobertura() async {
    if (fallaCobertura) {
      throw GatewayException(message: 'No tienes permiso', statusCode: 403);
    }
    return cobertura ?? const [];
  }

  @override
  Future<List<Map<String, dynamic>>> listarZonas() async {
    if (falla) {
      throw GatewayException(message: 'Gateway caído', statusCode: 502);
    }
    return zonas ??
        [
          {
            'id': _chapinero,
            'name': 'Chapinero',
            'level': 'LOCALIDAD',
            'parentId': null,
            'selectable': true,
          },
          {
            'id': _chico,
            'name': 'Chicó Norte',
            'level': 'BARRIO',
            'parentId': _chapinero,
            'selectable': true,
          },
        ];
  }

  @override
  Future<GeometriasZonas> obtenerGeometrias(List<String> zonaIds) async {
    pedidas = zonaIds;
    peticiones.add(List.of(zonaIds));
    if (unLimitePorId) {
      return GatewayMapaDataSource.parsear(_porId(zonaIds));
    }
    return GatewayMapaDataSource.parsear(respuesta ?? _respuesta());
  }
}

void main() {
  group('conversión de GeoJSON', () {
    // El error clásico: GeoJSON es [lon, lat] y LatLng es (lat, lon).
    // Invertirlo no rompe ninguna prueba de forma, pero manda Bogotá al golfo
    // de Adén. Por eso se afirma el hemisferio, no solo el número de puntos.
    test(
      'invierte el par para que el punto caiga en Bogotá, no en el golfo de Adén',
      () {
        final anillos = GeometriaZona.anillosDesdeGeoJson(
          _respuesta()['features'][0]['geometry'],
        );

        expect(anillos, hasLength(1));
        final p = anillos.first.first;
        expect(p.latitude, closeTo(4.68132, 0.00001));
        expect(p.longitude, closeTo(-74.05045, 0.00001));
        expect(
          p.latitude > 3 && p.latitude < 6,
          isTrue,
          reason: 'latitud de Bogotá',
        );
        expect(p.longitude < -70, isTrue, reason: 'longitud de Bogotá');
      },
    );

    test('acepta MultiPolygon y aporta un anillo por contorno', () {
      final anillos = GeometriaZona.anillosDesdeGeoJson({
        'type': 'MultiPolygon',
        'coordinates': [
          [
            [
              [-74.1, 4.6],
              [-74.0, 4.6],
              [-74.0, 4.7],
              [-74.1, 4.6],
            ],
          ],
          [
            [
              [-74.3, 4.8],
              [-74.2, 4.8],
              [-74.2, 4.9],
              [-74.3, 4.8],
            ],
          ],
        ],
      });
      expect(anillos, hasLength(2));
    });

    // C2: una geometría inválida es un caso previsto y la pantalla debe poder
    // mostrar el estado vacío, no caerse.
    test(
      'devuelve vacío ante geometría nula, tipo desconocido o puntos insuficientes',
      () {
        expect(GeometriaZona.anillosDesdeGeoJson(null), isEmpty);
        expect(
          GeometriaZona.anillosDesdeGeoJson({
            'type': 'Point',
            'coordinates': [-74, 4],
          }),
          isEmpty,
        );
        expect(
          GeometriaZona.anillosDesdeGeoJson({
            'type': 'Polygon',
            'coordinates': [
              [
                [-74, 4],
                [-74, 5],
              ],
            ],
          }),
          isEmpty,
          reason: 'dos puntos no son un polígono',
        );
        expect(
          GeometriaZona.anillosDesdeGeoJson({
            'type': 'Polygon',
            'coordinates': [
              [
                ['x', 'y'],
                [1, 2],
                [3, 4],
                [5, 6],
              ],
            ],
          }),
          hasLength(1),
          reason: 'descarta el punto inválido y conserva el resto',
        );
      },
    );
  });

  group('MapaCubit', () {
    test(
      'carga la localidad y pide su geometría junto con la de sus barrios',
      () async {
        final datos = _DatosFalsos();
        final cubit = MapaCubit(datos);

        await cubit.cargar();

        expect(cubit.state.estado, MapaEstado.listo);
        expect(cubit.state.localidadId, _chapinero);
        expect(datos.pedidas, [_chapinero, _chico]);
        expect(cubit.state.geometrias, hasLength(1));
        expect(cubit.state.atribuciones, ['UAECD, CC BY 4.0']);
      },
    );

    test(
      'C2 informa las zonas sin límite cargado en vez de dibujar algo aproximado',
      () async {
        final datos = _DatosFalsos(
          respuesta: _respuesta(sinGeometria: [_chapinero]),
        );
        final cubit = MapaCubit(datos);

        await cubit.cargar();

        expect(cubit.state.sinGeometria, [_chapinero]);
        expect(
          cubit.state.geometrias.every((g) => g.zonaId != _chapinero),
          isTrue,
        );
      },
    );

    test(
      'sin ninguna geometría dibujable el estado es vacío, no listo',
      () async {
        final datos = _DatosFalsos(
          respuesta: {
            'type': 'FeatureCollection',
            'features': const [],
            'sinGeometria': [_chapinero],
            'desconocidas': const <String>[],
            'atribuciones': const <String>[],
          },
        );
        final cubit = MapaCubit(datos);

        await cubit.cargar();

        expect(cubit.state.estado, MapaEstado.vacio);
        expect(cubit.state.geometrias, isEmpty);
      },
    );

    test(
      'sin localidades en el catálogo el estado es vacío y no se pide geometría',
      () async {
        final datos = _DatosFalsos(zonas: const []);
        final cubit = MapaCubit(datos);

        await cubit.cargar();

        expect(cubit.state.estado, MapaEstado.vacio);
        expect(datos.pedidas, isNull);
      },
    );

    test(
      'una localidad con muchos barrios se pide en tandas y se dibuja completa (SCRUM-1396)',
      () async {
        // Kennedy tiene más de cien barrios y el contrato topa en 20 por
        // petición: antes el cliente recortaba la lista y el resto no salía.
        final datos = _DatosFalsos(
          zonas: [
            {
              'id': 'loc-0',
              'name': 'Kennedy',
              'level': 'LOCALIDAD',
              'parentId': null,
              'selectable': true,
            },
            for (var i = 0; i < 45; i++)
              {
                'id': 'barrio-$i',
                'name': 'Barrio $i',
                'level': 'BARRIO',
                'parentId': 'loc-0',
                'selectable': true,
              },
          ],
        )..unLimitePorId = true;
        final cubit = MapaCubit(datos);

        await cubit.cargar();

        // 1 localidad + 45 barrios = 46 zonas: tandas de 20, 20 y 6.
        expect(datos.peticiones.map((p) => p.length), [20, 20, 6]);
        expect(datos.peticiones.expand((p) => p).toSet().length, 46);
        expect(cubit.state.geometrias, hasLength(46));
        expect(cubit.state.atribuciones, ['UAECD, CC BY 4.0']);
        expect(cubit.state.estado, MapaEstado.listo);
      },
    );

    test('no pide más zonas de las que Core admite por petición', () {
      expect(GatewayMapaDataSource.maxZonasPorPeticion, 20);
    });

    // El cliente ve sus propias sedes sobre el mapa; el admin no las puede
    // leer y eso no debe tumbar la pantalla.
    test(
      'ubica las sedes de la localidad y cuenta aparte las que no tienen punto',
      () async {
        final datos = _DatosFalsos(
          sitios: const [
            SitioUbicado(
              id: 's1',
              nombre: 'Sede Norte',
              zonaId: _chico,
              latitud: 4.68,
              longitud: -74.05,
            ),
            SitioUbicado(id: 's2', nombre: 'Sede sin GPS', zonaId: _chico),
            SitioUbicado(
              id: 's3',
              nombre: 'Sede de otra zona',
              zonaId: 'zona-ajena',
              latitud: 1,
              longitud: 1,
            ),
          ],
        );
        final cubit = MapaCubit(datos);

        await cubit.cargar();

        expect(cubit.state.sitios.map((s) => s.id), [
          's1',
        ], reason: 'solo la ubicada y de la zona pedida');
        expect(cubit.state.sitiosSinUbicacion, 1);
      },
    );

    test(
      'si las sedes no se pueden leer, el mapa sigue mostrando las zonas',
      () async {
        final datos = _DatosFalsos(fallaSitios: true);
        final cubit = MapaCubit(datos);

        await cubit.cargar();

        expect(
          cubit.state.estado,
          MapaEstado.listo,
          reason: 'el error de sedes no tumba el mapa',
        );
        expect(cubit.state.geometrias, hasLength(1));
        expect(cubit.state.sitios, isEmpty);
        expect(cubit.state.mensajeError, isNull);
      },
    );

    test(
      'una sede ubicada sostiene el mapa aunque no haya ningún límite',
      () async {
        final datos = _DatosFalsos(
          respuesta: {
            'type': 'FeatureCollection',
            'features': const [],
            'sinGeometria': [_chapinero],
            'desconocidas': const <String>[],
            'atribuciones': const <String>[],
          },
          sitios: const [
            SitioUbicado(
              id: 's1',
              nombre: 'Sede Norte',
              zonaId: _chapinero,
              latitud: 4.65,
              longitud: -74.06,
            ),
          ],
        );
        final cubit = MapaCubit(datos);

        await cubit.cargar();

        expect(cubit.state.estado, MapaEstado.listo);
        expect(cubit.state.sitios, hasLength(1));
      },
    );
  });

  group('cobertura del aliado', () {
    test(
      'resalta las zonas que el aliado declaró, y para otros roles queda vacía',
      () async {
        final aliado = _DatosFalsos()
          ..fallaCobertura = false
          ..cobertura = [_chico];
        final cubitAliado = MapaCubit(aliado);
        await cubitAliado.cargar();
        expect(cubitAliado.state.coberturaPropia, {_chico});

        // Un cliente o un admin reciben error del endpoint de cobertura: el mapa
        // sigue funcionando y no resalta nada.
        final otro = MapaCubit(_DatosFalsos());
        await otro.cargar();
        expect(otro.state.coberturaPropia, isEmpty);
        expect(otro.state.estado, MapaEstado.listo);
        expect(otro.state.mensajeError, isNull);
      },
    );

    test('parsea zoneIds y tolera la respuesta sin esa clave', () {
      expect(
        GatewayMapaDataSource.parsearCobertura({
          'zoneIds': [_chico, _chapinero],
        }),
        [_chico, _chapinero],
      );
      expect(GatewayMapaDataSource.parsearCobertura({}), isEmpty);
      expect(
        GatewayMapaDataSource.parsearCobertura({'zoneIds': 'no es lista'}),
        isEmpty,
      );
    });
  });

  group('parseo de sedes', () {
    test(
      'normaliza la coordenada que llega como cadena y trata lo no numérico como ausencia',
      () {
        final sitios = GatewayMapaDataSource.parsearSitios({
          'sitios': [
            {
              'id': 's1',
              'nombre': 'Sede Norte',
              'zonaId': _chico,
              'latitud': '4.68132',
              'longitud': '-74.05045',
            },
            {
              'id': 's2',
              'nombre': 'Sin punto',
              'zonaId': _chico,
              'latitud': null,
              'longitud': null,
            },
            {
              'id': 's3',
              'nombre': 'Basura',
              'zonaId': _chico,
              'latitud': 'norte',
              'longitud': 'occidente',
            },
          ],
        });

        expect(sitios, hasLength(3));
        expect(sitios[0].latitud, closeTo(4.68132, 0.00001));
        expect(sitios[0].tieneCoordenadas, isTrue);
        expect(sitios[1].tieneCoordenadas, isFalse);
        // Nunca 0: el ecuador no es una ubicación por omisión.
        expect(sitios[2].latitud, isNull);
        expect(sitios[2].tieneCoordenadas, isFalse);
      },
    );

    test('sin la clave sitios devuelve vacío en vez de fallar', () {
      expect(GatewayMapaDataSource.parsearSitios({}), isEmpty);
      expect(
        GatewayMapaDataSource.parsearSitios({'sitios': 'no es lista'}),
        isEmpty,
      );
    });
  });

  group('panorámica: todas las localidades a la vez (SCRUM-1396)', () {
    List<Map<String, dynamic>> localidades(int cuantas) => [
      for (var i = 0; i < cuantas; i++)
        {
          'id': 'loc-$i',
          'name': 'Localidad $i',
          'level': 'LOCALIDAD',
          'parentId': null,
          'selectable': true,
        },
    ];

    test('parte la consulta en tandas del tope del contrato', () async {
      // 25 localidades no caben en una petición: el contrato topa en 20 y lo
      // que sobra se perdía en silencio si se pidiera todo de una vez.
      final datos = _DatosFalsos(zonas: localidades(25))..unLimitePorId = true;
      final cubit = MapaCubit(datos);

      await cubit.cargarPanoramica();

      expect(datos.peticiones.length, 2);
      expect(datos.peticiones.first.length, 20);
      expect(datos.peticiones.last.length, 5);
      // Ninguna se queda fuera.
      expect(
        datos.peticiones.expand((p) => p).toSet().length,
        25,
        reason: 'las 25 localidades se piden',
      );
      expect(cubit.state.geometrias.length, 25);
      expect(cubit.state.localidades.length, 25);
      expect(cubit.state.estado, MapaEstado.listo);
    });

    test('no pide barrios ni sedes: solo localidades', () async {
      final datos = _DatosFalsos(
        zonas: [
          ...localidades(2),
          {
            'id': _chico,
            'name': 'Chicó Norte',
            'level': 'BARRIO',
            'parentId': 'loc-0',
            'selectable': true,
          },
        ],
      )..unLimitePorId = true;
      final cubit = MapaCubit(datos);

      await cubit.cargarPanoramica();

      expect(datos.peticiones.single, ['loc-0', 'loc-1']);
      // La panorámica es para elegir cobertura, que no tiene que ver con las
      // sedes del cliente: no se dibujan ni se cuentan.
      expect(cubit.state.sitios, isEmpty);
      expect(cubit.state.sitiosSinUbicacion, 0);
    });

    test('deja fuera lo no seleccionable', () async {
      final datos = _DatosFalsos(
        zonas: [
          ...localidades(1),
          {
            'id': 'loc-inactiva',
            'name': 'Inactiva',
            'level': 'LOCALIDAD',
            'parentId': null,
            'selectable': false,
          },
        ],
      )..unLimitePorId = true;
      final cubit = MapaCubit(datos);

      await cubit.cargarPanoramica();

      expect(datos.peticiones.single, ['loc-0']);
    });

    test('resalta la cobertura ya declarada del aliado', () async {
      final datos = _DatosFalsos(zonas: localidades(2))
        ..unLimitePorId = true
        ..fallaCobertura = false
        ..cobertura = ['loc-1'];
      final cubit = MapaCubit(datos);

      await cubit.cargarPanoramica();

      expect(cubit.state.coberturaPropia, {'loc-1'});
    });

    test('sin cobertura legible el mapa sigue, sin resaltado', () async {
      // Es lo que recibe un rol que no es aliado: error esperado, no fallo.
      final datos = _DatosFalsos(zonas: localidades(1))..unLimitePorId = true;
      final cubit = MapaCubit(datos);

      await cubit.cargarPanoramica();

      expect(cubit.state.estado, MapaEstado.listo);
      expect(cubit.state.coberturaPropia, isEmpty);
    });

    test('sin localidades queda vacío, no en error', () async {
      final cubit = MapaCubit(_DatosFalsos(zonas: const []));

      await cubit.cargarPanoramica();

      expect(cubit.state.estado, MapaEstado.vacio);
      expect(cubit.state.localidades, isEmpty);
    });

    test('sin ningún límite dibujable queda vacío', () async {
      // Catálogo con localidades pero sin geometría cargada todavía: no se
      // dibuja una forma aproximada (C2).
      final datos = _DatosFalsos(
        zonas: localidades(1),
        respuesta: {
          'type': 'FeatureCollection',
          'features': const [],
          'sinGeometria': const ['loc-0'],
          'desconocidas': const <String>[],
          'atribuciones': const <String>[],
        },
      );
      final cubit = MapaCubit(datos);

      await cubit.cargarPanoramica();

      expect(cubit.state.estado, MapaEstado.vacio);
      expect(cubit.state.sinGeometria, ['loc-0']);
    });

    test(
      'un fallo del Gateway se reporta y no deja el mapa cargando',
      () async {
        final cubit = MapaCubit(_DatosFalsos(zonas: const [])..falla = true);

        await cubit.cargarPanoramica();

        expect(cubit.state.estado, MapaEstado.error);
        expect(cubit.state.mensajeError, isNotNull);
      },
    );
  });
}
