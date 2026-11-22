import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/shell/al_cambiar_visibilidad.dart';

void main() {
  group('SCRUM-1647 — las pantallas ocultas no consultan', () {
    late List<bool> cambios;

    setUp(() => cambios = []);

    Widget arbol({required bool seVe}) => MaterialApp(
      home: TickerMode(
        enabled: seVe,
        child: AlCambiarVisibilidad(
          alCambiar: cambios.add,
          child: const Text('bandeja'),
        ),
      ),
    );

    testWidgets('si arranca a la vista no avisa nada', (tester) async {
      await tester.pumpWidget(arbol(seVe: true));
      expect(cambios, isEmpty);
    });

    testWidgets('avisa al ocultarse la pestaña y al volver a ella', (
      tester,
    ) async {
      await tester.pumpWidget(arbol(seVe: true));
      await tester.pumpWidget(arbol(seVe: false));
      expect(cambios, [false]);
      await tester.pumpWidget(arbol(seVe: true));
      expect(cambios, [false, true]);
    });

    testWidgets('avisa cuando la app pasa a segundo plano y cuando regresa', (
      tester,
    ) async {
      await tester.pumpWidget(arbol(seVe: true));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(cambios, [false]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(cambios, [false, true]);
    });

    testWidgets('perder el foco con la app a la vista no cuenta como oculta', (
      tester,
    ) async {
      await tester.pumpWidget(arbol(seVe: true));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(cambios, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('volver al primer plano con la pestaña oculta no reanuda', (
      tester,
    ) async {
      await tester.pumpWidget(arbol(seVe: false));
      expect(cambios, [false]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(cambios, [false]);
    });
  });
}
