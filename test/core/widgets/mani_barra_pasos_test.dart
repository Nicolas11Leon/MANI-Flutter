import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/widgets/mani_barra_pasos.dart';

void main() {
  testWidgets('dice en qué paso va y lo anuncia a lectores de pantalla', (
    tester,
  ) async {
    final sem = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ManiBarraPasos(
            etiquetas: ['Servicio', 'Problema', 'Ubicación', 'Revisión'],
            actual: 1,
          ),
        ),
      ),
    );
    expect(find.text('Paso 2 de 4 · Problema'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 2 de 4: Problema'), findsOneWidget);
    sem.dispose();
  });
}
