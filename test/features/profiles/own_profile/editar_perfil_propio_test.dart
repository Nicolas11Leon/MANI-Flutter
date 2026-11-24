import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/widgets/mani_avatar.dart';
import 'package:mani/features/profiles/own_profile/data/datasources/perfil_propio_remote_datasource.dart';
import 'package:mani/features/profiles/own_profile/presentation/pages/editar_perfil_page.dart';

const _urlFirmada =
    'https://storage.example/object/sign/kyc-documentos/trama-demo/u-1/avatar-nuevo.png?token=abc';

void main() {
  group(
    'US-02.3.1 (SCRUM-854 / SCRUM-1029 / SCRUM-1030 / SCRUM-1031) — Editar perfil propio',
    () {
      test(
        'GatewayPerfilPropioDataSource consulta GET /api/v1/core/profiles/me y actualiza PATCH /api/v1/core/profiles/me',
        () async {
          String? lastMethod;
          String? lastPath;
          Map<String, dynamic>? lastBody;

          final jsonHeaders = {
            'content-type': 'application/json; charset=utf-8',
          };
          final mockHttp = MockClient((request) async {
            lastMethod = request.method;
            lastPath = request.url.path;
            if (request.method == 'PATCH') {
              lastBody = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode({
                  'profile': {
                    'id': 'u-1',
                    'tenantId': 'trama-demo',
                    'role': 'CLIENT',
                    'fullName': lastBody!['fullName'],
                    'status': 'VERIFIED',
                    'phone': lastBody!['phone'],
                    'address': lastBody!['address'],
                  },
                }),
                200,
                headers: jsonHeaders,
              );
            }
            return http.Response(
              jsonEncode({
                'profile': {
                  'id': 'u-1',
                  'tenantId': 'trama-demo',
                  'role': 'CLIENT',
                  'fullName': 'Usuario Inicial',
                  'status': 'VERIFIED',
                  'phone': '+573001112233',
                  'address': 'Calle 10 # 20-30',
                },
              }),
              200,
              headers: jsonHeaders,
            );
          });

          final client = GatewayClient(
            baseUrl: 'https://gateway.mani.local',
            tokenProvider: () async => 'jwt-token',
            httpClient: mockHttp,
          );
          final ds = GatewayPerfilPropioDataSource(client);

          final actual = await ds.obtenerPerfilPropio();
          expect(lastMethod, 'GET');
          expect(lastPath, '/api/v1/core/profiles/me');
          expect(actual.fullName, 'Usuario Inicial');

          final actualizado = await ds.actualizarPerfilPropio(
            fullName: 'Laura Gómez',
            phone: '+57 315 222 3344',
            address: 'Carrera 15 # 85-30 Bogotá',
          );
          expect(lastMethod, 'PATCH');
          expect(lastPath, '/api/v1/core/profiles/me');
          expect(actualizado.fullName, 'Laura Gómez');
          expect(actualizado.phone, '+57 315 222 3344');
          expect(actualizado.address, 'Carrera 15 # 85-30 Bogotá');
        },
      );

      testWidgets(
        'EditarPerfilPage muestra datos actuales, valida campos, sube foto y refleja los cambios guardados',
        (tester) async {
          final jsonHeaders = {
            'content-type': 'application/json; charset=utf-8',
          };
          Map<String, dynamic> estadoServidor = {
            'id': 'u-1',
            'tenantId': 'trama-demo',
            'role': 'ALLY',
            'fullName': 'Carlos Mendoza',
            'status': 'VERIFIED',
            'phone': '+573001234567',
            'address': 'Av. El Dorado # 68B-85',
            'photoUrl': null,
          };

          final mockHttp = MockClient((request) async {
            if (request.method == 'GET' &&
                request.url.path == '/api/v1/core/profiles/me') {
              return http.Response(
                jsonEncode({'profile': estadoServidor}),
                200,
                headers: jsonHeaders,
              );
            }
            if (request.method == 'PATCH' &&
                request.url.path == '/api/v1/core/profiles/me') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              estadoServidor = {
                ...estadoServidor,
                'fullName': body['fullName'],
                'phone': body['phone'],
                'address': body['address'],
              };
              return http.Response(
                jsonEncode({'profile': estadoServidor}),
                200,
                headers: jsonHeaders,
              );
            }
            if (request.method == 'POST' &&
                request.url.path == '/api/v1/core/profiles/me/photo') {
              estadoServidor = {
                ...estadoServidor,
                // SCRUM-1634: Core responde la foto como URL firmada, no como la ruta del bucket.
                'photoUrl': _urlFirmada,
              };
              return http.Response(
                jsonEncode({'profile': estadoServidor}),
                200,
                headers: jsonHeaders,
              );
            }
            return http.Response('{}', 404, headers: jsonHeaders);
          });

          final ds = GatewayPerfilPropioDataSource(
            GatewayClient(
              baseUrl: 'https://gateway.mani.local',
              tokenProvider: () async => 'jwt-token',
              httpClient: mockHttp,
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: EditarPerfilPage(
                dataSource: ds,
                selectorImagen: () async => (
                  nombre: 'avatar-nuevo.png',
                  bytes: Uint8List.fromList([1, 2, 3, 4]),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Verifica carga inicial y que rol/estado se muestran en solo lectura
          expect(find.text('Carlos Mendoza'), findsOneWidget);
          expect(find.text('Aliado'), findsOneWidget);
          expect(find.text('Verificado'), findsOneWidget);

          // SCRUM-1028 / SCRUM-1031: Rechaza dirección vacía y teléfono inválido en el formulario
          await tester.enterText(
            find.byKey(const Key('input-telefono-perfil')),
            'abc',
          );
          await tester.enterText(
            find.byKey(const Key('input-direccion-perfil')),
            '   ',
          );
          await tester.ensureVisible(
            find.byKey(const Key('btn-guardar-perfil')),
          );
          await tester.tap(find.byKey(const Key('btn-guardar-perfil')));
          await tester.pumpAndSettle();

          expect(find.text('Ingresa un teléfono válido'), findsOneWidget);
          expect(
            find.textContaining('La dirección no puede estar vacía'),
            findsOneWidget,
          );

          // SCRUM-1030: Subida de foto de perfil
          await tester.ensureVisible(
            find.byKey(const Key('btn-cambiar-foto-perfil')),
          );
          await tester.tap(find.byKey(const Key('btn-cambiar-foto-perfil')));
          await tester.pumpAndSettle();
          expect(
            find.text('Foto de perfil actualizada correctamente'),
            findsOneWidget,
          );
          // SCRUM-1634: la foto nueva llega al avatar y su dirección no se escribe como texto.
          expect(
            tester
                .widget<ManiAvatar>(
                  find.byKey(const Key('avatar-perfil-propio')),
                )
                .foto,
            _urlFirmada,
          );
          expect(find.text(_urlFirmada), findsNothing);

          // SCRUM-1029 / SCRUM-1031: Edita y guarda datos válidos y refleja los cambios
          await tester.enterText(
            find.byKey(const Key('input-nombre-perfil')),
            'Carlos Alberto Mendoza',
          );
          await tester.enterText(
            find.byKey(const Key('input-telefono-perfil')),
            '+57 310 987 6543',
          );
          await tester.enterText(
            find.byKey(const Key('input-direccion-perfil')),
            'Calle 93 # 11-40 Oficina 302',
          );
          await tester.ensureVisible(
            find.byKey(const Key('btn-guardar-perfil')),
          );
          await tester.tap(find.byKey(const Key('btn-guardar-perfil')));
          await tester.pumpAndSettle();

          expect(find.text('Perfil actualizado exitosamente'), findsOneWidget);
          expect(find.text('Carlos Alberto Mendoza'), findsOneWidget);
          expect(find.text('+57 310 987 6543'), findsOneWidget);
          expect(find.text('Calle 93 # 11-40 Oficina 302'), findsOneWidget);
        },
      );
    },
  );
}
