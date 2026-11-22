import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:mani/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mani/features/auth/domain/entities/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// US-02.1.1-M3: el registro de aliado persona natural sale por el Gateway y
/// nunca toca Supabase directamente.
void main() {
  late List<http.Request> alGateway;
  late List<http.BaseRequest> aSupabase;
  late http.Response Function(http.Request) responder;

  AuthRemoteDataSource datasource() {
    final supabase = SupabaseClient(
      'http://supabase.local',
      'anon-key',
      httpClient: MockClient((r) async {
        aSupabase.add(r);
        return http.Response('{}', 200);
      }),
    );
    final gateway = GatewayClient(
      baseUrl: 'http://gateway.local',
      tokenProvider: () async => null,
      correlationId: () => 'corr-test',
      httpClient: MockClient((r) async {
        alGateway.add(r);
        return responder(r);
      }),
    );
    return AuthRemoteDataSource(client: supabase, gateway: gateway);
  }

  Map<String, String> doc(String tipo, String nombre, String contenido) => {
    'tipo_documento': tipo,
    'nombre_archivo': nombre,
    'contenido_base64': base64Encode(utf8.encode(contenido)),
  };

  Future<Map<String, dynamic>> registrar(
    IAuthRemoteDataSource ds, {
    List<Map<String, String>>? documentos,
  }) => ds.registrarAliadoPersonaNatural(
    email: '  pedro@correo.co ',
    password: 'Secreta123!',
    nombreCompleto: ' Pedro Pérez ',
    tenantId: 'tenant-a',
    categoriaId: 'cat-1',
    documentosKYC:
        documentos ??
        [
          doc('CEDULA_CIUDADANIA', 'cedula.pdf', 'PDF-CEDULA'),
          doc('RUT_CERTIFICADO', 'rut.pdf', 'PDF-RUT'),
        ],
  );

  setUp(() {
    alGateway = [];
    aSupabase = [];
    responder = (_) => http.Response(
      jsonEncode({'usuario_id': 'u-1', 'estado_verificacion': 'PENDIENTE'}),
      201,
      headers: {'content-type': 'application/json'},
    );
  });

  group('datasource', () {
    test('una sola petición, al Gateway, ninguna a Supabase', () async {
      await registrar(datasource());

      expect(aSupabase, isEmpty);
      expect(alGateway, hasLength(1));
      final r = alGateway.single;
      expect(r.method, 'POST');
      expect(
        r.url.toString(),
        'http://gateway.local${AuthRemoteDataSource.rutaRegistroPersonaNatural}',
      );
      expect(r.headers['X-Correlation-ID'], 'corr-test');
    });

    test('los documentos KYC viajan como archivos en el multipart', () async {
      await registrar(datasource());

      final cuerpo = utf8.decode(alGateway.single.bodyBytes);
      expect(
        cuerpo,
        contains('name="cedula_ciudadania"; filename="cedula.pdf"'),
      );
      expect(cuerpo, contains('PDF-CEDULA'));
      expect(cuerpo, contains('name="rut_certificado"; filename="rut.pdf"'));
      expect(cuerpo, contains('PDF-RUT'));
      expect(cuerpo, isNot(contains('ruta_storage')));
    });

    test('envía los datos limpios', () async {
      await registrar(datasource());

      final cuerpo = utf8.decode(alGateway.single.bodyBytes);
      String campo(String n) => RegExp(
        'name="$n"(?:\r\n[^\r]+)*\r\n\r\n([^\r]*)',
      ).firstMatch(cuerpo)!.group(1)!;
      expect(campo('email'), 'pedro@correo.co');
      expect(campo('fullName'), 'Pedro Pérez');
      expect(campo('categoriaId'), 'cat-1');
    });

    test('el tenant no viaja en el cuerpo, solo como header '
        'de preautenticación (X-Tenant-Slug ADR-0018)', () async {
      await registrar(datasource());

      final r = alGateway.single;
      final cuerpo = utf8.decode(r.bodyBytes);
      expect(cuerpo, isNot(contains('tenant')));
      expect(r.headers[AuthRemoteDataSource.headerTenantSlug], 'tenant-a');
      expect(r.headers.containsKey('X-Tenant-Id'), isFalse);
      expect(r.headers.containsKey('X-Tenant-ID'), isFalse);
    });

    test(
      'cada documento sale con su tipo MIME, no como octet-stream',
      () async {
        await registrar(
          datasource(),
          documentos: [
            doc('CEDULA_CIUDADANIA', 'cedula.PDF', 'PDF-CEDULA'),
            doc('RUT_CERTIFICADO', 'rut.jpg', 'JPG-RUT'),
          ],
        );

        final cuerpo = alGateway.single.body;
        expect(cuerpo, contains('content-type: application/pdf'));
        expect(cuerpo, contains('content-type: image/jpeg'));
        expect(cuerpo, isNot(contains('application/octet-stream')));
      },
    );

    test('tipo MIME por extensión', () {
      expect(
        AuthRemoteDataSource.tipoContenidoDocumento('a.pdf'),
        'application/pdf',
      );
      expect(
        AuthRemoteDataSource.tipoContenidoDocumento('a.JPEG'),
        'image/jpeg',
      );
      expect(AuthRemoteDataSource.tipoContenidoDocumento('a.png'), 'image/png');
      expect(AuthRemoteDataSource.tipoContenidoDocumento('a.docx'), isNull);
    });

    test('mantiene la forma de respuesta que espera la UI', () async {
      final res = await registrar(datasource());

      expect(res['success'], isTrue);
      expect(res['usuario_id'], 'u-1');
      expect(res['estado_verificacion'], 'PENDIENTE');
    });

    test('documento sin contenido no se envía', () async {
      final sinContenido = {
        'tipo_documento': 'CEDULA_CIUDADANIA',
        'nombre_archivo': 'cedula.pdf',
        'contenido_base64': '',
      };

      await expectLater(
        registrar(datasource(), documentos: [sinContenido]),
        throwsA(anything),
      );
      expect(alGateway, isEmpty);
    });
  });

  group('repositorio: errores visibles', () {
    Future<AuthFailure> fallo(http.Response respuesta) async {
      responder = (_) => respuesta;
      final repo = AuthRepositoryImpl(remoteDataSource: datasource());
      try {
        await repo.registrarAliadoPersonaNatural(
          email: 'a@b.co',
          password: 'x',
          nombreCompleto: 'N',
          tenantId: 't',
          categoriaId: 'cat-1',
          documentosKYC: [doc('CEDULA_CIUDADANIA', 'c.pdf', 'C')],
        );
      } on AuthFailure catch (e) {
        return e;
      }
      fail('debía lanzar AuthFailure');
    }

    http.Response json(int s, Map<String, Object> b) => http.Response(
      jsonEncode(b),
      s,
      headers: {'content-type': 'application/json'},
    );

    test('400 muestra el campo faltante', () async {
      final e = await fallo(json(400, {'message': 'Falta cedula_ciudadania'}));
      expect(e.message, 'Falta cedula_ciudadania');
    });

    test('409 informa el correo duplicado', () async {
      final e = await fallo(
        json(409, {'message': 'Ya existe una cuenta con este correo'}),
      );
      expect(e.message, 'Ya existe una cuenta con este correo');
    });

    test('5xx da un mensaje genérico sin detalles internos', () async {
      final e = await fallo(json(500, {'message': 'TypeError at line 42'}));
      expect(e.message, isNot(contains('TypeError')));
      expect(e.message, isNot(startsWith('Error en registro')));
    });
  });
}
