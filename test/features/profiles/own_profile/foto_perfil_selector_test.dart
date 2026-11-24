import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/widgets/mani_avatar.dart';
import 'package:mani/features/profiles/own_profile/presentation/widgets/foto_perfil_selector_widget.dart';

/// SCRUM-1634: la foto se ve en el avatar y su dirección nunca se escribe como texto (ni la URL firmada ni la ruta
/// interna del bucket que devolvía Core antes).
void main() {
  Future<void> montar(WidgetTester tester, String? photoUrl) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FotoPerfilSelectorWidget(
            fullName: 'Ana Gómez',
            photoUrl: photoUrl,
            onFotoSeleccionada: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  const firmada =
      'https://storage.example/object/sign/kyc-documentos/t1/u1/avatar-1.jpg?token=abc';
  const rutaInterna = 'kyc-documentos/t1/u1/avatar-1.jpg';

  for (final (nombre, url) in [
    ('URL firmada', firmada),
    ('ruta interna', rutaInterna),
  ]) {
    testWidgets(
      'con $nombre: el avatar recibe la foto y no se muestra como texto',
      (tester) async {
        await montar(tester, url);

        final avatar = tester.widget<ManiAvatar>(
          find.byKey(const Key('avatar-perfil-propio')),
        );
        expect(avatar.foto, url);
        expect(find.text(url), findsNothing);
        expect(find.byKey(const Key('texto-foto-actual')), findsNothing);
        expect(find.textContaining('kyc-documentos'), findsNothing);
        expect(
          find.byKey(const Key('btn-cambiar-foto-perfil')),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('sin foto muestra las iniciales y el botón para cambiarla', (
    tester,
  ) async {
    await montar(tester, null);

    expect(find.text('AG'), findsOneWidget);
    expect(find.byKey(const Key('btn-cambiar-foto-perfil')), findsOneWidget);
  });
}
