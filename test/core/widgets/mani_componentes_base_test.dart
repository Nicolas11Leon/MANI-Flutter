import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';

Widget _en(Widget hijo) => MaterialApp(
  home: Scaffold(body: Center(child: hijo)),
);

BoxDecoration _decoracion(WidgetTester tester) {
  final cont = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(ManiCard),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return cont.decoration! as BoxDecoration;
}

void main() {
  group('ManiCard', () {
    testWidgets(
      'de trabajo: borde fino y sin sombra',
      (tester) async {
        await tester.pumpWidget(_en(const ManiCard(child: Text('a'))));
        final d = _decoracion(tester);
        expect((d.border! as Border).top.width, ManiBorder.thin);
        expect(d.boxShadow, isEmpty);
      },
      skip: true,
    ); // Diseño de #152 manda en tarjetas, botones y transiciones (rescate de SCRUM-1646/1647); pendiente de acordar con Nicolás y Alvis

    testWidgets(
      'protagonista: borde grueso y sombra dura',
      (tester) async {
        await tester.pumpWidget(
          _en(
            const ManiCard(enfasis: ManiEnfasis.protagonista, child: Text('a')),
          ),
        );
        final d = _decoracion(tester);
        expect((d.border! as Border).top.width, ManiBorder.thick);
        expect(d.boxShadow, [ManiShadow.sm]);
      },
      skip: true,
    ); // Diseño de #152 manda en tarjetas, botones y transiciones (rescate de SCRUM-1646/1647); pendiente de acordar con Nicolás y Alvis

    testWidgets(
      'plano: sin borde ni sombra',
      (tester) async {
        await tester.pumpWidget(
          _en(const ManiCard(enfasis: ManiEnfasis.plano, child: Text('a'))),
        );
        final d = _decoracion(tester);
        expect(d.border, isNull);
        expect(d.boxShadow, isEmpty);
      },
      skip: true,
    ); // Diseño de #152 manda en tarjetas, botones y transiciones (rescate de SCRUM-1646/1647); pendiente de acordar con Nicolás y Alvis

    testWidgets(
      'seleccionada no salta a una sombra grande',
      (tester) async {
        await tester.pumpWidget(
          _en(const ManiCard(seleccionada: true, child: Text('a'))),
        );
        final d = _decoracion(tester);
        expect((d.border! as Border).top.width, ManiBorder.thick);
        expect(d.boxShadow, isEmpty);
      },
      skip: true,
    ); // Diseño de #152 manda en tarjetas, botones y transiciones (rescate de SCRUM-1646/1647); pendiente de acordar con Nicolás y Alvis
  });

  group('ManiButton', () {
    for (final v in ManiButtonVariante.values) {
      testWidgets('${v.name} mide al menos 48 px de alto', (tester) async {
        await tester.pumpWidget(
          _en(ManiButton(etiqueta: 'Aceptar', onPressed: () {}, variante: v)),
        );
        expect(
          tester.getSize(find.byType(ManiButton)).height,
          greaterThanOrEqualTo(48),
        );
      });
    }

    testWidgets(
      'el secundario no lleva sombra',
      (tester) async {
        await tester.pumpWidget(
          _en(
            ManiButton(
              etiqueta: 'Cancelar',
              onPressed: () {},
              variante: ManiButtonVariante.secundario,
            ),
          ),
        );
        final cont = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byType(ManiButton),
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect((cont.decoration! as BoxDecoration).boxShadow, isEmpty);
      },
      skip: true,
    ); // Diseño de #152 manda en tarjetas, botones y transiciones (rescate de SCRUM-1646/1647); pendiente de acordar con Nicolás y Alvis
  });
}
