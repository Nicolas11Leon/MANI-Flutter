import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/widgets/barra_acciones_flujo.dart';

Future<void> _montar(
  WidgetTester tester,
  BarraAccionesFlujo barra, {
  double ancho = 390,
  double alto = 800,
}) async {
  tester.view.physicalSize = Size(ancho, alto);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: const SizedBox.expand(key: Key('contenido')),
        bottomNavigationBar: barra,
      ),
    ),
  );
}

void main() {
  group('SCRUM-1647 — barra de acciones estándar de los flujos', () {
    testWidgets(
      'muestra Atrás y la acción principal, y cada una hace lo suyo',
      (tester) async {
        var atras = 0;
        var principal = 0;
        await _montar(
          tester,
          BarraAccionesFlujo(
            claveAtras: const Key('atras'),
            clavePrincipal: const Key('principal'),
            etiquetaPrincipal: 'Continuar',
            onAtras: () => atras++,
            onPrincipal: () => principal++,
          ),
        );

        expect(find.text('Atrás'), findsOneWidget);
        expect(find.text('Continuar'), findsOneWidget);
        await tester.tap(find.byKey(const Key('atras')));
        await tester.tap(find.byKey(const Key('principal')));
        expect(atras, 1);
        expect(principal, 1);
      },
    );

    testWidgets('mide lo que miden sus botones y no se come el contenido', (
      tester,
    ) async {
      // Sin heightFactor el Center ocupaba toda la altura de la ranura inferior y el contenido quedaba en 0.
      await _montar(
        tester,
        BarraAccionesFlujo(
          etiquetaPrincipal: 'Pagar',
          onPrincipal: () {},
          onAtras: () {},
        ),
      );

      final barra = tester.getSize(find.byType(BarraAccionesFlujo));
      final contenido = tester.getSize(find.byKey(const Key('contenido')));
      expect(barra.height, lessThan(160));
      expect(contenido.height, greaterThan(600));
    });

    testWidgets('la pista dice qué falta, y sin ella no se muestra', (
      tester,
    ) async {
      await _montar(
        tester,
        BarraAccionesFlujo(
          clavePista: const Key('pista'),
          pista: 'Describe el problema para continuar.',
          etiquetaPrincipal: 'Continuar',
          onPrincipal: null,
          onAtras: () {},
        ),
      );
      expect(find.byKey(const Key('pista')), findsOneWidget);

      await _montar(
        tester,
        BarraAccionesFlujo(
          clavePista: const Key('pista'),
          etiquetaPrincipal: 'Continuar',
          onPrincipal: () {},
          onAtras: () {},
        ),
      );
      expect(find.byKey(const Key('pista')), findsNothing);
    });

    testWidgets('sin acción principal disponible no hace nada al tocar', (
      tester,
    ) async {
      var principal = 0;
      await _montar(
        tester,
        BarraAccionesFlujo(
          clavePrincipal: const Key('principal'),
          etiquetaPrincipal: 'Continuar',
          onPrincipal: null,
          onAtras: () => principal++,
        ),
      );
      await tester.tap(find.byKey(const Key('principal')));
      expect(principal, 0);
    });

    testWidgets('cabe en un celular angosto sin desbordar', (tester) async {
      await _montar(
        tester,
        BarraAccionesFlujo(
          etiquetaPrincipal: 'Publicar solicitud',
          onPrincipal: () {},
          onAtras: () {},
        ),
        ancho: 320,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Publicar solicitud'), findsOneWidget);
    });
  });
}
