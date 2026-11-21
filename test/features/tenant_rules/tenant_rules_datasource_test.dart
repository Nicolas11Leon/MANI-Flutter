import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/network/gateway_exception.dart';
import 'package:mani/features/tenant_rules/data/tenant_rules_datasource.dart';
import 'package:mani/features/tenant_rules/domain/regla_tenant.dart';

const _reglasJson = {
  'ordenListado': {'criterio': 'cobertura'},
  'alertaTarifa': {'toleranciaPorcentaje': 25},
  'comision': {'porcentaje': 12.5},
  'cancelacion': {'ventanaHoras': 6, 'penalizacionPorcentaje': 40},
  'oferta': {'minutosParaAceptar': 30},
};

/// Arma la fuente sobre un [GatewayClient] real cuyo HTTP responde [responder].
(GatewayFuenteReglasTenant, List<http.Request>) _fuente(
  http.Response Function(http.Request) responder,
) {
  final vistas = <http.Request>[];
  final gateway = GatewayClient(
    baseUrl: 'http://gateway',
    tokenProvider: () async => 'tok',
    httpClient: MockClient((req) async {
      vistas.add(req);
      return responder(req);
    }),
  );
  return (GatewayFuenteReglasTenant(gateway), vistas);
}

http.Response _json(Object cuerpo, [int estado = 200]) => http.Response(
  jsonEncode(cuerpo),
  estado,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('SCRUM-1366 · fuente de reglas operativas del tenant', () {
    test('getVigente lee la versión, el origen y las reglas propias', () async {
      final (fuente, vistas) = _fuente(
        (_) => _json({
          'id': 'r1',
          'version': 3,
          'origen': 'PROPIO',
          'estado': 'VIGENTE',
          'reglas': _reglasJson,
          'auditoria': {'actor': 'admin.t1'},
        }),
      );

      final v = await fuente.getVigente();

      expect(vistas.single.method, 'GET');
      expect(vistas.single.url.path, GatewayFuenteReglasTenant.rutaVigente);
      expect(vistas.single.headers['Authorization'], 'Bearer tok');
      expect(v.id, 'r1');
      expect(v.version, 3);
      expect(v.origen, 'PROPIO');
      expect(v.estado, 'VIGENTE');
      expect(v.auditoria, {'actor': 'admin.t1'});
      expect(v.reglas.criterioOrden, 'COBERTURA');
      expect(v.reglas.toleranciaTarifa, 25);
      expect(v.reglas.comisionPorcentaje, 12.5);
      expect(v.reglas.ventanaCancelacionHoras, 6);
      expect(v.reglas.penalizacionCancelacion, 40);
      expect(v.reglas.minutosParaAceptarOferta, 30);
    });

    test('sin reglas propias se usan los valores por omisión', () async {
      final (fuente, _) = _fuente((_) => _json(<String, dynamic>{}));

      final v = await fuente.getVigente();

      expect(v.id, isNull);
      expect(v.version, 0);
      expect(v.origen, 'POR_OMISION');
      expect(v.reglas.criterioOrden, 'CALIFICACION');
      expect(v.reglas.toleranciaTarifa, 10);
      expect(v.reglas.comisionPorcentaje, 10);
      expect(v.reglas.ventanaCancelacionHoras, 2);
      expect(v.reglas.penalizacionCancelacion, 20);
      expect(v.reglas.minutosParaAceptarOferta, 15);
    });

    test('getHistorial convierte cada versión anterior', () async {
      final (fuente, vistas) = _fuente(
        (_) => _json({
          'items': [
            {
              'id': 'h2',
              'version': 2,
              'estado': 'VIGENTE',
              'reglas': _reglasJson,
              'auditoria': {'motivo': 'ajuste'},
            },
            <String, dynamic>{},
          ],
        }),
      );

      final h = await fuente.getHistorial();

      expect(vistas.single.url.path, GatewayFuenteReglasTenant.rutaHistorial);
      expect(h, hasLength(2));
      expect(h.first.id, 'h2');
      expect(h.first.version, 2);
      expect(h.first.estado, 'VIGENTE');
      expect(h.first.auditoria, {'motivo': 'ajuste'});
      expect(h.first.reglas.comisionPorcentaje, 12.5);
      // Un ítem incompleto no rompe la lista: toma los valores por omisión.
      expect(h.last.id, '');
      expect(h.last.version, 1);
      expect(h.last.estado, 'HISTORICA');
    });

    test('getHistorial sin ítems devuelve una lista vacía', () async {
      final (fuente, _) = _fuente((_) => _json(<String, dynamic>{}));
      expect(await fuente.getHistorial(), isEmpty);
    });

    test('actualizar envía la versión esperada y las reglas con PUT', () async {
      final (fuente, vistas) = _fuente(
        (req) => _json({
          'version': 4,
          'origen': 'PROPIO',
          'reglas': (jsonDecode(req.body) as Map)['reglas'],
        }),
      );
      final reglas = ReglasOperativas.fromJson(_reglasJson);

      final v = await fuente.actualizar(expectedVersion: 3, reglas: reglas);

      final req = vistas.single;
      expect(req.method, 'PUT');
      expect(req.url.path, GatewayFuenteReglasTenant.rutaVigente);
      final cuerpo = jsonDecode(req.body) as Map<String, dynamic>;
      expect(cuerpo['expectedVersion'], 3);
      expect(cuerpo['reglas'], reglas.toJson());
      expect(v.version, 4);
      expect(v.reglas.criterioOrden, 'COBERTURA');
    });

    test('un 409 de Core llega como GatewayException', () async {
      final (fuente, _) = _fuente(
        (_) => _json({
          'error': {
            'code': 'MANI-REG-409',
            'message': 'Versión desactualizada',
          },
        }, 409),
      );

      await expectLater(
        fuente.actualizar(
          expectedVersion: 1,
          reglas: ReglasOperativas.fromJson(const {}),
        ),
        throwsA(
          isA<GatewayException>().having((e) => e.statusCode, 'status', 409),
        ),
      );
    });
  });
}
