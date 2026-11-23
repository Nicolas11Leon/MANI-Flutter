import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Los valores del sistema de diseño viven en los tokens de
/// `lib/core/theme/tokens/` (DESIGN.md): si alguien los cambia, que sea a
/// propósito. El contraste de cada par texto/fondo lo cubre `contrast_test`.
void main() {
  group('tokens', () {
    test('colores de marca', () {
      expect(ManiColors.background, const Color(0xFFFAF6F2));
      expect(ManiColors.brand, const Color(0xFFFED1B0));
      expect(ManiColors.ink, const Color(0xFF1C1613));
      expect(ManiColors.surface, const Color(0xFFFFFFFF));
      expect(ManiColors.border, ManiColors.ink);
    });

    test('titulo() sin color toma el del tema, no una tinta fija', () {
      expect(AppTheme.titulo().color, isNull);
      expect(
        AppTheme.titulo(color: ManiColors.inkMuted).color,
        ManiColors.inkMuted,
      );
    });

    test('sombras duras de 2, 4 y 6 px, sin desenfoque', () {
      expect(ManiShadow.sm.offset, const Offset(2, 2));
      expect(ManiShadow.md.offset, const Offset(4, 4));
      expect(ManiShadow.lg.offset, const Offset(6, 6));
      for (final s in [ManiShadow.sm, ManiShadow.md, ManiShadow.lg]) {
        expect(s.blurRadius, 0);
        expect(s.color, ManiColors.ink);
      }
    });

    test('bordes y movimiento', () {
      expect(
        [ManiBorder.thin, ManiBorder.regular, ManiBorder.thick],
        [1.5, 2, 2.5],
      );
      expect(ManiMotion.fast, const Duration(milliseconds: 120));
      expect(ManiMotion.base, const Duration(milliseconds: 200));
      expect(ManiMotion.slow, const Duration(milliseconds: 320));
    });
  });

  group('ThemeData', () {
    for (final (nombre, tema, tokens) in [
      ('claro', AppTheme.light, ManiTokens.claro),
      ('oscuro', AppTheme.dark, ManiTokens.oscuro),
    ]) {
      test('$nombre: Material 3 y fondo, primario y campos de sus tokens', () {
        expect(tema.useMaterial3, isTrue);
        expect(tema.scaffoldBackgroundColor, tokens.background);
        expect(tema.colorScheme.primary, tokens.brand);
        expect(tema.inputDecorationTheme.filled, isTrue);
        expect(tema.inputDecorationTheme.fillColor, tokens.surface);
      });
    }

    test('la barra superior no tiene elevación y usa la tinta', () {
      final barra = AppTheme.light.appBarTheme;
      expect(barra.elevation, 0);
      expect(barra.foregroundColor, ManiTokens.claro.ink);
    });
  });
}
