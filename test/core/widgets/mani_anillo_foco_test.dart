import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/navegacion_movil.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_anillo_foco.dart';
import 'package:mani/core/widgets/mani_button.dart';

Widget _app(Widget hijo, {ThemeData? tema}) => MaterialApp(
  theme: tema ?? AppTheme.light,
  home: Scaffold(body: Center(child: hijo)),
);

Widget _fila(String texto) => InkWell(
  onTap: () {},
  child: Padding(padding: const EdgeInsets.all(16), child: Text(texto)),
);

const _anillo = Key('anillo-foco');

/// Anillos dibujados ahora: la caja siempre existe y solo tiene borde mientras el control tiene el foco del teclado.
Finder _conAnillo() => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.key == _anillo &&
      (w.decoration as BoxDecoration).border != null,
);

int _anillos() => _conAnillo().evaluate().length;

bool _anilloEn(String clave) => find
    .descendant(of: find.byKey(Key(clave)), matching: _conAnillo())
    .evaluate()
    .isNotEmpty;

Future<void> _tab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
}

void main() {
  // Recorrer con Tab pone el foco «tradicional» (teclado); un toque lo pasa a «táctil».
  setUp(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional,
  );
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  group('SCRUM-1647 — ManiAnilloFoco', () {
    testWidgets('sin foco no dibuja anillo', (tester) async {
      await tester.pumpWidget(_app(ManiAnilloFoco(child: _fila('Fila'))));

      expect(_anillos(), 0);
    });

    testWidgets(
      'con el foco del teclado dibuja un anillo de 3 px con la tinta del tema',
      (tester) async {
        await tester.pumpWidget(_app(ManiAnilloFoco(child: _fila('Fila'))));

        for (var i = 0; i < 3 && _anillos() == 0; i++) {
          await _tab(tester);
        }

        expect(_anillos(), 1);
        final decoracion =
            tester.widget<DecoratedBox>(_conAnillo()).decoration
                as BoxDecoration;
        final borde = decoracion.border! as Border;
        expect(borde.top.width, ManiAnilloFoco.grosor);
        expect(borde.top.color, ManiColors.ink);
      },
    );

    testWidgets('el anillo pasa por los dos controles al recorrerlos con Tab', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ManiAnilloFoco(key: const Key('a'), child: _fila('A')),
              ManiAnilloFoco(key: const Key('b'), child: _fila('B')),
            ],
          ),
        ),
      );

      final vistos = <String>{};
      for (var i = 0; i < 4; i++) {
        await _tab(tester);
        if (_anilloEn('a')) vistos.add('a');
        if (_anilloEn('b')) vistos.add('b');
      }

      expect(vistos, {'a', 'b'});
    });

    testWidgets('con un toque (foco táctil) no se dibuja', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await tester.pumpWidget(_app(ManiAnilloFoco(child: _fila('Fila'))));

      await tester.tap(find.text('Fila'));
      await tester.pump();

      expect(_anillos(), 0);
    });

    testWidgets('se ve también en modo oscuro (tinta clara)', (tester) async {
      await tester.pumpWidget(
        _app(ManiAnilloFoco(child: _fila('Fila')), tema: AppTheme.dark),
      );

      for (var i = 0; i < 3 && _anillos() == 0; i++) {
        await _tab(tester);
      }

      final decoracion =
          tester.widget<DecoratedBox>(_conAnillo()).decoration as BoxDecoration;
      expect((decoracion.border! as Border).top.color, ManiDarkColors.ink);
    });
  });

  group('SCRUM-1647 — los controles con anillo de foco', () {
    testWidgets(
      'cada destino de la barra inferior muestra el anillo cuando tiene el foco',
      (tester) async {
        final navegacion = navegacionMovilPara(RolUsuario.cliente)!;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              bottomNavigationBar: BarraInferiorMovil(
                navegacion: navegacion,
                ubicacion: '/inicio',
                seccion: null,
                onNavegar: (_) {},
              ),
            ),
          ),
        );

        final destinos = navegacion.todos.map((d) => d.ruta).toList();
        final sinAnillo = <String>[];
        for (final ruta in destinos) {
          final entrada = find.byKey(Key('menu-entrada-$ruta'));
          // Se pone el foco directamente en el control de cada destino: el orden del Tab no es lo que se prueba.
          final dentro = find.descendant(
            of: find.descendant(of: entrada, matching: find.byType(InkWell)),
            matching: find.byType(Padding),
          );
          // Desde dentro del InkWell, el Focus más cercano es el del propio InkWell.
          final nodo = Focus.of(tester.element(dentro.first));
          nodo.requestFocus();
          await tester.pumpAndSettle();
          if (!_anilloEn('menu-entrada-$ruta')) sinAnillo.add(ruta);
        }

        expect(
          sinAnillo,
          isEmpty,
          reason: 'destinos sin anillo cuando tienen el foco: $sinAnillo',
        );
      },
    );

    testWidgets(
      'el anillo no altera el recorrido con Tab: la barra inferior se recorre completa y en orden',
      (tester) async {
        final navegacion = navegacionMovilPara(RolUsuario.cliente)!;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              bottomNavigationBar: BarraInferiorMovil(
                navegacion: navegacion,
                ubicacion: '/inicio',
                seccion: null,
                onNavegar: (_) {},
              ),
            ),
          ),
        );
        final destinos = navegacion.todos.map((d) => d.ruta).toList();

        final recorrido = <String>[];
        for (var i = 0; i < destinos.length * 2; i++) {
          await _tab(tester);
          final enfocados = destinos.where(
            (ruta) => _anilloEn('menu-entrada-$ruta'),
          );
          expect(enfocados.length, 1, reason: 'paso ${i + 1}: un solo foco');
          recorrido.add(enfocados.single);
        }

        // Dos vueltas completas con los mismos cinco destinos, sin que el foco caiga a un ámbito vacío.
        expect(recorrido.sublist(0, destinos.length).toSet(), destinos.toSet());
        expect(
          recorrido.sublist(destinos.length),
          recorrido.sublist(0, destinos.length),
        );
      },
    );

    testWidgets('el botón de enlace («Ver todos») muestra el anillo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ManiButton(
            etiqueta: 'Ver todos',
            variante: ManiButtonVariante.texto,
            onPressed: () {},
          ),
        ),
      );

      for (var i = 0; i < 3 && _anillos() == 0; i++) {
        await _tab(tester);
      }

      expect(_anillos(), 1);
    });
  });
}
