import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SCRUM-1733 (WCAG 1.4.4): el zoom en celular no puede quedar bloqueado. El motor de Flutter web inyecta
/// `user-scalable=no` en tiempo de ejecución; `web/index.html` lo corrige con un guardián. Esta prueba protege la parte
/// estática; la comprobación del `meta viewport` final se hace en el navegador (ver el PR).
void main() {
  late String html;
  setUpAll(() => html = File('web/index.html').readAsStringSync());

  test('la etiqueta viewport declarada permite el zoom', () {
    final meta = RegExp(
      r'<meta name="viewport" content="([^"]*)"',
    ).firstMatch(html)!.group(1)!;
    expect(meta, contains('width=device-width'));
    expect(meta, isNot(contains('user-scalable')));
    expect(meta, isNot(contains('maximum-scale')));
  });

  test(
    'el guardián corre antes de arrancar Flutter y repone la etiqueta si el motor la cambia',
    () {
      final guardian = html.indexOf('MutationObserver');
      final arranque = html.indexOf('flutter_bootstrap.js');
      expect(guardian, isNonNegative, reason: 'falta el guardián del viewport');
      expect(
        guardian,
        lessThan(arranque),
        reason: 'debe instalarse antes de que arranque el motor',
      );
      expect(html, contains("meta[name=\"viewport\"]"));
      expect(html, contains("'width=device-width, initial-scale=1'"));
    },
  );

  test('ninguna parte del HTML pide bloquear el zoom', () {
    final sinComentarios = html.replaceAll(
      RegExp(r'<!--.*?-->', dotAll: true),
      '',
    );
    final codigo = sinComentarios.replaceAll(
      RegExp(r"'[^']*user-scalable[^']*'"),
      '',
    );
    expect(codigo, isNot(contains('user-scalable=no')));
    expect(codigo, isNot(contains('maximum-scale=1')));
  });

  test(
    'el pellizco no queda bloqueado: body permite pinch-zoom, que gana al touch-action: none del motor',
    () {
      final regla = RegExp(
        r'body\s*\{[^}]*touch-action:\s*pinch-zoom\s*!important\s*;?\s*\}',
      ).firstMatch(html);
      expect(
        regla,
        isNotNull,
        reason: 'falta body { touch-action: pinch-zoom !important; }',
      );
      final codigo = html.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
      expect(codigo, isNot(contains('touch-action: none')));
      expect(codigo, isNot(contains('touch-action:none')));
    },
  );

  test(
    'la regla de pellizco está en un <style> del <head>, antes de arrancar Flutter',
    () {
      final head = html.substring(
        html.indexOf('<head>'),
        html.indexOf('</head>'),
      );
      expect(head, contains('touch-action: pinch-zoom'));
      expect(
        html.indexOf('touch-action: pinch-zoom'),
        lessThan(html.indexOf('flutter_bootstrap.js')),
      );
    },
  );
}
