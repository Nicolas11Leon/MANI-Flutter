import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de diseño oficial de MANI — Neo-Brutalismo.
/// Extraído directamente de los prototipos oficiales de Figma:
/// - Fondo principal: #FDFBF7 (Crema cálido)
/// - Primario / Acento insignia: #FACC15 (Amarillo MANI)
/// - Bordes y contrastes: #1E1E1E (Negro carbón)
/// - Superficies / Tarjetas: #FFFFFF
/// - Textos secundarios: #6B7280
/// - Sombras duras (Hard Shadows): sin desenfoque (offset con color #1E1E1E)
/// - Tipografía: Plus Jakarta Sans
class AppTheme {
  AppTheme._();

  // ── Colores base ──────────────────────────────────────────────────────────
  static const Color background = Color(0xFFFDFBF7); // Crema de fondo oficial
  static const Color surface = Color(0xFFFFFFFF); // Blanco
  static const Color primary = Color(
    0xFFFACC15,
  ); // Amarillo característico MANI
  static const Color dark = Color(0xFF1E1E1E); // Tinta negra / bordes
  static const Color textPrimary = Color(0xFF1E1E1E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color borderLight = Color(0xFFE5E7EB);

  // ── Colores de estado ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);

  // ── Sombras neo-brutalistas ───────────────────────────────────────────────
  static const BoxShadow hardShadowSm = BoxShadow(
    color: dark,
    offset: Offset(2, 2),
    blurRadius: 0,
  );

  static const BoxShadow hardShadowMd = BoxShadow(
    color: dark,
    offset: Offset(4, 4),
    blurRadius: 0,
  );

  static const BoxShadow hardShadowLg = BoxShadow(
    color: dark,
    offset: Offset(6, 6),
    blurRadius: 0,
  );

  // ── Radios de borde ───────────────────────────────────────────────────────
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusXl = 12.0;
  static const double radius2xl = 16.0;

  static ThemeData get light {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: textPrimary,
        surface: surface,
        onSurface: textPrimary,
        error: error,
      ),
      textTheme: textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }
}
