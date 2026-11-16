import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/widgets/refresco_periodico.dart';

const _intervalo = Duration(seconds: 20);

void main() {
  late int consultas;
  Future<void> Function() onRefrescar = () async {};

  setUp(() {
    consultas = 0;
    onRefrescar = () async => consultas++;
  });

  tearDown(() {
    // Deja la app en primer plano para la prueba siguiente.
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  Widget pantalla({Duration? intervalo = _intervalo}) => MaterialApp(
    home: RefrescoPeriodico(
      intervalo: intervalo,
      onRefrescar: () => onRefrescar(),
      child: const Text('servicio'),
    ),
  );

  void ciclo(WidgetTester tester, AppLifecycleState estado) =>
      tester.binding.handleAppLifecycleStateChanged(estado);

  group('SCRUM-1644 · RefrescoPeriodico', () {
    testWidgets('consulta cada intervalo y no al abrir', (tester) async {
      await tester.pumpWidget(pantalla());
      expect(find.text('servicio'), findsOneWidget);
      expect(consultas, 0, reason: 'la carga inicial la hace el Cubit');

      await tester.pump(_intervalo);
      expect(consultas, 1);
      await tester.pump(_intervalo);
      expect(consultas, 2);
    });

    testWidgets('sin intervalo no consulta nunca', (tester) async {
      await tester.pumpWidget(pantalla(intervalo: null));
      await tester.pump(_intervalo * 3);
      expect(consultas, 0);
    });

    testWidgets('pausa con la pestaña oculta y consulta enseguida al volver', (
      tester,
    ) async {
      await tester.pumpWidget(pantalla());

      ciclo(tester, AppLifecycleState.inactive);
      ciclo(tester, AppLifecycleState.hidden);
      await tester.pump(_intervalo * 3);
      expect(consultas, 0);

      ciclo(tester, AppLifecycleState.inactive);
      await tester.pump();
      expect(consultas, 1, reason: 'volver a la vista consulta sin esperar');

      await tester.pump(_intervalo);
      expect(consultas, 2, reason: 'y retoma el intervalo');
    });

    testWidgets('perder el foco (inactive) no pausa: la ventana sigue a la '
        'vista', (tester) async {
      await tester.pumpWidget(pantalla());
      ciclo(tester, AppLifecycleState.inactive);
      await tester.pump(_intervalo);
      expect(consultas, 1);
    });

    testWidgets('en segundo plano en móvil (paused) también pausa', (
      tester,
    ) async {
      await tester.pumpWidget(pantalla());
      ciclo(tester, AppLifecycleState.inactive);
      ciclo(tester, AppLifecycleState.hidden);
      ciclo(tester, AppLifecycleState.paused);
      await tester.pump(_intervalo * 2);
      expect(consultas, 0);
    });

    testWidgets('pausa mientras otra ruta tapa la pantalla y al volver solo '
        'reanuda el intervalo', (tester) async {
      await tester.pumpWidget(pantalla());
      final navegador = tester.state<NavigatorState>(find.byType(Navigator));

      unawaited(
        navegador.push(
          MaterialPageRoute<void>(builder: (_) => const Text('chat')),
        ),
      );
      await tester.pumpAndSettle();
      final antes = consultas;
      await tester.pump(_intervalo * 3);
      expect(consultas, antes, reason: 'tapada no consulta');

      navegador.pop();
      await tester.pumpAndSettle();
      expect(
        consultas,
        antes,
        reason:
            'al cerrar un diálogo no consulta: el Cubit ya relee tras la '
            'acción que dispara',
      );

      await tester.pump(_intervalo);
      expect(consultas, antes + 1, reason: 'retoma el intervalo');
    });

    testWidgets('un diálogo abierto encima también pausa', (tester) async {
      await tester.pumpWidget(pantalla());
      final contexto = tester.element(find.text('servicio'));

      unawaited(
        showDialog<void>(
          context: contexto,
          builder: (_) => const AlertDialog(content: Text('confirmar')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(_intervalo * 2);
      expect(consultas, 0);
    });

    testWidgets('no lanza una consulta si la anterior no terminó', (
      tester,
    ) async {
      final pendiente = Completer<void>();
      onRefrescar = () {
        consultas++;
        return pendiente.future;
      };
      await tester.pumpWidget(pantalla());

      await tester.pump(_intervalo);
      await tester.pump(_intervalo);
      await tester.pump(_intervalo);
      expect(consultas, 1);

      pendiente.complete();
      await tester.pump(_intervalo);
      expect(consultas, 2);
    });

    testWidgets('un fallo no detiene el sondeo', (tester) async {
      onRefrescar = () async {
        consultas++;
        throw StateError('sin red');
      };
      await tester.pumpWidget(pantalla());

      await tester.pump(_intervalo);
      await tester.pump(_intervalo);
      expect(consultas, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('al cerrar la pantalla deja de consultar', (tester) async {
      await tester.pumpWidget(pantalla());
      await tester.pumpWidget(const SizedBox());
      await tester.pump(_intervalo * 2);
      expect(consultas, 0);
    });
  });
}
