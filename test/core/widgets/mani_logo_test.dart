import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_logo.dart';
import 'package:mani/core/widgets/mani_mano.dart';

/// Un paquete de recursos sin imágenes: obliga a las piezas a pintar su respaldo.
class _SinRecursos extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      Future<ByteData>.error(FlutterError('sin recurso: $key'));
}

Widget _en(Widget hijo, {AssetBundle? recursos}) {
  final app = MaterialApp(
    home: Scaffold(body: Center(child: hijo)),
  );
  return recursos == null
      ? app
      : DefaultAssetBundle(bundle: recursos, child: app);
}

void main() {
  group('ManiLogo', () {
    testWidgets('mide el diámetro pedido y se anuncia como «MANI»', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await tester.pumpWidget(_en(const ManiLogo(size: 56)));
      await tester.pump();

      expect(tester.getSize(find.byType(ClipOval)), const Size(56, 56));
      expect(find.bySemanticsLabel('MANI'), findsOneWidget);
      sem.dispose();
    });

    testWidgets('lleva la sombra dura por omisión y puede quedar plano', (
      tester,
    ) async {
      BoxDecoration decoracion() =>
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(ManiLogo),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;

      await tester.pumpWidget(_en(const ManiLogo()));
      expect(decoracion().boxShadow, [AppTheme.hardShadowSm]);

      await tester.pumpWidget(_en(const ManiLogo(sombra: null)));
      expect(decoracion().boxShadow, isNull);
    });

    testWidgets('si la imagen no carga, queda el círculo amarillo con la «M»', (
      tester,
    ) async {
      await tester.pumpWidget(
        _en(const ManiLogo(size: 40), recursos: _SinRecursos()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('M'), findsOneWidget);
    });
  });

  group('ManiMano', () {
    testWidgets('se pinta al alto pedido y se anuncia como «MANI»', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await tester.pumpWidget(_en(const ManiMano(alto: 120)));
      await tester.pump();

      expect(tester.widget<Image>(find.byType(Image)).height, 120);
      expect(find.bySemanticsLabel('MANI'), findsOneWidget);
      sem.dispose();
    });

    testWidgets('si la imagen no carga, queda un círculo con la «M»', (
      tester,
    ) async {
      await tester.pumpWidget(
        _en(const ManiMano(alto: 100), recursos: _SinRecursos()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('M'), findsOneWidget);
      expect(tester.getSize(find.byType(SizedBox).last), const Size(60, 60));
    });
  });
}
