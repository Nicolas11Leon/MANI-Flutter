import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/theme/app_theme.dart';

/// El sistema de diseño comparte valores con la landing (SCRUM-1646): si alguien los cambia, que sea a propósito.
void main() {
  group('tokens de la landing', () {
    test('colores de marca', () {
      expect(AppTheme.background, const Color(0xFFFBF3E4));
      expect(AppTheme.primary, const Color(0xFFF2B705));
      expect(AppTheme.dark, const Color(0xFF1B2A4A));
      expect(AppTheme.surface, const Color(0xFFFFFFFF));
      expect(AppTheme.errorLight, const Color(0xFFFDE5DE));
    });

    test('sombras duras de 3, 5 y 8 px, sin desenfoque', () {
      expect(AppTheme.hardShadowSm.offset, const Offset(3, 3));
      expect(AppTheme.hardShadowMd.offset, const Offset(5, 5));
      expect(AppTheme.hardShadowLg.offset, const Offset(8, 8));
      for (final s in [
        AppTheme.hardShadowSm,
        AppTheme.hardShadowMd,
        AppTheme.hardShadowLg,
        AppTheme.hardShadowHover,
      ]) {
        expect(s.blurRadius, 0);
        expect(s.color, AppTheme.dark);
      }
    });

    test('radios, bordes y movimiento', () {
      expect(
        [AppTheme.radiusSm, AppTheme.radiusMd, AppTheme.radiusLg],
        [8, 16, 24],
      );
      // Los nombres anteriores siguen apuntando a la escala nueva.
      expect(AppTheme.radiusXl, AppTheme.radiusMd);
      expect(AppTheme.radius2xl, AppTheme.radiusLg);
      expect(
        [AppTheme.borderThin, AppTheme.borderMedium, AppTheme.borderThick],
        [1.5, 2.5, 3.0],
      );
      expect(AppTheme.motionFast, const Duration(milliseconds: 150));
      expect(AppTheme.motionBase, const Duration(milliseconds: 220));
      expect(AppTheme.motionSlow, const Duration(milliseconds: 250));
      expect(AppTheme.motionBounce.transform(1), closeTo(1, 1e-9));
    });
  });

  group('ThemeData', () {
    late ThemeData tema;
    setUp(() => tema = AppTheme.light);

    test('usa Material 3 y el crema como fondo', () {
      expect(tema.useMaterial3, isTrue);
      expect(tema.scaffoldBackgroundColor, AppTheme.background);
      expect(tema.colorScheme.primary, AppTheme.primary);
      expect(tema.colorScheme.onPrimary, AppTheme.textPrimary);
    });

    test('la barra superior es crema-blanca con borde inferior grueso', () {
      final barra = tema.appBarTheme;
      expect(barra.elevation, 0);
      expect(barra.foregroundColor, AppTheme.dark);
      final borde = barra.shape! as Border;
      expect(borde.bottom.width, AppTheme.borderThick);
      expect(borde.bottom.color, AppTheme.dark);
    });

    test('las tarjetas y los campos usan la escala de radios y bordes', () {
      final tarjeta = tema.cardTheme.shape! as RoundedRectangleBorder;
      expect(tarjeta.borderRadius, BorderRadius.circular(AppTheme.radiusMd));

      final campo = tema.inputDecorationTheme;
      expect(campo.filled, isTrue);
      expect(campo.fillColor, AppTheme.surface);
      final reposo = campo.enabledBorder! as OutlineInputBorder;
      expect(reposo.borderSide.color, AppTheme.dark);
    });
  });
}
