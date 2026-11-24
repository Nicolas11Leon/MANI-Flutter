import 'package:flutter/widgets.dart';

/// Duraciones y curvas de movimiento.
///
/// Toda animación pasa por [ManiMotion.duracion], que devuelve cero cuando el
/// sistema pide reducir movimiento (`MediaQuery.disableAnimations`).
abstract final class ManiMotion {
  /// Retroalimentación inmediata: presionar, hover.
  static const Duration fast = Duration(milliseconds: 120);

  /// Cambios de estado y aparición de contenido.
  static const Duration base = Duration(milliseconds: 200);

  /// Transiciones de ruta y paneles.
  static const Duration slow = Duration(milliseconds: 320);

  static const Curve entrada = Curves.easeOutCubic;
  static const Curve salida = Curves.easeInCubic;
  static const Curve estandar = Curves.easeInOutCubic;

  /// Desplazamiento vertical (px) con el que entra una pantalla nueva.
  static const double deslizamientoRuta = 8;

  /// [d] o cero si el usuario pidió reducir el movimiento.
  static Duration duracion(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}
