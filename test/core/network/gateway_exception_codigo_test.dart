import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/network/gateway_exception.dart';

/// SCRUM-1643: el código de negocio de Core (`MANI-XXX-NNN`) y la referencia de
/// la petición se leen siempre de la misma forma, para mostrarlos y para decidir
/// el mensaje sin depender del texto ni del status HTTP.
void main() {
  group('codigo', () {
    test('sale del campo `code` del cuerpo', () {
      final e = GatewayException.fromStatus(
        403,
        cuerpo: {'code': 'MANI-PLA-403', 'error': 'MANI-PLA-403: x'},
      );
      expect(e.codigo, 'MANI-PLA-403');
    });

    test('si el cuerpo no lo trae, sale del prefijo del mensaje', () {
      final e = GatewayException.fromStatus(
        422,
        detalle: 'MANI-SOL-422Z: zona inválida',
      );
      expect(e.codigo, 'MANI-SOL-422Z');
    });

    test('acepta los códigos con letra final y los de tres letras', () {
      for (final c in ['MANI-SOL-403C', 'MANI-PAG-409K', 'MANI-RLS-400']) {
        expect(
          GatewayException(message: 'x', cuerpo: {'code': c}).codigo,
          c,
          reason: c,
        );
      }
    });

    test('un valor que no tiene la forma MANI-XXX-NNN no es un código', () {
      for (final c in ['INVALID_RECOVERY_TOKEN', 'MANI-SOL', 'mani-sol-422z']) {
        expect(
          GatewayException(message: 'sin código', cuerpo: {'code': c}).codigo,
          isNull,
          reason: c,
        );
      }
      expect(const GatewayException(message: 'sin red').codigo, isNull);
      // Un código a mitad del texto no cuenta: solo el prefijo del mensaje.
      expect(
        const GatewayException(message: 'falló con MANI-SOL-422Z').codigo,
        isNull,
      );
    });
  });

  group('referencia y línea de diagnóstico', () {
    test('prefiere el correlationId del cuerpo y cae al de la cabecera', () {
      expect(
        GatewayException(
          message: 'x',
          correlationId: 'cabecera-1',
          cuerpo: {'correlationId': 'cuerpo-1'},
        ).referencia,
        'cuerpo-1',
      );
      expect(
        GatewayException(
          message: 'x',
          correlationId: 'cabecera-1',
          cuerpo: {'correlationId': 'none'},
        ).referencia,
        'cabecera-1',
        reason: '«none» es el valor de relleno de Core, no una referencia',
      );
      expect(
        const GatewayException(message: 'x', correlationId: 'c-9').referencia,
        'c-9',
      );
    });

    test('la línea tiene el formato «Código: … · Ref: …»', () {
      final e = GatewayException(
        message: 'x',
        statusCode: 403,
        correlationId: 'abc-123',
        cuerpo: {'code': 'MANI-PLA-403'},
      );
      expect(e.lineaDeDiagnostico, 'Código: MANI-PLA-403 · Ref: abc-123');
    });

    test('omite la parte que falta y es null si faltan las dos', () {
      expect(
        GatewayException(
          message: 'x',
          cuerpo: {'code': 'MANI-SOL-422C'},
        ).lineaDeDiagnostico,
        'Código: MANI-SOL-422C',
      );
      expect(
        const GatewayException(
          message: 'x',
          correlationId: 'solo-ref',
        ).lineaDeDiagnostico,
        'Ref: solo-ref',
      );
      expect(const GatewayException(message: 'x').lineaDeDiagnostico, isNull);
    });
  });
}
