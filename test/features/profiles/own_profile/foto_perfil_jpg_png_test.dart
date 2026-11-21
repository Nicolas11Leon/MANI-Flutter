import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/network/gateway_exception.dart';
import 'package:mani/features/profiles/own_profile/data/datasources/perfil_propio_remote_datasource.dart';
import 'package:mani/features/profiles/own_profile/presentation/pages/editar_perfil_page.dart';

/// SCRUM-1389 (C2): la foto de perfil acepta solo JPG o PNG de hasta 5 MB
/// (decisión del PO del 19-oct en SCRUM-854). Lo inválido no sale hacia el
/// Gateway, y el 413/400 de la subida llegan con el mismo mensaje.
void main() {
  const mensaje = 'La foto debe ser JPG o PNG de hasta 5 MB';
  const limite = GatewayPerfilPropioDataSource.tamanoMaximoFoto;
  const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

  late List<http.BaseRequest> peticiones;
  late http.Response Function(http.Request) responder;

  Map<String, dynamic> perfil({String? photoUrl}) => {
    'id': 'u-1',
    'tenantId': 'trama-demo',
    'role': 'ALLY',
    'fullName': 'Carlos Mendoza',
    'status': 'VERIFIED',
    'phone': '+573001234567',
    'address': 'Av. El Dorado # 68B-85',
    'photoUrl': photoUrl,
  };

  GatewayPerfilPropioDataSource datasource() => GatewayPerfilPropioDataSource(
    GatewayClient(
      baseUrl: 'https://gateway.mani.local',
      tokenProvider: () async => 'jwt-token',
      maxRetries: 0,
      httpClient: MockClient((r) async {
        peticiones.add(r);
        return responder(r);
      }),
    ),
  );

  Uint8List bytes(int n) => Uint8List(n);

  setUp(() {
    peticiones = [];
    responder = (_) => http.Response(
      jsonEncode({'profile': perfil(photoUrl: 'trama-demo/u-1/avatar.png')}),
      200,
      headers: jsonHeaders,
    );
  });

  group('validación previa en la app', () {
    test('WEBP se rechaza sin llamar al Gateway', () async {
      await expectLater(
        datasource().subirFotoPerfil(
          nombreArchivo: 'avatar.webp',
          bytes: bytes(1024),
        ),
        throwsA(isA<FotoPerfilInvalidaException>()),
      );
      expect(peticiones, isEmpty);
    });

    test(
      'un archivo de 5 MB + 1 byte se rechaza sin llamar al Gateway',
      () async {
        await expectLater(
          datasource().subirFotoPerfil(
            nombreArchivo: 'avatar.png',
            bytes: bytes(limite + 1),
          ),
          throwsA(isA<FotoPerfilInvalidaException>()),
        );
        expect(peticiones, isEmpty);
      },
    );

    test('el mensaje es exactamente el acordado', () {
      expect(const FotoPerfilInvalidaException().toString(), mensaje);
    });

    test('esFotoValida: formatos y límite exacto de 5 MB', () {
      bool valida(String nombre, int n) =>
          GatewayPerfilPropioDataSource.esFotoValida(nombre, bytes(n));
      expect(valida('a.png', limite), isTrue);
      expect(valida('a.JPG', 10), isTrue);
      expect(valida('a.jpeg', 10), isTrue);
      expect(valida('a.png', limite + 1), isFalse);
      expect(valida('a.webp', 10), isFalse);
      expect(valida('a.gif', 10), isFalse);
    });
  });

  group('subida por el Gateway', () {
    test('un PNG válido se envía en multipart y devuelve el perfil', () async {
      final actualizado = await datasource().subirFotoPerfil(
        nombreArchivo: 'avatar.png',
        bytes: bytes(2048),
      );

      final r = peticiones.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/api/v1/core/profiles/me/photo');
      // MockClient entrega el multipart ya serializado como Request.
      expect(r.headers['content-type'], startsWith('multipart/form-data'));
      expect(
        (r as http.Request).body,
        contains('name="photo"; filename="avatar.png"'),
      );
      expect(actualizado.photoUrl, 'trama-demo/u-1/avatar.png');
    });

    test('un JPG en el límite de 5 MB también se envía', () async {
      await datasource().subirFotoPerfil(
        nombreArchivo: 'avatar.jpg',
        bytes: bytes(limite),
      );
      expect(peticiones, hasLength(1));
    });

    // SCRUM-1634: Core valida el MIME declarado de la parte; sin él la
    // parte sale como application/octet-stream y Core responde 400.
    for (final (nombre, mime) in [
      ('avatar.png', 'image/png'),
      ('avatar.PNG', 'image/png'),
      ('avatar.jpg', 'image/jpeg'),
      ('avatar.jpeg', 'image/jpeg'),
    ]) {
      test('$nombre se envía con Content-Type $mime en la parte', () async {
        await datasource().subirFotoPerfil(
          nombreArchivo: nombre,
          bytes: bytes(64),
        );
        final cuerpo = (peticiones.single as http.Request).body;
        expect(cuerpo, contains('content-type: $mime'));
        expect(cuerpo, isNot(contains('application/octet-stream')));
      });
    }

    for (final status in [413, 400]) {
      test('$status de la subida se traduce al mensaje de la foto', () async {
        responder = (_) => http.Response(
          jsonEncode({'error': 'File too large', 'code': 'VALIDATION_ERROR'}),
          status,
          headers: jsonHeaders,
        );
        await expectLater(
          datasource().subirFotoPerfil(
            nombreArchivo: 'avatar.png',
            bytes: bytes(2048),
          ),
          throwsA(
            isA<FotoPerfilInvalidaException>().having(
              (e) => e.toString(),
              'mensaje',
              mensaje,
            ),
          ),
        );
      });
    }

    test('otros errores no se disfrazan de error de foto', () async {
      responder = (_) => http.Response('{}', 500, headers: jsonHeaders);
      await expectLater(
        datasource().subirFotoPerfil(
          nombreArchivo: 'avatar.png',
          bytes: bytes(2048),
        ),
        throwsA(isA<GatewayException>()),
      );
    });
  });

  group('pantalla', () {
    Future<void> montar(
      WidgetTester tester, {
      required String nombre,
      required int tamano,
      http.Response? respuestaSubida,
    }) async {
      responder = (r) => r.method == 'POST' && respuestaSubida != null
          ? respuestaSubida
          : http.Response(
              jsonEncode({'profile': perfil()}),
              200,
              headers: jsonHeaders,
            );
      await tester.pumpWidget(
        MaterialApp(
          home: EditarPerfilPage(
            dataSource: datasource(),
            selectorImagen: () async => (nombre: nombre, bytes: bytes(tamano)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('btn-cambiar-foto-perfil')),
      );
      await tester.tap(find.byKey(const Key('btn-cambiar-foto-perfil')));
      await tester.pumpAndSettle();
    }

    testWidgets('WEBP muestra el aviso y no se sube', (tester) async {
      await montar(tester, nombre: 'avatar.webp', tamano: 1024);

      expect(find.text(mensaje), findsOneWidget);
      expect(peticiones.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('5 MB + 1 byte muestra el aviso y no se sube', (tester) async {
      await montar(tester, nombre: 'avatar.png', tamano: limite + 1);

      expect(find.text(mensaje), findsOneWidget);
      expect(peticiones.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('el 413 del Gateway se muestra con el mismo mensaje', (
      tester,
    ) async {
      await montar(
        tester,
        nombre: 'avatar.png',
        tamano: 10,
        respuestaSubida: http.Response('', 413),
      );

      expect(peticiones.where((r) => r.method == 'POST'), hasLength(1));
      expect(
        tester.widget<Text>(find.byKey(const Key('banner-error-perfil'))).data,
        mensaje,
      );
    });
  });
}
