import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/navegacion_movil.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/theme/mani_transiciones.dart';
import 'package:mani/core/widgets/mani_button.dart';

/// SCRUM-1647: lo que respalda con pruebas los tres compromisos de accesibilidad del cierre, además del foco visible:
/// áreas táctiles de 48 px, nombres para los lectores de pantalla y «reducir movimiento».

Widget _barra(ThemeData tema) {
  final navegacion = navegacionMovilPara(RolUsuario.cliente)!;
  return MaterialApp(
    theme: tema,
    home: Scaffold(
      bottomNavigationBar: BarraInferiorMovil(
        navegacion: navegacion,
        ubicacion: '/inicio',
        seccion: null,
        onNavegar: (_) {},
      ),
    ),
  );
}

void main() {
  group('Áreas táctiles de 48 px', () {
    for (final entrada in {
      'claro': AppTheme.light,
      'oscuro': AppTheme.dark,
    }.entries) {
      testWidgets(
        'la barra inferior cumple la guía de Android (48 × 48), modo ${entrada.key}',
        (tester) async {
          final semantica = tester.ensureSemantics();
          await tester.pumpWidget(_barra(entrada.value));

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          semantica.dispose();
        },
      );
    }

    testWidgets(
      'el botón de enlace conserva el área de 48 px aunque el texto sea pequeño',
      (tester) async {
        final semantica = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Center(
                child: ManiButton(
                  etiqueta: 'Ver todos',
                  variante: ManiButtonVariante.texto,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        semantica.dispose();
      },
    );
  });

  group('Lectores de pantalla', () {
    testWidgets(
      'cada destino de la barra inferior tiene nombre y se anuncia como botón',
      (tester) async {
        final semantica = tester.ensureSemantics();
        await tester.pumpWidget(_barra(AppTheme.light));
        final navegacion = navegacionMovilPara(RolUsuario.cliente)!;

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        for (final destino in navegacion.todos) {
          expect(
            find.bySemanticsLabel(destino.etiqueta),
            findsWidgets,
            reason: 'sin nombre para el lector: ${destino.etiqueta}',
          );
        }
        semantica.dispose();
      },
    );

    testWidgets('el destino activo se anuncia como seleccionado', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(_barra(AppTheme.light));

      final inicio = tester.getSemantics(
        find.byKey(const Key('menu-entrada-/inicio')),
      );
      // ignore: deprecated_member_use
      expect(inicio.hasFlag(SemanticsFlag.isSelected), isTrue);
      semantica.dispose();
    });
  });

  group('Reducir movimiento', () {
    Future<Duration> duracionCon(
      WidgetTester tester, {
      required bool sinAnimar,
    }) async {
      late Duration resultado;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: sinAnimar),
          child: Builder(
            builder: (context) {
              resultado = ManiMotion.duracion(context, ManiMotion.slow);
              return const SizedBox();
            },
          ),
        ),
      );
      return resultado;
    }

    testWidgets(
      'con «reducir movimiento» la duración es cero; sin él, la normal',
      (tester) async {
        expect(await duracionCon(tester, sinAnimar: true), Duration.zero);
        expect(await duracionCon(tester, sinAnimar: false), ManiMotion.slow);
      },
    );

    testWidgets('la transición de pantalla no anima con «reducir movimiento»', (
      tester,
    ) async {
      final hijo = const Text('contenido');
      Widget transicion(bool sinAnimar) => MediaQuery(
        data: MediaQueryData(disableAnimations: sinAnimar),
        child: Builder(
          builder: (context) =>
              const ManiPageTransitionsBuilder().buildTransitions<void>(
                PageRouteBuilder<void>(pageBuilder: (_, _, _) => hijo),
                context,
                const AlwaysStoppedAnimation<double>(0.5),
                const AlwaysStoppedAnimation<double>(0),
                hijo,
              ),
        ),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: transicion(true),
        ),
      );
      expect(find.byType(FadeTransition), findsNothing);
      expect(find.byType(SlideTransition), findsNothing);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: transicion(false),
        ),
      );
      expect(find.byType(FadeTransition), findsWidgets);
    });
  });
}
