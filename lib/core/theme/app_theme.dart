import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mani/core/theme/transicion_de_pantalla.dart';

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
  /// Solo para texto de ejemplo en campos: sobre blanco no llega al contraste AA.
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color borderLight = Color(0xFFF3E5CD);

  // ── Colores de estado ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFE4572E);
  static const Color errorHover = Color(0xFFCC441C);
  static const Color errorLight = Color(0xFFFDE5DE);

  // ── Sobriedad ─────────────────────────────────────────────────────────────
  static const Color divisor = Color(0xFFF3E5CD); // Divisor entre filas
  static const Color errorStrong = Color(
    0xFFB8401D,
  ); // Texto de error y botón de peligro
  static const Color successStrong = Color(
    0xFF047857,
  ); // Texto sobre successLight
  static const Color avisoFondo = Color(0xFFFEF3C7);
  static const Color avisoTexto = Color(0xFF92600A); // Texto sobre avisoFondo
  static const double borderHair = 1.0;

  // ── Espaciado ─────────────────────────────────────────────────────────────
  static const double esp1 = 4;
  static const double esp2 = 8;
  static const double esp3 = 12;
  static const double esp4 = 16;
  static const double esp5 = 24;
  static const double esp6 = 32;
  static const double esp7 = 48;

  /// Radio intermedio para cajas de icono y miniaturas.
  static const double radiusIcon = 12.0;

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

  /// Fuente de títulos (la de la landing): Fredoka a 600.
  static TextStyle titulo({
    double size = 18,
    double height = 24 / 18,
    Color color = textPrimary,
  }) => GoogleFonts.fredoka(
    fontSize: size,
    height: height,
    fontWeight: FontWeight.w600,
    color: color,
  );

  /// Escala tipográfica: títulos en Fredoka, el resto en Plus Jakarta Sans. Mínimo absoluto 12 px.
  static TextTheme _escala() {
    final base = GoogleFonts.plusJakartaSansTextTheme();
    return base.copyWith(
      displaySmall: titulo(size: 28, height: 32 / 28),
      headlineSmall: titulo(size: 24, height: 30 / 24),
      titleLarge: titulo(size: 20, height: 26 / 20),
      titleMedium: titulo(),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: 21 / 14,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        height: 19 / 13,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w800,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static ThemeData get light {
    final textTheme = _escala();

    return ThemeData(
      useMaterial3: true,
      // Cambio de pantalla en desvanecimiento, sin zoom ni superposición (ver `TransicionDePantalla`).
      pageTransitionsTheme: pageTransitionsDeMani,
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
        titleTextStyle: titulo(size: 20, height: 26 / 20, color: dark),
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
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(surface),
        trackColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected) ? primary : backgroundDark,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(dark),
        trackOutlineWidth: const WidgetStatePropertyAll(borderThin),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected) ? primary : surface,
        ),
        checkColor: const WidgetStatePropertyAll(dark),
        side: const BorderSide(color: dark, width: borderThin),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(fillColor: const WidgetStatePropertyAll(dark)),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: dark,
        linearTrackColor: backgroundDark,
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
        errorStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: errorStrong,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: dark, width: borderThin),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: dark, width: borderThin),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: dark, width: borderMedium),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: errorStrong, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: errorStrong, width: borderMedium),
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
