import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/i18n/mani_idioma.dart';

/// SCRUM-1732 (WCAG 3.1.1): la app declara español de Colombia. En web, Flutter escribe el locale de la app en
/// `<html lang>`, así que el lector de pantalla lee con voz en español.

Widget _app({Locale? dispositivo, void Function(BuildContext)? alConstruir}) {
  return MaterialApp(
    locale: dispositivo ?? ManiIdioma.principal,
    supportedLocales: ManiIdioma.soportados,
    localizationsDelegates: ManiIdioma.delegados,
    home: Builder(
      builder: (context) {
        alConstruir?.call(context);
        return const Scaffold(body: Text('hola'));
      },
    ),
  );
}

void main() {
  group('SCRUM-1732 — idioma de la app', () {
    test('el idioma principal es es-CO y también se soporta es', () {
      expect(ManiIdioma.principal, const Locale('es', 'CO'));
      expect(ManiIdioma.soportados, [
        const Locale('es', 'CO'),
        const Locale('es'),
      ]);
    });

    test('el inglés no se declara como idioma soportado', () {
      expect(
        ManiIdioma.soportados.where((l) => l.languageCode == 'en'),
        isEmpty,
      );
    });

    testWidgets(
      'la app corre en es-CO y los textos del framework salen en español',
      (tester) async {
        late Locale localeActual;
        late MaterialLocalizations textos;
        await tester.pumpWidget(
          _app(
            alConstruir: (context) {
              localeActual = Localizations.localeOf(context);
              textos = MaterialLocalizations.of(context);
            },
          ),
        );

        expect(localeActual, const Locale('es', 'CO'));
        expect(textos.okButtonLabel.toUpperCase(), 'ACEPTAR');
        expect(textos.cancelButtonLabel.toUpperCase(), 'CANCELAR');
      },
    );

    testWidgets('con un celular en inglés la app sigue en español', (
      tester,
    ) async {
      // La app fija su locale (no sigue al del dispositivo): un inglés configurado no cambia el idioma declarado.
      late Locale localeActual;
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        _app(alConstruir: (c) => localeActual = Localizations.localeOf(c)),
      );

      expect(localeActual.languageCode, 'es');
    });

    test('hay un delegado de Material, de Widgets y de Cupertino', () {
      expect(ManiIdioma.delegados, hasLength(3));
      expect(
        ManiIdioma.delegados.map((d) => d.runtimeType.toString()).join(),
        allOf(contains('Material'), contains('Widgets'), contains('Cupertino')),
      );
    });
  });
}
