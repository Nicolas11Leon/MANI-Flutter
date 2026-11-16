import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/features/home/data/resumen_inicio.dart';
import 'package:mani/features/home/presentation/pages/inicio_page.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

/// Gateway simulado: responde por ruta y anota las rutas consultadas.
GatewayClient _gateway(
  Map<String, Object> respuestas, {
  List<String>? consultadas,
}) => GatewayClient(
  baseUrl: 'http://gateway.test',
  tokenProvider: () async => 'token',
  maxRetries: 0,
  httpClient: MockClient((req) async {
    consultadas?.add(req.url.path);
    final r = respuestas[req.url.path];
    if (r == null) return http.Response('{"error":"x"}', 500, headers: _json);
    return http.Response(jsonEncode(r), 200, headers: _json);
  }),
);

Map<String, String?> _valores(List<IndicadorResumen> l) => {
  for (final i in l) i.etiqueta: i.valor,
};

class _SesionFija implements FuenteDatosSesion {
  @override
  Future<DatosSesion> cargar() async =>
      const DatosSesion(nombreUsuario: 'Ana Pérez', nombreTenant: 'Tenant A');
}

class _ResumenFijo implements FuenteResumenInicio {
  _ResumenFijo(this.indicadores);
  final List<IndicadorResumen> indicadores;
  RolUsuario? pedido;
  @override
  Future<List<IndicadorResumen>> cargar(RolUsuario rol) async {
    pedido = rol;
    return indicadores;
  }
}

void main() {
  group('US-11.2.3 (SCRUM-1446) — resumen de inicio por el Gateway', () {
    test('cliente: cuenta las sedes de la sesión con la lectura que sirve a '
        'cualquier cliente activo, no la de cliente empresa', () async {
      final rutas = <String>[];
      final fuente = GatewayResumenInicio(
        _gateway({
          '/api/v1/core/solicitudes/sitios': {
            'sitios': [
              {'id': 's-1'},
              {'id': 's-2'},
            ],
          },
        }, consultadas: rutas),
      );

      final r = await fuente.cargar(RolUsuario.cliente);

      expect(_valores(r), {'Sedes registradas': '2'});
      expect(r.single.ruta, '/cliente/sedes');
      expect(rutas, ['/api/v1/core/solicitudes/sitios']);
    });

    test('cliente sin sedes ve 0, no un error', () async {
      final fuente = GatewayResumenInicio(
        _gateway({
          '/api/v1/core/solicitudes/sitios': {'sitios': <dynamic>[]},
        }),
      );

      final r = await fuente.cargar(RolUsuario.cliente);

      expect(_valores(r), {'Sedes registradas': '0'});
    });

    test(
      'cliente: si Core no devuelve las sedes, el valor queda vacío',
      () async {
        final fuente = GatewayResumenInicio(_gateway({}));

        final r = await fuente.cargar(RolUsuario.cliente);

        expect(_valores(r), {'Sedes registradas': null});
      },
    );

    test('aliado: categorías, estado ahora y ausencias', () async {
      final fuente = GatewayResumenInicio(
        _gateway({
          '/api/v1/core/profiles/me/categories': {
            'data': [
              {'id': 'c-1'},
              {'id': 'c-2'},
            ],
          },
          '/api/v1/core/profiles/me/unavailability': {
            'availableNow': false,
            'data': [
              {'id': 'a-1'},
            ],
          },
        }),
      );

      final r = await fuente.cargar(RolUsuario.aliado);

      expect(_valores(r), {
        'Categorías que atiendo': '2',
        'Estado ahora': 'No disponible',
        'Ausencias programadas': '1',
      });
    });

    test('aliado: si falla una consulta, solo ese dato queda vacío', () async {
      final fuente = GatewayResumenInicio(
        _gateway({
          '/api/v1/core/profiles/me/unavailability': {
            'availableNow': true,
            'data': <Object>[],
          },
        }),
      );

      final r = await fuente.cargar(RolUsuario.aliado);

      expect(_valores(r), {
        'Categorías que atiendo': null,
        'Estado ahora': 'Disponible',
        'Ausencias programadas': '0',
      });
    });

    test(
      'aliado: sin la consulta de ausencias, estado y ausencias quedan vacíos',
      () async {
        final fuente = GatewayResumenInicio(
          _gateway({
            '/api/v1/core/profiles/me/categories': {'data': <Object>[]},
          }),
        );

        final r = await fuente.cargar(RolUsuario.aliado);

        expect(_valores(r), {
          'Categorías que atiendo': '0',
          'Estado ahora': null,
          'Ausencias programadas': null,
        });
      },
    );

    test(
      'admin: cuenta solo los aliados pendientes y las categorías',
      () async {
        final fuente = GatewayResumenInicio(
          _gateway({
            '/api/v1/core/aliados/verificacion': [
              {'id': 'a-1', 'estado_verificacion': 'PENDIENTE'},
              {'id': 'a-2', 'estado_verificacion': 'APROBADO'},
              {'id': 'a-3', 'estado_verificacion': 'pendiente'},
            ],
            '/api/v1/core/catalog/categories': {
              'categories': [
                {'id': 'c-1'},
              ],
            },
          }),
        );

        final r = await fuente.cargar(RolUsuario.adminTenant);

        expect(_valores(r), {
          'Aliados por verificar': '2',
          'Categorías del catálogo': '1',
        });
      },
    );

    test('admin: una bandeja que no es lista cuenta cero', () async {
      final fuente = GatewayResumenInicio(
        _gateway({
          '/api/v1/core/aliados/verificacion': {'data': 'inesperado'},
        }),
      );

      final r = await fuente.cargar(RolUsuario.adminTenant);

      expect(_valores(r), {
        'Aliados por verificar': '0',
        'Categorías del catálogo': null,
      });
    });

    test('sin rol reconocible no se consulta nada', () async {
      final rutas = <String>[];
      final fuente = GatewayResumenInicio(_gateway({}, consultadas: rutas));

      expect(await fuente.cargar(RolUsuario.desconocido), isEmpty);
      expect(rutas, isEmpty);
    });
  });

  group('US-11.2.3 (SCRUM-1446) — pantalla de inicio', () {
    Future<void> montar(
      WidgetTester tester, {
      required RolUsuario rol,
      required FuenteResumenInicio resumen,
      ValueChanged<String>? onNavegar,
      Future<void> Function()? onCerrarSesion,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InicioPage(
            rol: rol,
            fuenteSesion: _SesionFija(),
            fuenteResumen: resumen,
            onNavegar: onNavegar ?? (_) {},
            onCerrarSesion: onCerrarSesion,
          ),
        ),
      );
    }

    testWidgets('saluda, muestra el resumen del rol y sus accesos', (
      tester,
    ) async {
      final resumen = _ResumenFijo(const [
        IndicadorResumen(
          etiqueta: 'Aliados por verificar',
          ruta: '/admin/verificacion-aliados',
          valor: '4',
        ),
      ]);
      await montar(tester, rol: RolUsuario.adminTenant, resumen: resumen);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(resumen.pedido, RolUsuario.adminTenant);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Aliados por verificar'), findsOneWidget);
      expect(
        find.byKey(const Key('inicio-acceso-/admin/categorias')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('inicio-acceso-/inicio')), findsNothing);
      // El administrador del tenant no tiene pantallas de cliente ni aliado.
      expect(
        find.byKey(const Key('inicio-acceso-/aliado/solicitudes')),
        findsNothing,
      );
      expect(find.byKey(const Key('inicio-sin-rol')), findsNothing);
    });

    testWidgets('un dato que no se pudo consultar se muestra como raya', (
      tester,
    ) async {
      await montar(
        tester,
        rol: RolUsuario.cliente,
        resumen: _ResumenFijo(const [
          IndicadorResumen(
            etiqueta: 'Sedes registradas',
            ruta: '/cliente/sedes',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('tocar un indicador o un acceso navega a su pantalla', (
      tester,
    ) async {
      final destinos = <String>[];
      await montar(
        tester,
        rol: RolUsuario.aliado,
        resumen: _ResumenFijo(const [
          IndicadorResumen(
            etiqueta: 'Estado ahora',
            ruta: '/aliado/disponibilidad',
            valor: 'Disponible',
          ),
        ]),
        onNavegar: destinos.add,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inicio-indicador-Estado ahora')));
      await tester.tap(
        find.byKey(const Key('inicio-acceso-/aliado/cobertura')),
      );

      expect(destinos, ['/aliado/disponibilidad', '/aliado/cobertura']);
    });

    testWidgets('sin rol reconocible avisa y solo ofrece el perfil', (
      tester,
    ) async {
      await montar(
        tester,
        rol: RolUsuario.desconocido,
        resumen: _ResumenFijo(const []),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inicio-sin-rol')), findsOneWidget);
      expect(
        find.byKey(const Key('inicio-acceso-/perfil/editar')),
        findsOneWidget,
      );
    });

    testWidgets(
      'muestra tarjeta de cerrar sesión cuando onCerrarSesion está configurado y lo ejecuta',
      (tester) async {
        var cerro = false;
        await montar(
          tester,
          rol: RolUsuario.cliente,
          resumen: _ResumenFijo(const []),
          onCerrarSesion: () async => cerro = true,
        );
        await tester.pumpAndSettle();

        final cardSesion = find.byKey(const Key('inicio-card-sesion'));
        await tester.scrollUntilVisible(cardSesion, 200);
        expect(cardSesion, findsOneWidget);
        // La pantalla pinta una tarjeta por entrada del menú del rol, así que
        // al crecer el menú el botón queda por debajo del pliegue y un toque
        // a ciegas no aterriza. Se asegura la visibilidad antes de tocar.
        await tester.ensureVisible(
          find.byKey(const Key('inicio-cerrar-sesion')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('inicio-cerrar-sesion')));
        await tester.pumpAndSettle();
        expect(cerro, isTrue);
      },
    );
  });
}
