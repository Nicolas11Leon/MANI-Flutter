import 'package:flutter/material.dart';
import 'package:mani/core/theme/tokens/mani_colors.dart';
import 'package:mani/core/theme/tokens/mani_shape.dart';

export 'mani_colors.dart';
export 'mani_motion.dart';
export 'mani_shape.dart';
export 'mani_spacing.dart';
export 'mani_typography.dart';

/// Tokens de MANI expuestos por el tema, para el código que reacciona al
/// tema activo (`AppTheme.light` / `AppTheme.dark`) sin acoplar cada pantalla
/// a colores fijos.
@immutable
class ManiTokens extends ThemeExtension<ManiTokens> {
  const ManiTokens({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    this.surfaceWarm = ManiColors.surfaceWarm,
    required this.ink,
    required this.inkMuted,
    this.inkSubtle = ManiColors.inkSubtle,
    required this.border,
    this.borderSubtle = ManiColors.borderSubtle,
    required this.brand,
    this.onBrand = ManiColors.onBrand,
    required this.brandSoft,
    required this.shadow,
    this.shadowSm = ManiShadow.sm,
    this.shadowLg = ManiShadow.lg,
  });

  static const ManiTokens claro = ManiTokens(
    background: ManiColors.background,
    surface: ManiColors.surface,
    surfaceMuted: ManiColors.surfaceMuted,
    surfaceWarm: ManiColors.surfaceWarm,
    ink: ManiColors.ink,
    inkMuted: ManiColors.inkMuted,
    inkSubtle: ManiColors.inkSubtle,
    border: ManiColors.border,
    borderSubtle: ManiColors.borderSubtle,
    brand: ManiColors.brand,
    onBrand: ManiColors.onBrand,
    brandSoft: ManiColors.brandSoft,
    shadow: ManiShadow.md,
    shadowSm: ManiShadow.sm,
    shadowLg: ManiShadow.lg,
  );

  static const ManiTokens oscuro = ManiTokens(
    background: ManiDarkColors.background,
    surface: ManiDarkColors.surface,
    surfaceMuted: ManiDarkColors.surfaceMuted,
    surfaceWarm: ManiDarkColors.surfaceWarm,
    ink: ManiDarkColors.ink,
    inkMuted: ManiDarkColors.inkMuted,
    inkSubtle: ManiDarkColors.inkSubtle,
    border: ManiDarkColors.border,
    borderSubtle: ManiDarkColors.borderSubtle,
    brand: ManiDarkColors.brand,
    onBrand: ManiDarkColors.onBrand,
    brandSoft: ManiDarkColors.brandSoft,
    shadow: BoxShadow(color: ManiDarkColors.shadow, offset: Offset(4, 4)),
    shadowSm: BoxShadow(color: ManiDarkColors.shadow, offset: Offset(2, 2)),
    shadowLg: BoxShadow(color: ManiDarkColors.shadow, offset: Offset(6, 6)),
  );

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceWarm;
  final Color ink;
  final Color inkMuted;
  final Color inkSubtle;
  final Color border;
  final Color borderSubtle;
  final Color brand;
  final Color onBrand;
  final Color brandSoft;
  final BoxShadow shadow;
  final BoxShadow shadowSm;
  final BoxShadow shadowLg;

  @override
  ManiTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceWarm,
    Color? ink,
    Color? inkMuted,
    Color? inkSubtle,
    Color? border,
    Color? borderSubtle,
    Color? brand,
    Color? onBrand,
    Color? brandSoft,
    BoxShadow? shadow,
    BoxShadow? shadowSm,
    BoxShadow? shadowLg,
  }) => ManiTokens(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    surfaceWarm: surfaceWarm ?? this.surfaceWarm,
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    inkSubtle: inkSubtle ?? this.inkSubtle,
    border: border ?? this.border,
    borderSubtle: borderSubtle ?? this.borderSubtle,
    brand: brand ?? this.brand,
    onBrand: onBrand ?? this.onBrand,
    brandSoft: brandSoft ?? this.brandSoft,
    shadow: shadow ?? this.shadow,
    shadowSm: shadowSm ?? this.shadowSm,
    shadowLg: shadowLg ?? this.shadowLg,
  );

  @override
  ManiTokens lerp(ManiTokens? other, double t) {
    if (other == null) return this;
    return ManiTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceWarm: Color.lerp(surfaceWarm, other.surfaceWarm, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkSubtle: Color.lerp(inkSubtle, other.inkSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      shadow: BoxShadow.lerp(shadow, other.shadow, t)!,
      shadowSm: BoxShadow.lerp(shadowSm, other.shadowSm, t)!,
      shadowLg: BoxShadow.lerp(shadowLg, other.shadowLg, t)!,
    );
  }
}

extension ManiTokensContext on BuildContext {
  /// Tokens del tema actual (los claros si el tema no los declara).
  ManiTokens get mani =>
      Theme.of(this).extension<ManiTokens>() ?? ManiTokens.claro;

  /// Indica si el tema actual está en modo oscuro.
  bool get esModoOscuro => Theme.of(this).brightness == Brightness.dark;
}
