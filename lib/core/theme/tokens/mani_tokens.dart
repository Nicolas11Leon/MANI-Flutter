import 'package:flutter/material.dart';
import 'package:mani/core/theme/tokens/mani_colors.dart';
import 'package:mani/core/theme/tokens/mani_shape.dart';

export 'mani_colors.dart';
export 'mani_motion.dart';
export 'mani_shape.dart';
export 'mani_spacing.dart';
export 'mani_typography.dart';

/// Tokens de MANI expuestos por el tema, para el código que deba reaccionar
/// a un tema distinto (alto contraste, oscuro) sin tocar cada pantalla.
@immutable
class ManiTokens extends ThemeExtension<ManiTokens> {
  const ManiTokens({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.inkMuted,
    required this.border,
    required this.brand,
    required this.brandSoft,
    required this.shadow,
  });

  static const ManiTokens claro = ManiTokens(
    background: ManiColors.background,
    surface: ManiColors.surface,
    surfaceMuted: ManiColors.surfaceMuted,
    ink: ManiColors.ink,
    inkMuted: ManiColors.inkMuted,
    border: ManiColors.border,
    brand: ManiColors.brand,
    brandSoft: ManiColors.brandSoft,
    shadow: ManiShadow.md,
  );

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color ink;
  final Color inkMuted;
  final Color border;
  final Color brand;
  final Color brandSoft;
  final BoxShadow shadow;

  @override
  ManiTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? ink,
    Color? inkMuted,
    Color? border,
    Color? brand,
    Color? brandSoft,
    BoxShadow? shadow,
  }) => ManiTokens(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    border: border ?? this.border,
    brand: brand ?? this.brand,
    brandSoft: brandSoft ?? this.brandSoft,
    shadow: shadow ?? this.shadow,
  );

  @override
  ManiTokens lerp(ManiTokens? other, double t) {
    if (other == null) return this;
    return ManiTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      shadow: BoxShadow.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension ManiTokensContext on BuildContext {
  /// Tokens del tema actual (los claros si el tema no los declara).
  ManiTokens get mani =>
      Theme.of(this).extension<ManiTokens>() ?? ManiTokens.claro;
}
