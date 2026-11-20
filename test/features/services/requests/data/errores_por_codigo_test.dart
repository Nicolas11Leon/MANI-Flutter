import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/network/gateway_exception.dart';
import 'package:mani/features/services/requests/data/repositories/solicitudes_cliente_repository_impl.dart';
import 'package:mani/features/services/requests/domain/failures/solicitud_failure.dart';

/// SCRUM-1643: los errores al publicar una solicitud se traducen por el código
/// que envía Core. El status HTTP solo decide cuando el código no se conoce.
GatewayException _error(int status, String code, {String? ref}) =>
    GatewayException.fromStatus(
      status,
      detalle: '$code: mensaje de Core',
      correlationId: ref,
      cuerpo: {'code': code},
    );

void main() {
  test(
    'cada código MANI-SOL conocido se traduce a su tipo, sea cual sea el status',
    () {
      const casos = <String, SolicitudErrorTipo>{
        'MANI-SOL-401': SolicitudErrorTipo.sinSesion,
        'MANI-SOL-403C': SolicitudErrorTipo.noEsCliente,
        'MANI-SOL-422C': SolicitudErrorTipo.categoriaInvalida,
        'MANI-SOL-422D': SolicitudErrorTipo.descripcionInvalida,
        'MANI-SOL-422F': SolicitudErrorTipo.fotosInvalidas,
        'MANI-SOL-422S': SolicitudErrorTipo.ubicacionInvalida,
        'MANI-SOL-422Z': SolicitudErrorTipo.zonaInvalida,
      };
      casos.forEach((codigo, tipo) {
        // El status es otro a propósito: manda el código.
        final f = SolicitudesClienteRepositoryImpl.mapearGateway(
          _error(500, codigo),
        );
        expect(f.tipo, tipo, reason: codigo);
        expect(f.codigo, codigo);
      });
    },
  );

  test(
    'un 403 con MANI-PLA-403 ya no dice «solo los clientes pueden publicar»',
    () {
      final f = SolicitudesClienteRepositoryImpl.mapearGateway(
        _error(403, 'MANI-PLA-403'),
      );
      expect(f.tipo, SolicitudErrorTipo.sinPermiso);
      expect(f.mensajeUsuario, isNot(contains('Solo los clientes')));
    },
  );

  test(
    'el 403 del cliente sí conserva su mensaje cuando el código lo dice',
    () {
      final f = SolicitudesClienteRepositoryImpl.mapearGateway(
        _error(403, 'MANI-SOL-403C'),
      );
      expect(f.tipo, SolicitudErrorTipo.noEsCliente);
      expect(f.mensajeUsuario, contains('Solo los clientes'));
    },
  );

  test('con un código desconocido o sin código decide el status HTTP', () {
    SolicitudErrorTipo tipo(GatewayException e) =>
        SolicitudesClienteRepositoryImpl.mapearGateway(e).tipo;

    expect(tipo(_error(403, 'MANI-XYZ-999')), SolicitudErrorTipo.sinPermiso);
    expect(tipo(_error(401, 'MANI-XYZ-999')), SolicitudErrorTipo.sinSesion);
    expect(tipo(_error(413, 'MANI-XYZ-999')), SolicitudErrorTipo.fotoMuyPesada);
    expect(tipo(_error(503, 'MANI-XYZ-999')), SolicitudErrorTipo.desconocido);
    expect(
      tipo(GatewayException.fromStatus(404)),
      SolicitudErrorTipo.desconocido,
    );
    expect(
      tipo(const GatewayException(message: 'sin red')),
      SolicitudErrorTipo.sinConexion,
    );
  });

  test('el error lleva el código y la referencia para el diagnóstico', () {
    final f = SolicitudesClienteRepositoryImpl.mapearGateway(
      _error(422, 'MANI-SOL-422Z', ref: 'corr-77'),
    );
    expect(f.codigo, 'MANI-SOL-422Z');
    expect(f.referencia, 'corr-77');
    expect(f.lineaDeDiagnostico, 'Código: MANI-SOL-422Z · Ref: corr-77');
  });

  test('un error local (sin servicio) no tiene línea de diagnóstico', () {
    expect(
      const SolicitudFailure(
        SolicitudErrorTipo.fotoMuyPesada,
      ).lineaDeDiagnostico,
      isNull,
    );
  });
}
