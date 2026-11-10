import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mani/core/theme/tokens/mani_colors.dart';

/// Escala tipográfica de MANI (Plus Jakarta Sans).
///
/// Los tamaños son los únicos permitidos en la app; los estilos de
/// [ManiText] los combinan con peso, interlineado y tracking. En pantallas se
/// prefiere `Theme.of(context).textTheme.*`, que se construye con esta escala.
abstract final class ManiFontSize {
  static const double micro = 11;
  static const double caption = 12;
  static const double bodySm = 13;
  static const double body = 14;
  static const double bodyLg = 16;
  static const double title = 18;
  static const double h3 = 20;
  static const double h2 = 24;
  static const double h1 = 32;
  static const double display = 40;
}

/// Estilos con nombre, ya en Plus Jakarta Sans con el peso correcto. Se
/// ajustan con `copyWith` (color, peso) sin volver a declarar la fuente.
abstract final class ManiText {
  static const TextStyle _display = TextStyle(
    fontSize: ManiFontSize.display,
    fontWeight: FontWeight.w900,
    height: 1.05,
    letterSpacing: -1.2,
    color: ManiColors.ink,
  );
  static const TextStyle _h1 = TextStyle(
    fontSize: ManiFontSize.h1,
    fontWeight: FontWeight.w900,
    height: 1.1,
    letterSpacing: -0.8,
    color: ManiColors.ink,
  );
  static const TextStyle _h2 = TextStyle(
    fontSize: ManiFontSize.h2,
    fontWeight: FontWeight.w900,
    height: 1.15,
    letterSpacing: -0.5,
    color: ManiColors.ink,
  );
  static const TextStyle _h3 = TextStyle(
    fontSize: ManiFontSize.h3,
    fontWeight: FontWeight.w900,
    height: 1.2,
    letterSpacing: -0.4,
    color: ManiColors.ink,
  );
  static const TextStyle _title = TextStyle(
    fontSize: ManiFontSize.title,
    fontWeight: FontWeight.w900,
    height: 1.25,
    color: ManiColors.ink,
  );
  static const TextStyle _subtitle = TextStyle(
    fontSize: ManiFontSize.bodyLg,
    fontWeight: FontWeight.w800,
    height: 1.3,
    color: ManiColors.ink,
  );
  static const TextStyle _bodyLg = TextStyle(
    fontSize: ManiFontSize.bodyLg,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: ManiColors.ink,
  );
  static const TextStyle _body = TextStyle(
    fontSize: ManiFontSize.body,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: ManiColors.ink,
  );
  static const TextStyle _bodySm = TextStyle(
    fontSize: ManiFontSize.bodySm,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: ManiColors.inkMuted,
  );
  static const TextStyle _label = TextStyle(
    fontSize: ManiFontSize.bodySm,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
    color: ManiColors.ink,
  );
  static const TextStyle _caption = TextStyle(
    fontSize: ManiFontSize.caption,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: ManiColors.inkMuted,
  );

  static const TextStyle _overline = TextStyle(
    fontSize: ManiFontSize.micro,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.6,
    color: ManiColors.ink,
  );

  // Estilos públicos: pasan por GoogleFonts para que cada peso cargue su
  // propio archivo (Plus Jakarta Sans registra una familia por variante).
  static TextStyle _f(TextStyle base) =>
      GoogleFonts.plusJakartaSans(textStyle: base);

  static TextStyle get display => _f(_display);
  static TextStyle get h1 => _f(_h1);
  static TextStyle get h2 => _f(_h2);
  static TextStyle get h3 => _f(_h3);
  static TextStyle get title => _f(_title);
  static TextStyle get subtitle => _f(_subtitle);
  static TextStyle get bodyLg => _f(_bodyLg);
  static TextStyle get body => _f(_body);
  static TextStyle get bodySm => _f(_bodySm);
  static TextStyle get label => _f(_label);
  static TextStyle get caption => _f(_caption);

  /// Etiqueta en mayúsculas de campos y encabezados de columna.
  static TextStyle get overline => _f(_overline);

  /// `TextTheme` de Material construido con la escala, en Plus Jakarta Sans.
  static TextTheme textTheme() => GoogleFonts.plusJakartaSansTextTheme(
    const TextTheme(
      displayLarge: _display,
      displayMedium: _h1,
      displaySmall: _h2,
      headlineLarge: _h1,
      headlineMedium: _h2,
      headlineSmall: _h3,
      titleLarge: _title,
      titleMedium: _subtitle,
      titleSmall: _label,
      bodyLarge: _bodyLg,
      bodyMedium: _body,
      bodySmall: _bodySm,
      labelLarge: _label,
      labelMedium: _caption,
      labelSmall: _overline,
    ),
  );
}
