import 'package:flutter/material.dart';

/// Paleta semántica de MANI (identidad neo-brutalista «La ficha sellada»).
///
/// Basada en la paleta cálida Maní:
/// - Crema durazno (`#FED1B0`) como sello de marca ([brand]).
/// - Café maní tostado (`#894C2F`) como acento cálido ([accent]).
/// - Azul cobalto (`#0065B3`) como color informativo y operativo ([info]).
/// - Rojo intenso (`#EE1C25` / `#D61921`) para alertas y peligro ([danger]).
/// - Blanco puro (`#FFFFFF`) sobre papel cálido (`#FAF6F2`).
///
/// Cada par texto/fondo que se declara aquí cumple WCAG AA (≥ 4.5:1 para
/// texto normal); lo verifica `test/core/theme/contrast_test.dart`. Reglas:
/// - La marca [brand] es fondo, nunca color de texto: sobre ella va [onBrand]
///   (y [onBrandMuted] para texto secundario).
/// - [danger] es el rojo de relleno (texto blanco encima); [dangerText] es el
///   rojo legible sobre fondos claros y contenedores.
/// - Los `*Container` son fondos tenues de estado; su texto es el `*Text`.
abstract final class ManiColors {
  // ── Superficies (Modo Claro) ────────────────────────────────────────────
  /// Papel crema cálido de fondo de página.
  static const Color background = Color(0xFFFAF6F2);

  /// Tarjetas, campos y diálogos (`#FFFFFF` de la paleta).
  static const Color surface = Color(0xFFFFFFFF);

  /// Superficie hundida (fondos de grupo, filas alternas, chips neutros).
  static const Color surfaceMuted = Color(0xFFF3ECE6);

  /// Fondo cálido de secciones destacadas.
  static const Color surfaceWarm = Color(0xFFFCE6D4);

  // ── Tinta (Modo Claro) ──────────────────────────────────────────────────
  /// Texto principal, bordes y sombras duras (carbón espresso cálido).
  static const Color ink = Color(0xFF1C1613);

  /// Texto secundario (≥ 5.5:1 sobre todas las superficies claras).
  static const Color inkMuted = Color(0xFF5C5049);

  /// Texto terciario y marcadores (≥ 4.6:1 sobre superficie hundida y crema).
  static const Color inkSubtle = Color(0xFF665A52);

  /// Texto e íconos sobre fondos oscuros ([ink], [danger]).
  static const Color onInk = Color(0xFFFFFFFF);

  // ── Bordes ──────────────────────────────────────────────────────────────
  /// Borde neo-brutalista: el mismo carbón de la tinta.
  static const Color border = ink;

  /// Separadores suaves y estados deshabilitados.
  static const Color borderSubtle = Color(0xFFE4DAD1);

  // ── Marca (`#FED1B0` + `#894C2F`) ───────────────────────────────────────
  /// Color de marca MANI (`#FED1B0`, crema durazno cálido).
  /// Un relleno de marca siempre lleva borde carbón para distinguirse,
  /// nunca se apoya solo en el color.
  static const Color brand = Color(0xFFFED1B0);

  /// Texto e íconos sobre [brand] (11.9:1).
  static const Color onBrand = ink;

  /// Texto secundario sobre [brand] o [brandSoft], derivado del café maní
  /// (`#894C2F` oscurecido a `#63341E` para ≥ 4.8:1 sobre `#FED1B0`).
  static const Color onBrandMuted = Color(0xFF63341E);

  /// Tinte tenue de la marca para selección y resaltado.
  static const Color brandSoft = Color(0xFFFFF2E8);

  // ── Estados ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF15803D);
  static const Color successText = Color(0xFF166534);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color successBorder = Color(0xFFBBF7D0);

  static const Color warning = Color(0xFFB45309);
  static const Color warningText = Color(0xFF92400E);
  static const Color warningContainer = Color(0xFFFEF3C7);

  /// Rojo base de la paleta (`#EE1C25`) y su ajuste AA (`#D61921`) para que
  /// cumpla ≥ 4.5:1 tanto con texto blanco encima como sobre crema/blanco.
  static const Color paletteRed = Color(0xFFEE1C25);
  static const Color danger = Color(0xFFD61921);
  static const Color dangerText = Color(0xFFB01219);
  static const Color dangerContainer = Color(0xFFFEE2E2);
  static const Color dangerBorder = Color(0xFFFECACA);

  /// Azul cobalto de la paleta (`#0065B3`) para información y acciones.
  static const Color info = Color(0xFF0065B3);
  static const Color infoText = Color(0xFF005294);
  static const Color infoContainer = Color(0xFFE0F0FF);
  static const Color infoBorder = Color(0xFFB3D9FF);

  /// Acento secundario cálido (`#894C2F`, café maní tostado de la paleta).
  static const Color accent = Color(0xFF894C2F);
  static const Color accentContainer = Color(0xFFF7E6DC);

  // ── Interacción ─────────────────────────────────────────────────────────
  /// Anillo de foco de teclado: carbón sobre la marca es visible en todas las
  /// superficies claras de la app.
  static const Color focus = ink;

  /// Velo de modales y visores.
  static const Color scrim = Color(0xA6000000);
}

/// Paleta semántica de MANI para Modo Oscuro («La ficha sellada nocturna»).
///
/// Diseñada explícitamente con superficies cálidas de espresso tostado,
/// bordes crema de alto contraste y sellos en durazno (`#FED1B0`) con tinta
/// oscura (`#1C1613`).
abstract final class ManiDarkColors {
  static const Color background = Color(0xFF14110F);
  static const Color surface = Color(0xFF1F1A17);
  static const Color surfaceMuted = Color(0xFF2B2420);
  static const Color surfaceWarm = Color(0xFF362A22);

  static const Color ink = Color(0xFFF7F2ED);
  static const Color inkMuted = Color(0xFFC4B5AA);
  static const Color inkSubtle = Color(0xFF9E8E83);
  static const Color onInk = Color(0xFF14110F);

  static const Color border = Color(0xFFD6C2B2);
  static const Color borderSubtle = Color(0xFF3D332D);

  static const Color brand = Color(0xFFFED1B0);
  static const Color onBrand = Color(0xFF1C1613);
  static const Color onBrandMuted = Color(0xFF63341E);
  static const Color brandSoft = Color(0xFF3A291F);

  static const Color shadow = Color(0xFF050403);
}
