import 'package:flutter/widgets.dart';

/// Escala de espaciado de MANI: múltiplos de 4 (con 2 para ajustes finos).
///
/// Se usa para padding, márgenes y separaciones; ningún widget debe escribir
/// un número suelto de espacio.
abstract final class ManiSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 48;

  /// Márgenes laterales de página en móvil y en pantallas medianas o mayores.
  static const double paginaMovil = lg;
  static const double paginaAncha = 36;
}

/// Separadores verticales (`v*`) y horizontales (`h*`) de la escala.
abstract final class ManiGap {
  static const SizedBox vXxs = SizedBox(height: ManiSpace.xxs);
  static const SizedBox vXs = SizedBox(height: ManiSpace.xs);
  static const SizedBox vSm = SizedBox(height: ManiSpace.sm);
  static const SizedBox vMd = SizedBox(height: ManiSpace.md);
  static const SizedBox vLg = SizedBox(height: ManiSpace.lg);
  static const SizedBox vXl = SizedBox(height: ManiSpace.xl);
  static const SizedBox vXxl = SizedBox(height: ManiSpace.xxl);
  static const SizedBox vXxxl = SizedBox(height: ManiSpace.xxxl);
  static const SizedBox vHuge = SizedBox(height: ManiSpace.huge);

  static const SizedBox hXxs = SizedBox(width: ManiSpace.xxs);
  static const SizedBox hXs = SizedBox(width: ManiSpace.xs);
  static const SizedBox hSm = SizedBox(width: ManiSpace.sm);
  static const SizedBox hMd = SizedBox(width: ManiSpace.md);
  static const SizedBox hLg = SizedBox(width: ManiSpace.lg);
  static const SizedBox hXl = SizedBox(width: ManiSpace.xl);
  static const SizedBox hXxl = SizedBox(width: ManiSpace.xxl);
  static const SizedBox hXxxl = SizedBox(width: ManiSpace.xxxl);
}
