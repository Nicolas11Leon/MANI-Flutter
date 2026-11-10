import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_estado.dart';

/// Razón de contraste WCAG 2.x entre dos colores opacos.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (claro, oscuro) = la > lb ? (la, lb) : (lb, la);
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  const fondos = {
    'background': ManiColors.background,
    'surface': ManiColors.surface,
    'surfaceMuted': ManiColors.surfaceMuted,
    'brandSoft': ManiColors.brandSoft,
  };

  group('texto sobre superficies cumple AA (4.5:1)', () {
    const textos = {
      'ink': ManiColors.ink,
      'inkMuted': ManiColors.inkMuted,
      'inkSubtle': ManiColors.inkSubtle,
      'dangerText': ManiColors.dangerText,
      'infoText': ManiColors.infoText,
      'accent': ManiColors.accent,
    };
    for (final t in textos.entries) {
      for (final f in fondos.entries) {
        test('${t.key} sobre ${f.key}', () {
          expect(contraste(t.value, f.value), greaterThanOrEqualTo(4.5));
        });
      }
    }
  });

  test('success, warning y danger como texto sobre blanco y crema', () {
    for (final c in [
      ManiColors.success,
      ManiColors.successText,
      ManiColors.warning,
      ManiColors.warningText,
      ManiColors.danger,
    ]) {
      expect(contraste(c, ManiColors.surface), greaterThanOrEqualTo(4.5));
      expect(contraste(c, ManiColors.background), greaterThanOrEqualTo(4.5));
    }
  });

  test('texto sobre rellenos de marca y de estado cumple AA', () {
    expect(
      contraste(ManiColors.onBrand, ManiColors.brand),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contraste(ManiColors.onInk, ManiColors.ink),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contraste(ManiColors.onInk, ManiColors.danger),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('cada ManiTono tiene texto AA sobre su fondo', () {
    for (final tono in ManiTono.values) {
      expect(
        contraste(tono.texto, tono.fondo),
        greaterThanOrEqualTo(4.5),
        reason: tono.name,
      );
    }
  });

  test('bordes y foco se distinguen del fondo (3:1, WCAG 1.4.11)', () {
    for (final f in [...fondos.values, ManiColors.brand]) {
      expect(contraste(ManiColors.border, f), greaterThanOrEqualTo(3));
      expect(contraste(ManiColors.focus, f), greaterThanOrEqualTo(3));
    }
  });

  test('el amarillo de marca nunca es legible como texto sobre claro', () {
    // Documenta la regla: el amarillo solo es fondo.
    expect(contraste(ManiColors.brand, ManiColors.surface), lessThan(3));
  });
}
