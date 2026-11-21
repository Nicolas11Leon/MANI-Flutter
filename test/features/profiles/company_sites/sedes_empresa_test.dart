import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/network/gateway_exception.dart';
import 'package:mani/features/profiles/company_sites/data/sedes_empresa_remote_datasource.dart';
import 'package:mani/features/profiles/company_sites/domain/entities/sede_empresa.dart';
import 'package:mani/features/profiles/company_sites/domain/usecases/sedes_empresa_usecases.dart';
import 'package:mani/features/profiles/company_sites/presentation/bloc/sedes_empresa_cubit.dart';
import 'package:mani/features/profiles/company_sites/presentation/pages/gestion_sedes_empresa_page.dart';
import 'package:mani/features/catalog/map/domain/entities/geometria_zona.dart';
import 'package:mani/features/catalog/map/presentation/bloc/mapa_cubit.dart';

const _rutaSedes = '/api/v1/core/clients/me/sites';
const _rutaZonas = '/api/v1/core/catalog/zones';

/// Catálogo de Core: una ciudad, una localidad y dos barrios, uno inactivo.
const _zonas = [
  {'id': 'z-bog', 'name': 'Bogotá', 'parentId': null, 'selectable': false},
  {
    'id': 'z-chap',
    'name': 'Chapinero',
    'parentId': 'z-bog',
    'selectable': true,
  },
  {
    'id': 'z-quinta',
    'name': 'Quinta Camacho',
    'parentId': 'z-chap',
    'selectable': true,
  },
  {
    'id': 'z-old',
    'name': 'Barrio Viejo',
    'parentId': 'z-chap',
    'selectable': false,
  },
];

const _sedePrincipal = {
  'id': 'sede-1',
  'nombre': 'Sede Principal Centro',
  'direccion': 'Calle 72 # 10-07',
  'zonaId': 'z-chap',
  'contactoNombre': 'Ana',
  'contactoTelefono': null,
};

http.Response _json(Object cuerpo, int status) => http.Response(
  jsonEncode(cuerpo),
  status,
  headers: {'content-type': 'application/json'},
);

/// Gateway simulado: cada clave es `MÉTODO ruta`. Registra las peticiones.
GatewayClient _gateway(
  Map<String, http.Response Function(http.Request)> rutas,
  List<http.Request> peticiones,
) {
  return GatewayClient(
    baseUrl: 'http://gateway.local',
    tokenProvider: () async => 'jwt-cliente-empresa',
    httpClient: MockClient((req) async {
      peticiones.add(req);
      final manejador = rutas['${req.method} ${req.url.path}'];
      return manejador == null ? _json({'error': 'no'}, 500) : manejador(req);
    }),
  );
}

SedesEmpresaCubit _cubit(GatewayClient gateway) {
  final repo = SedesEmpresaRepositoryImpl(
    remoteDataSource: SedesEmpresaRemoteDataSource(gateway: gateway),
  );
  return SedesEmpresaCubit(
    listarUseCase: ListarSedesEmpresaUseCase(repo),
    agregarUseCase: AgregarSedeEmpresaUseCase(repo),
    editarUseCase: EditarSedeEmpresaUseCase(repo),
    listarZonasUseCase: ListarZonasSedeUseCase(repo),
  );
}

Future<void> _abrir(WidgetTester tester, SedesEmpresaCubit cubit) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: const GestionSedesEmpresaPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _elegirZona(
  WidgetTester tester,
  Finder campo,
  String texto,
) async {
  await tester.enterText(campo, texto);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Chapinero · Quinta Camacho').last);
  await tester.pumpAndSettle();
}

class _RepoFalso implements ISedesEmpresaRepository {
  Map<String, dynamic>? cambiosEnviados;

  @override
  Future<SedeEmpresa> editarSede(
    String sedeId,
    Map<String, dynamic> cambios,
  ) async {
    cambiosEnviados = cambios;
    return SedeEmpresa.fromJson({..._sedePrincipal, ...cambios});
  }

  @override
  Future<SedeEmpresa> agregarSede(NuevaSedeEmpresa sede) =>
      throw UnimplementedError();

  @override
  Future<List<SedeEmpresa>> listarSedes() => throw UnimplementedError();

  @override
  Future<List<ZonaSede>> listarZonas() => throw UnimplementedError();
}

class _FuenteQueFalla implements ISedesEmpresaRemoteDataSource {
  _FuenteQueFalla(this.error);
  final Object error;

  @override
  Future<SedeEmpresa> agregarSede(NuevaSedeEmpresa sede) => Future.error(error);

  @override
  Future<SedeEmpresa> editarSede(String sedeId, Map<String, dynamic> cambios) =>
      Future.error(error);

  @override
  Future<List<SedeEmpresa>> listarSedes() => Future.error(error);

  @override
  Future<List<ZonaSede>> listarZonas() => Future.error(error);
}

void main() {
  group('SCRUM-852 / SCRUM-1387 — sedes del cliente empresa por el Gateway', () {
    testWidgets(
      'lista las sedes con el alias me y nombra la zona con su zona padre',
      (tester) async {
        final peticiones = <http.Request>[];
        final cubit = _cubit(
          _gateway({
            'GET $_rutaSedes': (_) => _json({
              'totalSitios': 1,
              'sitios': [_sedePrincipal],
            }, 200),
            'GET $_rutaZonas': (_) => _json({'zones': _zonas}, 200),
          }, peticiones),
        );
        addTearDown(cubit.close);

        await _abrir(tester, cubit);

        expect(find.byKey(const Key('sede_card_sede-1')), findsOneWidget);
        expect(
          find.text('Calle 72 # 10-07 · Zona: Bogotá · Chapinero'),
          findsOneWidget,
        );
        expect(
          peticiones.map((r) => r.url.path),
          containsAll([_rutaSedes, _rutaZonas]),
        );
        // Nunca se envía el id del usuario como id del cliente.
        expect(
          peticiones.every((r) => !r.url.path.contains('/clients/u-')),
          isTrue,
        );
      },
    );

    testWidgets(
      'agrega una sede con una zona elegida del catálogo y vacía el formulario',
      (tester) async {
        final peticiones = <http.Request>[];
        final cubit = _cubit(
          _gateway({
            'GET $_rutaSedes': (_) => _json({
              'sitios': [_sedePrincipal],
            }, 200),
            'GET $_rutaZonas': (_) => _json({'zones': _zonas}, 200),
            'POST $_rutaSedes': (req) {
              final body = jsonDecode(req.body) as Map<String, dynamic>;
              return _json({
                'sitio': {'id': 'sede-2', ...body},
              }, 201);
            },
          }, peticiones),
        );
        addTearDown(cubit.close);
        await _abrir(tester, cubit);

        final formulario = find.byKey(
          const ValueKey('formulario_nueva_sede_0'),
        );
        await tester.enterText(
          find.descendant(
            of: formulario,
            matching: find.byKey(const Key('input_nombre_sede')),
          ),
          'Sucursal Norte',
        );
        await tester.enterText(
          find.descendant(
            of: formulario,
            matching: find.byKey(const Key('input_direccion_sede')),
          ),
          'Carrera 15 # 119-40',
        );
        // La zona inactiva no aparece entre las opciones.
        await tester.enterText(
          find.descendant(
            of: formulario,
            matching: find.byKey(const Key('input_zona_sede')),
          ),
          'viejo',
        );
        await tester.pumpAndSettle();
        expect(find.text('Chapinero · Barrio Viejo'), findsNothing);

        await _elegirZona(
          tester,
          find.descendant(
            of: formulario,
            matching: find.byKey(const Key('input_zona_sede')),
          ),
          'quinta',
        );
        await tester.tap(
          find.descendant(
            of: formulario,
            matching: find.byKey(const Key('btn_guardar_sede')),
          ),
        );
        await tester.pumpAndSettle();

        final post = peticiones.last;
        expect(post.method, 'POST');
        expect(post.url.path, _rutaSedes);
        final enviado = jsonDecode(post.body) as Map<String, dynamic>;
        expect(enviado['zonaId'], 'z-quinta');
        expect(enviado.containsKey('contactoNombre'), isFalse);
        expect(find.byKey(const Key('sede_card_sede-2')), findsOneWidget);
        expect(find.text('Sede registrada.'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('formulario_nueva_sede_1')),
          findsOneWidget,
        );
      },
    );

    testWidgets('sin zona elegida no se envía la sede (RF-09)', (tester) async {
      final peticiones = <http.Request>[];
      final cubit = _cubit(
        _gateway({
          'GET $_rutaSedes': (_) => _json({'sitios': <dynamic>[]}, 200),
          'GET $_rutaZonas': (_) => _json({'zones': _zonas}, 200),
        }, peticiones),
      );
      addTearDown(cubit.close);
      await _abrir(tester, cubit);

      await tester.enterText(
        find.byKey(const Key('input_nombre_sede')),
        'Sede',
      );
      await tester.enterText(
        find.byKey(const Key('input_direccion_sede')),
        'Calle 1 # 2-3',
      );
      // Escribir sin elegir una opción no cuenta como zona.
      await tester.enterText(
        find.byKey(const Key('input_zona_sede')),
        'quinta',
      );
      await tester.tap(find.byKey(const Key('btn_guardar_sede')));
      await tester.pumpAndSettle();

      expect(find.text('Elige la zona de la sede'), findsOneWidget);
      expect(peticiones.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets(
      'edita una sede: el PATCH lleva solo lo que cambió y la tarjeta se actualiza',
      (tester) async {
        final peticiones = <http.Request>[];
        final cubit = _cubit(
          _gateway({
            'GET $_rutaSedes': (_) => _json({
              'sitios': [_sedePrincipal],
            }, 200),
            'GET $_rutaZonas': (_) => _json({'zones': _zonas}, 200),
            'PATCH $_rutaSedes/sede-1': (req) {
              final body = jsonDecode(req.body) as Map<String, dynamic>;
              return _json({
                'sitio': {..._sedePrincipal, ...body},
              }, 200);
            },
          }, peticiones),
        );
        addTearDown(cubit.close);
        await _abrir(tester, cubit);

        await tester.tap(find.byKey(const Key('btn_editar_sede_sede-1')));
        await tester.pumpAndSettle();
        final dialogo = find.byKey(const Key('formulario_editar_sede'));
        expect(dialogo, findsOneWidget);

        final nombre = find.descendant(
          of: dialogo,
          matching: find.byKey(const Key('input_nombre_sede')),
        );
        expect(
          find.descendant(
            of: dialogo,
            matching: find.text('Sede Principal Centro'),
          ),
          findsOneWidget,
        );
        await tester.enterText(nombre, 'Sede Centro Renovada');
        await _elegirZona(
          tester,
          find.descendant(
            of: dialogo,
            matching: find.byKey(const Key('input_zona_sede')),
          ),
          'quinta',
        );
        await tester.tap(
          find.descendant(
            of: dialogo,
            matching: find.byKey(const Key('btn_guardar_sede')),
          ),
        );
        await tester.pumpAndSettle();

        final patch = peticiones.last;
        expect(patch.method, 'PATCH');
        expect(patch.url.path, '$_rutaSedes/sede-1');
        expect(jsonDecode(patch.body), {
          'nombre': 'Sede Centro Renovada',
          'zonaId': 'z-quinta',
        });
        expect(find.byKey(const Key('formulario_editar_sede')), findsNothing);
        expect(find.text('Sede Centro Renovada'), findsOneWidget);
        expect(find.text('Sede actualizada.'), findsOneWidget);
      },
    );

    testWidgets(
      'si Core rechaza la edición, el diálogo sigue abierto con el motivo',
      (tester) async {
        final cubit = _cubit(
          _gateway({
            'GET $_rutaSedes': (_) => _json({
              'sitios': [_sedePrincipal],
            }, 200),
            'GET $_rutaZonas': (_) => _json({'zones': _zonas}, 200),
            'PATCH $_rutaSedes/sede-1': (_) => _json({
              'error': 'Sitio con ID "sede-1" no encontrado para este cliente.',
              'code': 'SITE_NOT_FOUND',
            }, 404),
          }, <http.Request>[]),
        );
        addTearDown(cubit.close);
        await _abrir(tester, cubit);

        await tester.tap(find.byKey(const Key('btn_editar_sede_sede-1')));
        await tester.pumpAndSettle();
        final dialogo = find.byKey(const Key('formulario_editar_sede'));
        await tester.enterText(
          find.descendant(
            of: dialogo,
            matching: find.byKey(const Key('input_nombre_sede')),
          ),
          'Otro nombre',
        );
        await tester.tap(
          find.descendant(
            of: dialogo,
            matching: find.byKey(const Key('btn_guardar_sede')),
          ),
        );
        await tester.pumpAndSettle();

        expect(dialogo, findsOneWidget);
        expect(
          find.descendant(
            of: dialogo,
            matching: find.text(
              'Esa sede no existe o no es de tu empresa. Actualiza la lista.',
            ),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('btn_cancelar_edicion')));
        await tester.pumpAndSettle();
        expect(dialogo, findsNothing);
      },
    );

    testWidgets('un cliente sin empresa ve un mensaje claro, sin ids de Core', (
      tester,
    ) async {
      final cubit = _cubit(
        _gateway({
          'GET $_rutaSedes': (_) => _json({
            'error':
                'Cliente empresa de la sesión no encontrado en tenant "t-1".',
            'code': 'CLIENT_NOT_FOUND',
          }, 404),
          'GET $_rutaZonas': (_) => _json({'zones': _zonas}, 200),
        }, <http.Request>[]),
      );
      addTearDown(cubit.close);
      await _abrir(tester, cubit);

      expect(
        find.text(
          'Las sedes son para clientes empresa. Tu cuenta no tiene una '
          'empresa registrada.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('t-1'), findsNothing);
    });

    testWidgets(
      'si el catálogo de zonas falla, las sedes se ven pero no se editan',
      (tester) async {
        final cubit = _cubit(
          _gateway({
            'GET $_rutaSedes': (_) => _json({
              'sitios': [_sedePrincipal],
            }, 200),
            // 500 y no 503: el GatewayClient reintenta los 502-504 con espera.
            'GET $_rutaZonas': (_) => _json({'error': 'caído'}, 500),
          }, <http.Request>[]),
        );
        addTearDown(cubit.close);
        await _abrir(tester, cubit);

        expect(find.byKey(const Key('sede_card_sede-1')), findsOneWidget);
        expect(
          find.textContaining('No se pudieron cargar las zonas'),
          findsOneWidget,
        );
        // Sin catálogo la zona se muestra por su id.
        expect(find.text('Calle 72 # 10-07 · Zona: z-chap'), findsOneWidget);
        final editar = tester.widget<IconButton>(
          find.byKey(const Key('btn_editar_sede_sede-1')),
        );
        expect(editar.onPressed, isNull);
        final guardar = tester.widget<ElevatedButton>(
          find.byKey(const Key('btn_guardar_sede')),
        );
        expect(guardar.onPressed, isNull);
      },
    );
  });

  group('EditarSedeEmpresaUseCase', () {
    final actual = SedeEmpresa.fromJson(_sedePrincipal);

    test('sin cambios no llama a Core', () {
      final repo = _RepoFalso();
      expect(
        () => EditarSedeEmpresaUseCase(repo)(
          actual,
          const NuevaSedeEmpresa(
            nombre: 'Sede Principal Centro ',
            direccion: 'Calle 72 # 10-07',
            zonaId: 'z-chap',
            contactoNombre: 'Ana',
            contactoTelefono: '  ',
          ),
        ),
        throwsA(isA<SedeEmpresaFailure>()),
      );
      expect(repo.cambiosEnviados, isNull);
    });

    test(
      'borrar el contacto lo envía como null y agregar teléfono lo envía',
      () async {
        final repo = _RepoFalso();
        await EditarSedeEmpresaUseCase(repo)(
          actual,
          const NuevaSedeEmpresa(
            nombre: 'Sede Principal Centro',
            direccion: 'Calle 72 # 10-07',
            zonaId: 'z-chap',
            contactoNombre: '',
            contactoTelefono: '3001234567',
          ),
        );
        expect(repo.cambiosEnviados, {
          'contactoNombre': null,
          'contactoTelefono': '3001234567',
        });
      },
    );

    test('nombre, dirección y zona siguen siendo obligatorios', () {
      final usecase = EditarSedeEmpresaUseCase(_RepoFalso());
      for (final datos in const [
        NuevaSedeEmpresa(nombre: ' ', direccion: 'Calle 1', zonaId: 'z'),
        NuevaSedeEmpresa(nombre: 'Sede', direccion: '', zonaId: 'z'),
        NuevaSedeEmpresa(nombre: 'Sede', direccion: 'Calle 1', zonaId: ''),
      ]) {
        expect(
          () => usecase(actual, datos),
          throwsA(isA<SedeEmpresaFailure>()),
        );
      }
    });
  });

  group('SedesEmpresaRepositoryImpl traduce los errores', () {
    Future<String> mensaje(Object error) async {
      final repo = SedesEmpresaRepositoryImpl(
        remoteDataSource: _FuenteQueFalla(error),
      );
      try {
        await repo.agregarSede(
          const NuevaSedeEmpresa(nombre: 'a', direccion: 'b', zonaId: 'c'),
        );
      } on SedeEmpresaFailure catch (e) {
        return e.message;
      }
      fail('debía fallar');
    }

    test('un 404 sin código conocido usa el mensaje de la operación', () async {
      expect(
        await mensaje(const GatewayException(message: 'x', statusCode: 404)),
        'No se pudo registrar la nueva sede.',
      );
    });

    test('un 400 muestra el detalle del Gateway', () async {
      expect(
        await mensaje(
          const GatewayException(message: 'zona no existe', statusCode: 400),
        ),
        'zona no existe',
      );
    });

    test(
      'un error que no es del Gateway usa el mensaje de la operación',
      () async {
        expect(
          await mensaje(StateError('x')),
          'No se pudo registrar la nueva sede.',
        );
      },
    );

    test('las demás operaciones también traducen el error', () async {
      final repo = SedesEmpresaRepositoryImpl(
        remoteDataSource: _FuenteQueFalla(StateError('x')),
      );
      await expectLater(repo.listarSedes(), throwsA(isA<SedeEmpresaFailure>()));
      await expectLater(repo.listarZonas(), throwsA(isA<SedeEmpresaFailure>()));
      await expectLater(
        repo.editarSede('s', const {'nombre': 'x'}),
        throwsA(isA<SedeEmpresaFailure>()),
      );
    });
  });

  group('SedesEmpresaRemoteDataSource valida la respuesta de Core', () {
    SedesEmpresaRemoteDataSource fuente(Object cuerpo) =>
        SedesEmpresaRemoteDataSource(
          gateway: _gateway({
            'GET $_rutaSedes': (_) => _json(cuerpo, 200),
            'GET $_rutaZonas': (_) => _json(cuerpo, 200),
            'POST $_rutaSedes': (_) => _json(cuerpo, 201),
          }, <http.Request>[]),
        );

    test('sin "sitios" la lista queda vacía', () async {
      expect(await fuente({'data': []}).listarSedes(), isEmpty);
    });

    test('sin "zones" o sin "sitio" es un error, no una lista falsa', () async {
      await expectLater(
        fuente({'data': []}).listarZonas(),
        throwsA(isA<GatewayException>()),
      );
      await expectLater(
        fuente({'data': {}}).agregarSede(
          const NuevaSedeEmpresa(nombre: 'a', direccion: 'b', zonaId: 'c'),
        ),
        throwsA(isA<GatewayException>()),
      );
    });
  });

  group('mapa de las sedes (HU-M04-07 / SCRUM-1396)', () {
    /// Cubit con el catálogo y una sede, que es lo que la pantalla necesita
    /// para pintarse; el mapa llega por su propio cubit.
    SedesEmpresaCubit cubitBasico() => _cubit(
      _gateway({
        'GET $_rutaSedes': (_) => _json({
          'totalSitios': 1,
          'sitios': [_sedePrincipal],
        }, 200),
        'GET $_rutaZonas': (_) => _json({'zones': _zonas}, 200),
      }, <http.Request>[]),
    );

    /// La pantalla con mapa necesita un `MapaCubit` en el contexto.
    Future<void> abrirConMapa(
      WidgetTester tester,
      SedesEmpresaCubit cubit, {
      required MapaState mapa,
    }) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider<MapaCubit>.value(value: _MapaFalso(mapa)),
            ],
            child: const GestionSedesEmpresaPage(conMapa: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('dibuja el mapa y explica para qué sirve', (tester) async {
      await abrirConMapa(
        tester,
        cubitBasico(),
        mapa: MapaState(
          estado: MapaEstado.listo,
          geometrias: [
            GeometriaZona(
              zonaId: 'z-chap',
              nombre: 'Chapinero',
              nivel: 'LOCALIDAD',
              anillos: _anilloSede,
              atribucion: 'UAECD',
            ),
          ],
        ),
      );

      expect(find.byKey(const Key('sedes_mapa')), findsOneWidget);
      expect(find.text('Dónde quedan tus sedes'), findsOneWidget);
      // La razón por la que el cliente mira un mapa.
      expect(find.textContaining('cae donde esperas'), findsOneWidget);
    });

    testWidgets('informa de las sedes sin ubicación en vez de inventarla', (
      tester,
    ) async {
      // Criterio C2: una sede sin punto capturado no se marca en el centroide
      // de su zona; se cuenta aparte.
      await abrirConMapa(
        tester,
        cubitBasico(),
        mapa: MapaState(
          estado: MapaEstado.listo,
          geometrias: [
            GeometriaZona(
              zonaId: 'z-chap',
              nombre: 'Chapinero',
              nivel: 'LOCALIDAD',
              anillos: _anilloSede,
              atribucion: 'UAECD',
            ),
          ],
          sitiosSinUbicacion: 2,
        ),
      );

      expect(
        find.byKey(const Key('mapa_sitios_sin_ubicacion')),
        findsOneWidget,
      );
      expect(find.textContaining('2 sede(s) sin ubicación'), findsOneWidget);
    });

    testWidgets('sin la bandera la pantalla no monta el mapa', (tester) async {
      await _abrir(tester, cubitBasico());

      expect(find.byKey(const Key('sedes_mapa')), findsNothing);
    });
  });
}

/// Cubit de mapa con estado fijo: la pantalla de sedes no debe depender de la
/// red para probarse.
class _MapaFalso extends Cubit<MapaState> implements MapaCubit {
  _MapaFalso(super.initialState);

  @override
  Future<void> cargar() async {}

  @override
  Future<void> cargarPanoramica() async {}

  @override
  Future<void> seleccionar(String localidadId) async {}
}

final _anilloSede = GeometriaZona.anillosDesdeGeoJson({
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
