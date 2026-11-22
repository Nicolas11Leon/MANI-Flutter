import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_avatar.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_franja_simulado.dart';

Widget _en(Widget hijo) => MaterialApp(
  home: Scaffold(body: Center(child: hijo)),
);

void main() {
  group('ManiAvatar', () {
    test('las iniciales son hasta dos letras', () {
      expect(ManiAvatar.iniciales('Ana Pérez'), 'AP');
      expect(ManiAvatar.iniciales('  carlos  '), 'C');
      expect(ManiAvatar.iniciales('Luis Fernando Gómez'), 'LF');
      expect(ManiAvatar.iniciales(''), '');
    });

    test('el color de un nombre es siempre el mismo', () {
      expect(
        ManiAvatar.fondoPara('Ana Pérez'),
        ManiAvatar.fondoPara('ana pérez '),
      );
    });

    testWidgets('sin foto muestra las iniciales', (tester) async {
      await tester.pumpWidget(_en(const ManiAvatar(nombre: 'Ana Pérez')));
      expect(find.text('AP'), findsOneWidget);
    });

    testWidgets('si la foto falla, muestra las iniciales', (tester) async {
      await tester.pumpWidget(
        _en(
          const ManiAvatar(
            nombre: 'Ana Pérez',
            foto: 'http://localhost:0/x.png',
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('AP'), findsOneWidget);
    });
  });

  group('ManiEstado', () {
    testWidgets('muestra el texto y mide 26 px', (tester) async {
      await tester.pumpWidget(
        _en(const ManiEstado(texto: 'Finalizada', tono: ManiTono.listo)),
      );
      expect(find.text('Finalizada'), findsOneWidget);
      expect(tester.getSize(find.byType(ManiEstado)).height, 26);
    });

    testWidgets('cada tono usa su par de colores', (tester) async {
      await tester.pumpWidget(
        _en(const ManiEstado(texto: 'Cancelada', tono: ManiTono.mal)),
      );
      final texto = tester.widget<Text>(find.text('Cancelada'));
      expect(texto.style!.color, ManiColors.dangerText);
    });
  });

  testWidgets('la franja de simulación muestra su texto', (tester) async {
    await tester.pumpWidget(
      _en(const ManiFranjaSimulado(texto: 'Simulación: no mueve dinero real')),
    );
    expect(find.text('Simulación: no mueve dinero real'), findsOneWidget);
  });
}
