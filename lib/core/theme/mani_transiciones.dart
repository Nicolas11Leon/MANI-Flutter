import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:mani/core/theme/tokens/mani_motion.dart';

/// Transición de ruta de MANI: la pantalla nueva funde y sube
/// [ManiMotion.deslizamientoRuta] px; la anterior se desvanece un poco. Solo
/// usa opacidad y transformación (sin reflujo de layout). Con movimiento
/// reducido, el cambio es inmediato.
class ManiPageTransitionsBuilder extends PageTransitionsBuilder {
  const ManiPageTransitionsBuilder();

  @override
  Duration get transitionDuration => ManiMotion.slow;

  @override
  Duration get reverseTransitionDuration => ManiMotion.base;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final entrada = CurvedAnimation(
      parent: animation,
      curve: ManiMotion.entrada,
      reverseCurve: ManiMotion.salida,
    );
    final salida = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: ManiMotion.estandar),
    );
    return FadeTransition(
      opacity: salida,
      child: FadeTransition(
        opacity: entrada,
        child: AnimatedBuilder(
          animation: entrada,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              0,
              (1 - entrada.value) * ManiMotion.deslizamientoRuta,
            ),
            child: child,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Builder de MANI en web, Android y escritorio. iOS conserva la transición
/// de Cupertino para no perder el gesto nativo de deslizar para volver.
const maniPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: ManiPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: ManiPageTransitionsBuilder(),
    TargetPlatform.linux: ManiPageTransitionsBuilder(),
    TargetPlatform.fuchsia: ManiPageTransitionsBuilder(),
  },
);
