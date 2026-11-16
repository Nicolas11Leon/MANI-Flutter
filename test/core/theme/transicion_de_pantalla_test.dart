import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/theme/transicion_de_pantalla.dart';

/// Opacidad con la que se ve el texto [texto]: el producto de todos los desvanecimientos que lo envuelven.
double _opacidad(WidgetTester tester, String texto) {
  final fades = find.ancestor(
    of: find.text(texto),
    matching: find.byType(FadeTransition),
  );
  var o = 1.0;
  for (final e in fades.evaluate()) {
    o *= (e.widget as FadeTransition).opacity.value;
  }
  return o;
}

Future<GlobalKey<NavigatorState>> _montar(WidgetTester tester) async {
  final navegador = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      navigatorKey: navegador,
      home: const Scaffold(body: Text('A')),
    ),
  );
  return navegador;
}

Future<void> _abrirB(
  WidgetTester tester,
  GlobalKey<NavigatorState> navegador,
) async {
  navegador.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('B'))),
  );
  await tester.pump();
}

void main() {
  group('SCRUM-1646 — transición de pantalla sin superposición', () {
    testWidgets('el tema usa la transición propia en todas las plataformas', (
      tester,
    ) async {
      final tema = AppTheme.light.pageTransitionsTheme;
      for (final p in TargetPlatform.values) {
        expect(tema.builders[p], isA<TransicionDePantalla>(), reason: '$p');
      }
    });

    testWidgets('nunca se ven las dos pantallas a la vez', (tester) async {
      final nav = await _montar(tester);
      await _abrirB(tester, nav);

      // Se muestrea cada 15 ms mientras dura la animación: en cada instante una se ve y la otra casi no.
      await tester.pump(const Duration(milliseconds: 15));
      var juntasMax = 0.0;
      var muestras = 0;
      while (tester.hasRunningAnimations && muestras < 40) {
        final a = _opacidad(tester, 'A');
        final b = _opacidad(tester, 'B');
        final juntas = a < b ? a : b;
        if (juntas > juntasMax) juntasMax = juntas;
        muestras++;
        await tester.pump(const Duration(milliseconds: 15));
      }
      expect(muestras, greaterThan(5), reason: 'se muestreó la animación');
      expect(juntasMax, lessThan(0.15));
    });

    testWidgets('la pantalla nueva ya se ve casi completa a los 250 ms', (
      tester,
    ) async {
      final nav = await _montar(tester);
      await _abrirB(tester, nav);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_opacidad(tester, 'B'), greaterThan(0.95));
    });

    testWidgets(
      'la animación termina en menos de 400 ms: nada que esperar de más',
      (tester) async {
        final nav = await _montar(tester);
        await _abrirB(tester, nav);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.hasRunningAnimations, isFalse);
      },
    );

    testWidgets(
      'al terminar, la nueva está completa y la vieja ya no se pinta',
      (tester) async {
        final nav = await _montar(tester);
        await _abrirB(tester, nav);
        await tester.pumpAndSettle();

        expect(_opacidad(tester, 'B'), closeTo(1, 0.001));
        expect(find.text('A'), findsNothing);
      },
    );

    testWidgets('al volver atrás la pantalla anterior reaparece completa', (
      tester,
    ) async {
      final nav = await _montar(tester);
      await _abrirB(tester, nav);
      await tester.pumpAndSettle();
      nav.currentState!.pop();
      await tester.pumpAndSettle();

      expect(_opacidad(tester, 'A'), closeTo(1, 0.001));
      expect(find.text('B'), findsNothing);
    });
  });
}
