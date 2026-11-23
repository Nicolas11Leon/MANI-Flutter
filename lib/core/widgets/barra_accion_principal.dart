import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Franja fija al pie de un formulario largo con su acción principal (SCRUM-1717, QAS-30).
///
/// En un formulario que se desplaza, el botón de guardar o enviar quedaba al final y bajo el pliegue: el usuario no
/// sabía cuál era la acción principal hasta bajar. Esta franja lo deja siempre a la vista, con el mismo borde superior
/// que [BarraAccionesFlujo], y el contenido se desplaza por encima. Se usa en la ranura `bottomNavigationBar` de un
/// `Scaffold` o como último hijo de una columna, debajo de la zona que se desplaza.
class BarraAccionPrincipal extends StatelessWidget {
  const BarraAccionPrincipal({
    super.key,
    required this.child,
    this.anchoMaximo = 720,
  });

  /// La acción principal (normalmente un `ManiButton` con `expandir: true`) o una fila con su contexto.
  final Widget child;

  /// Ancho máximo del contenido, para que en escritorio quede alineado con el formulario.
  final double anchoMaximo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: context.mani.surface,
        border: Border(top: BorderSide(color: context.mani.ink, width: 2)),
      ),
      child: SafeArea(
        top: false,
        // heightFactor: la franja mide lo que mide su contenido; sin él, en la ranura inferior de un Scaffold el
        // Center ocupa toda la altura y deja el formulario sin espacio.
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: anchoMaximo),
            child: child,
          ),
        ),
      ),
    );
  }
}
