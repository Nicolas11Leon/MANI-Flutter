import 'package:flutter/widgets.dart';
import 'package:mani/core/theme/tokens/mani_colors.dart';

/// Radios de esquina.
abstract final class ManiRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}

/// Grosores de borde neo-brutalista.
abstract final class ManiBorder {
  /// Chips, filas y divisores internos.
  static const double thin = 1.5;

  /// Borde estándar de tarjetas, campos y botones.
  static const double regular = 2;

  /// Foco y diálogos.
  static const double thick = 2.5;

  static const BorderSide side = BorderSide(
    color: ManiColors.border,
    width: regular,
  );
  static const BorderSide sideThin = BorderSide(
    color: ManiColors.border,
    width: thin,
  );
  static const BorderSide sideThick = BorderSide(
    color: ManiColors.border,
    width: thick,
  );
}

/// Sombras duras (sin desenfoque) del Figma.
abstract final class ManiShadow {
  static const BoxShadow sm = BoxShadow(
    color: ManiColors.ink,
    offset: Offset(2, 2),
  );
  static const BoxShadow md = BoxShadow(
    color: ManiColors.ink,
    offset: Offset(4, 4),
  );
  static const BoxShadow lg = BoxShadow(
    color: ManiColors.ink,
    offset: Offset(6, 6),
  );

  /// Desplazamiento que recorre un control al hundirse (la sombra [sm]
  /// desaparece y el control ocupa su lugar).
  static const double hundimiento = 2;
}

/// Decoración estándar de tarjeta: superficie, borde de 2 px y sombra dura.
BoxDecoration maniDecoracion({
  Color color = ManiColors.surface,
  BoxShadow? sombra = ManiShadow.md,
  BorderRadius radio = ManiRadius.brLg,
  Color borde = ManiColors.border,
}) => BoxDecoration(
  color: color,
  borderRadius: radio,
  border: Border.all(color: borde, width: ManiBorder.regular),
  boxShadow: [?sombra],
);
