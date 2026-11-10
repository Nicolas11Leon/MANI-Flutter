import 'package:flutter/material.dart';

/// Paleta semántica de MANI (identidad neo-brutalista del Figma oficial).
///
/// Cada par texto/fondo que se declara aquí cumple WCAG AA (≥ 4.5:1 para
/// texto normal); lo verifica `test/core/theme/contrast_test.dart`. Reglas:
/// - La marca [brand] es fondo, nunca color de texto: sobre ella va [onBrand]
///   (y [onBrandMuted] para texto secundario).
/// - [danger] es el rojo de relleno (texto blanco encima); [dangerText] es el
///   rojo legible sobre fondos claros y contenedores.
/// - Los `*Container` son fondos tenues de estado; su texto es el `*Text`.
abstract final class ManiColors {
  // ── Superficies ─────────────────────────────────────────────────────────
  /// Crema cálido de fondo de página.
  static const Color background = Color(0xFFFDFBF7);

  /// Tarjetas, campos y diálogos.
  static const Color surface = Color(0xFFFFFFFF);

  /// Superficie hundida (fondos de grupo, filas alternas, chips neutros).
  static const Color surfaceMuted = Color(0xFFF5F3EE);

  /// Fondo cálido de secciones destacadas (antes `#F6EFDA` suelto).
  static const Color surfaceWarm = Color(0xFFF6EFDA);

  // ── Tinta ───────────────────────────────────────────────────────────────
  /// Texto principal, bordes y sombras duras.
  static const Color ink = Color(0xFF1E1E1E);

  /// Texto secundario (5.6:1 sobre crema).
  static const Color inkMuted = Color(0xFF5F6672);

  /// Texto terciario y marcadores: 4.7:1 sobre la superficie hundida y 5:1
  /// sobre crema (el antiguo `#9CA3AF` daba 2.5:1).
  static const Color inkSubtle = Color(0xFF666D79);

  /// Texto e íconos sobre fondos oscuros ([ink], [danger]).
  static const Color onInk = Color(0xFFFFFFFF);

  // ── Bordes ──────────────────────────────────────────────────────────────
  /// Borde neo-brutalista: el mismo carbón de la tinta.
  static const Color border = ink;

  /// Separadores suaves y estados deshabilitados.
  static const Color borderSubtle = Color(0xFFE5E7EB);

  // ── Marca ───────────────────────────────────────────────────────────────
  /// Color de marca MANI, fijado por producto el 2026-11-10 (antes #FACC15).
  /// Contra el fondo da 1.3:1: un relleno de marca siempre lleva el borde
  /// carbón para distinguirse, nunca se apoya solo en el color.
  static const Color brand = Color(0xFFF8DE7E);

  /// Texto e íconos sobre [brand] (12.5:1).
  static const Color onBrand = ink;

  /// Texto secundario sobre [brand] o [brandSoft], tinta tomada del mismo tono
  /// (5.3:1 sobre la marca; el gris [inkMuted] solo llega a 4.3:1 ahí).
  static const Color onBrandMuted = Color(0xFF5F583B);

  /// Tinte tenue de la marca para selección y resaltado (15:1 con tinta).
  static const Color brandSoft = Color(0xFFFDF3D2);

  // ── Estados ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF15803D);
  static const Color successText = Color(0xFF166534);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color successBorder = Color(0xFFBBF7D0);

  static const Color warning = Color(0xFFB45309);
  static const Color warningText = Color(0xFF92400E);
  static const Color warningContainer = Color(0xFFFEF3C7);

  /// Rojo de relleno: texto blanco encima con 4.8:1.
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerText = Color(0xFFB91C1C);
  static const Color dangerContainer = Color(0xFFFEE2E2);
  static const Color dangerBorder = Color(0xFFFECACA);

  static const Color info = Color(0xFF1D4ED8);
  static const Color infoText = Color(0xFF1E40AF);
  static const Color infoContainer = Color(0xFFDBEAFE);
  static const Color infoBorder = Color(0xFFBFDBFE);

  /// Acento secundario (índigo) para estados neutros "en curso".
  static const Color accent = Color(0xFF3730A3);
  static const Color accentContainer = Color(0xFFE0E7FF);

  // ── Interacción ─────────────────────────────────────────────────────────
  /// Anillo de foco de teclado: carbón sobre la marca es visible en todas las
  /// superficies claras de la app.
  static const Color focus = ink;

  /// Velo de modales y visores.
  static const Color scrim = Color(0xA6000000);
}
