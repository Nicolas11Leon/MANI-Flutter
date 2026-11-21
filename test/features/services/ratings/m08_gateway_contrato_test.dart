import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/features/services/ratings/data/calificacion_cierre_datasource.dart';
import 'package:mani/features/services/ratings/data/politica_cancelacion_datasource.dart';
import 'package:mani/features/services/ratings/domain/calificacion_cierre_modelos.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

/// M-08 por el Gateway con las respuestas tal como las arma Core (ratings.controller.js y
/// calculoPenalizacionCancelacion.js), para que la app no muestre «sin penalización» por leer otra forma.
void main() {
  late List<http.Request> alGateway;
  late http.Response Function(http.Request) responder;

  GatewayClient gateway() => GatewayClient(
    baseUrl: 'http://gateway.local',
    tokenProvider: () async => 'jwt-de-prueba',
    correlationId: () => 'corr-test',
    httpClient: MockClient((r) async {
      alGateway.add(r);
      return responder(r);
    }),
  );

  setUp(() => alGateway = []);

  group('SCRUM-878 · vista previa de cancelación', () {
    test(
      'lee la respuesta real de Core: cancelación tardía con monto',
      () async {
        responder = (_) => http.Response(
          jsonEncode({
            'penalizacion': {
              'solicitudId': 'sol-1',
              'estadoActual': 'ASIGNADA',
              'aplicaPenalizacion': true,
              'montoPenalizacion': 20000,
              'moneda': 'COP',
              'razon': 'CANCELACION_TARDIA_SEGUN_POLITICA',
              'politicaActiva': true,
              'tipoCobro': 'MONTO_FIJO',
              'valorPolitica': 20000,
              'ventanaGratuitaMinutos': 15,
              'minutosTranscurridos': 42.5,
            },
            'correlationId': 'corr-test',
          }),
          200,
          headers: _json,
        );
        final p = await GatewayFuenteModuloM08(
          gateway(),
        ).previsualizarCancelacion('sol-1');

        expect(
          alGateway.single.url.path,
          '/api/v1/core/solicitudes/me/sol-1/cancelacion-preview',
        );
        expect(p.aplicaPenalizacion, isTrue);
        expect(p.montoPenalizacion, 20000);
        expect(p.politicaActiva, isTrue);
        expect(p.cancelable, isTrue);
        expect(p.motivoPenalizacion, 'CANCELACION_TARDIA_SEGUN_POLITICA');
        expect(
          p.resumenUsuario,
          'Penalización por cancelación tardía: \$20000',
        );
      },
    );

    test('sin política vigente no hay penalización', () async {
      responder = (_) => http.Response(
        jsonEncode({
          'penalizacion': {
            'solicitudId': 'sol-1',
            'estadoActual': 'ASIGNADA',
            'aplicaPenalizacion': false,
            'montoPenalizacion': 0,
            'razon': 'SIN_POLITICA_VIGENTE',
            'politicaActiva': false,
          },
        }),
        200,
        headers: _json,
      );
      final p = await GatewayFuenteModuloM08(
        gateway(),
      ).previsualizarCancelacion('sol-1');
      expect(p.aplicaPenalizacion, isFalse);
      expect(p.politicaActiva, isFalse);
      expect(p.resumenUsuario, 'Sin penalización por cancelación (\$0).');
    });

    test('una solicitud ya cancelada no es cancelable', () {
      final p = VistaPreviaPenalizacion.fromJson({
        'solicitudId': 'sol-1',
        'estadoActual': 'CANCELADA',
        'aplicaPenalizacion': true,
        'montoPenalizacion': 5000,
        'politicaActiva': true,
      });
      expect(p.cancelable, isFalse);
    });
  });

  group('SCRUM-878 · política de cancelación del tenant', () {
    test(
      'GET y PUT a /tenants/me/politica-cancelacion con la forma de Core',
      () async {
        responder = (r) => http.Response(
          jsonEncode({
            'politica': {
              'tenantId': 't-1',
              'activa': r.method == 'PUT',
              'ventanaGratuitaMinutos': 30,
              'tipoCobro': 'PORCENTAJE',
              'valor': 20,
              'estadosGravables': ['ASIGNADA', 'COTIZANDO', 'ACEPTADA'],
              'configurada': r.method == 'PUT',
            },
          }),
          200,
          headers: _json,
        );
        final fuente = GatewayFuentePoliticaCancelacion(gateway());

        final actual = await fuente.obtener();
        final guardada = await fuente.guardar(actual.copiar(activa: true));

        expect(alGateway[0].method, 'GET');
        expect(
          alGateway[0].url.path,
          '/api/v1/core/tenants/me/politica-cancelacion',
        );
        expect(actual.activa, isFalse);
        expect(alGateway[1].method, 'PUT');
        expect(jsonDecode(alGateway[1].body), {
          'activa': true,
          'ventanaGratuitaMinutos': 30,
          'tipoCobro': 'PORCENTAJE',
          'valor': 20.0,
        });
        expect(guardada.activa, isTrue);
        expect(guardada.tipoCobro, TipoCobroPenalizacion.porcentaje);
      },
    );

    test('un 403 de Core (rol sin permiso) llega como sinPermiso', () async {
      responder = (_) => http.Response(
        jsonEncode({
          'error': 'MANI-PEN-403: solo el administrador',
          'code': 'MANI-PEN-403',
        }),
        403,
        headers: _json,
      );
      expect(
        () => GatewayFuentePoliticaCancelacion(gateway()).guardar(
          const PoliticaCancelacion(
            activa: true,
            ventanaGratuitaMinutos: 15,
            tipoCobro: TipoCobroPenalizacion.montoFijo,
            valor: 1,
          ),
        ),
        throwsA(
          isA<ModuloM08Failure>().having(
            (f) => f.tipo,
            'tipo',
            ModuloM08ErrorTipo.sinPermiso,
          ),
        ),
      );
    });
  });

  // Respuesta de Core (PgRatingsRepository.estadoCalificacionesYCierre + mapearCalificacion).
  Map<String, dynamic> resumenCore({
    required String estado,
    Map<String, dynamic>? cliente,
    Map<String, dynamic>? aliado,
  }) => {
    'calificaciones': {'clienteAlAliado': cliente, 'aliadoAlCliente': aliado},
    'cierre': {
      'solicitudId': 'sol-1',
      'estadoSolicitud': estado,
      'calificacionClienteRegistrada': cliente != null,
      'calificacionAliadoRegistrada': aliado != null,
      'cierreCompleto':
          estado == 'CERRADA' && cliente != null && aliado != null,
      'cerradaEn': estado == 'CERRADA' ? '2026-11-04T15:00:00.000Z' : null,
    },
    'reputacionAliado': null,
    'correlationId': 'corr-test',
  };

  Map<String, dynamic> califCore(String direccion, int puntaje) => {
    'id': 'cal-$direccion',
    'solicitudId': 'sol-1',
    'autorId': 'u-1',
    'destinatarioId': 'u-2',
    'direccion': direccion,
    'puntaje': puntaje,
    'comentario': null,
    'creadaEn': '2026-11-04T14:00:00.000Z',
  };

  group('SCRUM-874, 875 y 1418 · calificaciones y cierre', () {
    test(
      'GET lee estado, calificaciones y cierre de la respuesta real de Core',
      () async {
        responder = (_) => http.Response(
          jsonEncode(
            resumenCore(
              estado: 'FINALIZADA',
              cliente: califCore('CLIENTE_A_ALIADO', 5),
            ),
          ),
          200,
          headers: _json,
        );
        final r = await GatewayFuenteModuloM08(
          gateway(),
        ).obtenerCalificaciones('sol-1');

        expect(
          alGateway.single.url.path,
          '/api/v1/core/solicitudes/sol-1/calificaciones',
        );
        expect(r.estado, 'FINALIZADA');
        expect(r.solicitudId, 'sol-1');
        expect(r.clienteAAliado!.puntaje, 5);
        expect(r.clienteAAliado!.esDeCliente, isTrue);
        expect(r.aliadoACliente, isNull);
        expect(r.cierre.tieneCalificacionCliente, isTrue);
        expect(r.cierre.tieneCalificacionAliado, isFalse);
        expect(r.cierre.cierreCompleto, isFalse);
        expect(
          r.cierre.etiquetaEstadoCierre,
          'Pendiente de calificación del aliado',
        );
      },
    );

    test(
      'POST con la segunda calificación deja la solicitud CERRADA y el cierre completo',
      () async {
        responder = (_) => http.Response(
          jsonEncode({
            'calificacion': califCore('ALIADO_A_CLIENTE', 4),
            ...resumenCore(
              estado: 'CERRADA',
              cliente: califCore('CLIENTE_A_ALIADO', 5),
              aliado: califCore('ALIADO_A_CLIENTE', 4),
            ),
          }),
          201,
          headers: _json,
        );
        final r = await GatewayFuenteModuloM08(
          gateway(),
        ).registrarCalificacion(solicitudId: 'sol-1', puntaje: 4);

        expect(alGateway.single.method, 'POST');
        expect(jsonDecode(alGateway.single.body), {'puntaje': 4});
        expect(r.estado, 'CERRADA');
        expect(r.aliadoACliente!.esDeAliado, isTrue);
        expect(r.cierre.cierreCompleto, isTrue);
        expect(
          r.cierre.etiquetaEstadoCierre,
          'Cerrada (ambas calificaciones registradas)',
        );
      },
    );
  });

  group('SCRUM-879 y 880 · historial', () {
    test('historial del cliente con la forma de Core', () async {
      responder = (_) => http.Response(
        jsonEncode({
          'historial': [
            {
              'id': 'sol-1',
              'estado': 'CERRADA',
              'categoria': 'Plomería',
              'descripcion': 'Fuga',
              'direccion': 'Calle 1',
              'zonaDeclarada': {
                'nombre': 'Chapinero',
                'nivel': 'LOCALIDAD',
                'zonaPadre': 'Bogotá',
              },
              'aliado': {'id': 'a-1', 'nombreRazonSocial': 'Ana Aliada'},
              'penalizacion': {'aplicada': false, 'monto': 0, 'motivo': null},
              'calificaciones': {
                'clienteAlAliado': {'puntaje': 5, 'comentario': null},
                'aliadoAlCliente': {'puntaje': 4, 'comentario': 'Puntual'},
                'cierreCompleto': true,
              },
              'creadaEn': '2026-11-01T10:00:00.000Z',
              'cerradaEn': '2026-11-02T10:00:00.000Z',
            },
          ],
          'totalCount': 1,
        }),
        200,
        headers: _json,
      );
      final h = (await GatewayFuenteModuloM08(
        gateway(),
      ).listarHistorialCliente()).single;

      expect(
        alGateway.single.url.path,
        '/api/v1/core/solicitudes/me/historial',
      );
      expect(h.zona, 'Chapinero');
      expect(h.zonaPadre, 'Bogotá');
      expect(h.nombreContraparte, 'Ana Aliada');
      expect(h.calificacionEmitida!.puntaje, 5);
      expect(h.calificacionRecibida!.puntaje, 4);
    });

    test('historial del aliado con la forma de Core', () async {
      responder = (_) => http.Response(
        jsonEncode({
          'trabajos': [
            {
              'id': 'sol-2',
              'estado': 'CANCELADA',
              'categoria': 'Pintura',
              'descripcion': 'Pared',
              'direccion': 'Calle 2',
              'zonaDeclarada': {'nombre': 'Usaquén'},
              'valorCotizado': 150000,
              'penalizacionCancelacion': {'aplicada': true, 'monto': 20000},
              'calificaciones': {
                'aliadoAlCliente': {'puntaje': 3, 'comentario': null},
                'clienteAlAliado': null,
                'cierreCompleto': false,
              },
              'creadaEn': '2026-11-01T10:00:00.000Z',
            },
          ],
          'totalCount': 1,
        }),
        200,
        headers: _json,
      );
      final h = (await GatewayFuenteModuloM08(
        gateway(),
      ).listarHistorialAliado()).single;

      expect(alGateway.single.url.path, '/api/v1/core/allies/me/history');
      expect(h.zona, 'Usaquén');
      expect(h.valorTotal, 150000);
      expect(h.penalizacionAplicada, isTrue);
      expect(h.penalizacionMonto, 20000);
      expect(h.calificacionEmitida!.puntaje, 3);
      expect(h.calificacionRecibida, isNull);
    });
  });

  group('Calificaciones privadas entre participantes', () {
    test(
      'historial del cliente: la recibida llega oculta y solo se marca que existe',
      () async {
        responder = (_) => http.Response(
          jsonEncode({
            'historial': [
              {
                'id': 'sol-9',
                'estado': 'CERRADA',
                'categoria': 'Plomería',
                'descripcion': 'Fuga',
                'direccion': 'Calle 1',
                'zonaDeclarada': {'nombre': 'Chapinero'},
                'calificaciones': {
                  'clienteAlAliado': {'puntaje': 1, 'comentario': null},
                  'aliadoAlCliente': null,
                  'calificacionRecibidaRegistrada': true,
                  'cierreCompleto': true,
                },
                'creadaEn': '2026-11-01T10:00:00.000Z',
              },
            ],
            'totalCount': 1,
          }),
          200,
          headers: _json,
        );
        final h = (await GatewayFuenteModuloM08(
          gateway(),
        ).listarHistorialCliente()).single;

        expect(h.calificacionEmitida!.puntaje, 1);
        expect(h.calificacionRecibida, isNull);
        expect(h.calificacionRecibidaRegistrada, isTrue);
      },
    );
  });
}
