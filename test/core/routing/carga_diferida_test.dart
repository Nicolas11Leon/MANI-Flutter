import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/routing/carga_diferida.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_estado.dart';

Widget _app(Widget hijo) => MaterialApp(theme: AppTheme.light, home: hijo);

void main() {
  group('SCRUM-1647 — CargaDiferida', () {
    testWidgets(
      'muestra el indicador mientras llega la librería y luego la pantalla',
      (tester) async {
        final descarga = Completer<void>();
        await tester.pumpWidget(
          _app(
            CargaDiferida(
              cargar: () => descarga.future,
              builder: (_) => const Text('pantalla lista'),
            ),
          ),
        );

        expect(find.text('pantalla lista'), findsNothing);
        expect(find.byType(ManiCargando), findsOneWidget);

        descarga.complete();
        await tester.pumpAndSettle();

        expect(find.text('pantalla lista'), findsOneWidget);
      },
    );

    testWidgets(
      'si la descarga falla ofrece Reintentar y, al lograrlo, muestra la pantalla',
      (tester) async {
        var intentos = 0;
        await tester.pumpWidget(
          _app(
            CargaDiferida(
              cargar: () async {
                intentos++;
                if (intentos == 1) throw Exception('sin red');
              },
              builder: (_) => const Text('pantalla lista'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('pantalla lista'), findsNothing);
        expect(
          find.byKey(const Key('carga-diferida-reintentar')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('carga-diferida-reintentar')));
        await tester.pumpAndSettle();

        expect(intentos, 2);
        expect(find.text('pantalla lista'), findsOneWidget);
      },
    );

    testWidgets('embebida (pantalla: false) no abre un Scaffold propio', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: CargaDiferida(
              pantalla: false,
              cargar: () async {},
              builder: (_) => const Text('mapa listo'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('mapa listo'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets(
      'embebida muestra el indicador sin Scaffold propio mientras carga',
      (tester) async {
        final descarga = Completer<void>();
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: CargaDiferida(
                pantalla: false,
                mensajeCarga: 'Cargando el mapa',
                cargar: () => descarga.future,
                builder: (_) => const Text('mapa listo'),
              ),
            ),
          ),
        );

        expect(find.byType(ManiCargando), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
        descarga.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('no vuelve a pedir la librería al reconstruirse', (
      tester,
    ) async {
      var intentos = 0;
      final widget = CargaDiferida(
        cargar: () async => intentos++,
        builder: (_) => const Text('pantalla lista'),
      );
      await tester.pumpWidget(_app(widget));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(widget));
      await tester.pumpAndSettle();

      expect(intentos, 1);
    });
  });

  group('SCRUM-1647 — el mapa y la auditoría siguen diferidos', () {
    const diferidas = [
      'features/catalog/map/presentation/widgets/mapa_zonas.dart',
      'features/audit/presentation/auditoria_page.dart',
    ];

    final archivos = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    test('cada una se importa con deferred en algún archivo de lib', () {
      final textos = archivos.map((f) => f.readAsStringSync()).toList();
      for (final ruta in diferidas) {
        final diferida = RegExp(
          "import 'package:mani/$ruta'\\s+deferred\\s+as\\s+\\w+;",
        );
        expect(textos.any(diferida.hasMatch), isTrue, reason: ruta);
      }
    });

    test(
      'ningún archivo de lib las importa de forma normal (si no, dejarían de ser diferidas)',
      () {
        final culpables = <String>[];
        for (final f in archivos) {
          final texto = f.readAsStringSync();
          for (final ruta in diferidas) {
            final normal = RegExp(
              "import 'package:mani/$ruta'(?!\\s+deferred)",
            ).hasMatch(texto);
            if (normal) culpables.add('${f.path} importa $ruta');
          }
        }
        expect(culpables, isEmpty);
      },
    );

    test(
      'el mapa solo lo importa su envoltorio, que usan la página, Cobertura y Sedes',
      () {
        final importan = archivos
            .where(
              (f) => f.readAsStringSync().contains('widgets/mapa_zonas.dart'),
            )
            .map((f) => f.path)
            .toList();
        expect(importan, [
          'lib/features/catalog/map/presentation/widgets/mapa_zonas_diferido.dart',
        ]);
      },
    );
  });
}
