import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de diseño oficial de MANI — Neo-Brutalismo.
/// Los valores son los mismos que los de la landing (`MANI-Landing/src/index.css`), para que una marca no tenga dos
/// versiones de un mismo concepto (SCRUM-1646):
/// - Fondo: crema #FBF3E4; tarjetas: blanco
/// - Primario: amarillo #F2B705; tinta, bordes y texto: azul marino #1B2A4A
/// - Sombras duras (sin desenfoque): 3, 5 y 8 px en azul marino
/// - Radios 8, 16 y 24 px; botones y etiquetas en píldora
/// - Tipografía: Plus Jakarta Sans para el texto y Fredoka para los títulos
class AppTheme {
  AppTheme._();

  // ── Colores base ──────────────────────────────────────────────────────────
  static const Color background = Color(0xFFFBF3E4); // Crema de fondo
  static const Color backgroundSoft = Color(0xFFFFF9EE); // Crema suave
  static const Color backgroundDark = Color(0xFFF3E5CD); // Crema oscuro
  static const Color surface = Color(0xFFFFFFFF); // Blanco de tarjetas
  static const Color primary = Color(0xFFF2B705); // Amarillo MANI
  static const Color primaryLight = Color(0xFFFDE896);
  static const Color primaryHover = Color(0xFFDFA400);
  static const Color dark = Color(0xFF1B2A4A); // Tinta: azul marino / bordes
  static const Color darkDeep = Color(0xFF0F192E);
  static const Color darkLight = Color(0xFF2C4372);
  static const Color textPrimary = Color(0xFF1B2A4A);
  static const Color textSecondary = Color(0xFF536485); // Azul marino atenuado
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color borderLight = Color(0xFFF3E5CD);

  // ── Colores de estado ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFE4572E);
  static const Color errorHover = Color(0xFFCC441C);
  static const Color errorLight = Color(0xFFFDE5DE);

  // ── Sombras neo-brutalistas ───────────────────────────────────────────────
  static const BoxShadow hardShadowSm = BoxShadow(
    color: dark,
    offset: Offset(3, 3),
    blurRadius: 0,
  );

  static const BoxShadow hardShadowMd = BoxShadow(
    color: dark,
    offset: Offset(5, 5),
    blurRadius: 0,
  );

  static const BoxShadow hardShadowLg = BoxShadow(
    color: dark,
    offset: Offset(8, 8),
    blurRadius: 0,
  );

  /// Sombra al pasar el cursor o con un botón en reposo elevado.
  static const BoxShadow hardShadowHover = BoxShadow(
    color: dark,
    offset: Offset(2, 2),
    blurRadius: 0,
  );

  // ── Radios de borde ───────────────────────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusPill = 9999.0;
  // Alias de los nombres anteriores, que ya usa el código: apuntan a la escala de la landing.
  static const double radiusXl = radiusMd;
  static const double radius2xl = radiusLg;

  // ── Grosores de borde ─────────────────────────────────────────────────────
  static const double borderThick = 3.0;
  static const double borderMedium = 2.5;
  static const double borderThin = 1.5;

  // ── Movimiento ────────────────────────────────────────────────────────────
  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionBase = Duration(milliseconds: 220);
  static const Duration motionSlow = Duration(milliseconds: 250);
  static const Curve motionBounce = Cubic(0.34, 1.56, 0.64, 1);

  static ThemeData get light {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      // Familia de toda la app, no solo de `textTheme`: así `primaryTextTheme`,
      // tooltips y cualquier texto sin estilo propio usan Plus Jakarta Sans y
      // no caen en Roboto.
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(),
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: textPrimary,
        secondary: primary,
        onSecondary: textPrimary,
        surface: surface,
        onSurface: textPrimary,
        error: error,
      ),
      textTheme: textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: dark,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: dark,
        ),
        shape: const Border(
          bottom: BorderSide(color: dark, width: borderThick),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: dark, width: borderThick),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primary,
        selectedColor: primary,
        secondarySelectedColor: primary,
        disabledColor: borderLight,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: const BorderSide(color: dark, width: borderMedium),
        shape: const StadiumBorder(),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: dark,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: dark,
          disabledBackgroundColor: borderLight,
          disabledForegroundColor: textSecondary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
          shape: const StadiumBorder(
            side: BorderSide(color: dark, width: borderThick),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: dark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
          shape: const StadiumBorder(
            side: BorderSide(color: dark, width: borderThick),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: dark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          side: const BorderSide(color: dark, width: borderThick),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: dark,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          borderSide: const BorderSide(color: dark, width: borderMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          borderSide: const BorderSide(color: dark, width: borderMedium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          borderSide: const BorderSide(color: dark, width: borderThick),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          borderSide: const BorderSide(color: error, width: borderMedium),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          borderSide: const BorderSide(color: error, width: borderThick),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius2xl),
          side: const BorderSide(color: dark, width: borderThick),
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: dark,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(color: dark, width: borderMedium),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(color: primary, width: borderMedium),
        ),
      ),
      dividerTheme: const DividerThemeData(color: dark, thickness: 1.5),
    );
  }
}
