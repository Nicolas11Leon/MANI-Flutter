import 'package:flutter/material.dart';

/// Transición al cambiar de pantalla (SCRUM-1646 / SCRUM-1647): un desvanecimiento «a través», sin zoom ni
/// superposición.
///
/// La que trae Material por defecto hace entrar la pantalla nueva encima de la vieja y deja ver las dos a la vez durante
/// unos 300 ms, lo que se siente lento y pesado. Aquí la pantalla que sale se desvanece en el primer cuarto, y la que
/// entra aparece después con un desplazamiento leve hacia arriba, de modo que casi nunca se ven juntas. Cumple lo que
/// pide la propuesta de UX: desvanecimiento y desplazamiento leve en 150 a 250 ms.
///
/// Se aplica a todas las pantallas desde `AppTheme.light` (`pageTransitionsTheme`); funciona igual con `go` y con `push`,
/// y al volver atrás la animación va en sentido inverso.
class TransicionDePantalla extends PageTransitionsBuilder {
  const TransicionDePantalla();

  /// Tramo de la animación en que la pantalla que sale se desvanece.
  static const _salida = Interval(0, 0.25, curve: Curves.easeIn);

  /// Tramo en que la pantalla que entra aparece y sube. Empieza cuando la otra ya casi no se ve.
  static const _entrada = Interval(0.25, 0.8, curve: Curves.easeOut);

  /// Desplazamiento inicial de la pantalla que entra, como fracción de su alto: apenas perceptible.
  static const _desplazamiento = Offset(0, 0.015);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final entra = CurvedAnimation(parent: animation, curve: _entrada);
    // La pantalla que queda debajo (otra se abre encima) se desvanece al comienzo; al volver, reaparece al final.
    final cede = ReverseAnimation(
      CurvedAnimation(parent: secondaryAnimation, curve: _salida),
    );

    return FadeTransition(
      opacity: cede,
      child: FadeTransition(
        opacity: entra,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: _desplazamiento,
            end: Offset.zero,
          ).animate(entra),
          child: child,
        ),
      ),
    );
  }
}

/// La misma transición para todas las plataformas: lo que se siente fluido en el celular debe sentirse igual en la web.
const pageTransitionsDeMani = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: TransicionDePantalla(),
    TargetPlatform.iOS: TransicionDePantalla(),
    TargetPlatform.linux: TransicionDePantalla(),
    TargetPlatform.macOS: TransicionDePantalla(),
    TargetPlatform.windows: TransicionDePantalla(),
    TargetPlatform.fuchsia: TransicionDePantalla(),
  },
);
