import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Anillo de foco visible para quien navega con el teclado (SCRUM-1647, WCAG 2.2 AA «Foco visible»).
///
/// Los `InkWell` y los `IconButton` solo pintan un velo gris tenue al recibir el foco, que casi no se distingue sobre
/// el crema o el blanco. Este envoltorio dibuja un anillo de 3 px con la tinta del tema (contraste muy por encima de
/// 3:1 en claro y en oscuro) alrededor de lo que esté dentro **mientras un control suyo tiene el foco**, y solo cuando
/// el foco viene del teclado: un toque o un clic del ratón no lo muestran.
///
/// Uso: `ManiAnilloFoco(child: InkWell(onTap: ..., child: ...))`. No agrega nada al recorrido con Tab ni a la
/// accesibilidad: solo escucha el foco de sus descendientes.
class ManiAnilloFoco extends StatefulWidget {
  const ManiAnilloFoco({
    super.key,
    required this.child,
    this.radio = ManiRadius.brMd,
  });

  final Widget child;

  /// Esquinas del anillo; igual a las del control que envuelve.
  final BorderRadius radio;

  /// Grosor del anillo.
  static const double grosor = 3;

  @override
  State<ManiAnilloFoco> createState() => _ManiAnilloFocoState();
}

class _ManiAnilloFocoState extends State<ManiAnilloFoco> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_alCambiarModo);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_alCambiarModo);
    super.dispose();
  }

  // Un toque pasa el modo a «táctil» y el anillo debe apagarse aunque el foco siga donde estaba.
  void _alCambiarModo(FocusHighlightMode _) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      // El Builder depende del nodo: se reconstruye cada vez que un descendiente gana o pierde el foco.
      child: Builder(
        builder: (context) {
          final visible =
              Focus.of(context).hasFocus &&
              FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional;
          return DecoratedBox(
            // La clave es fija: si cambiara al aparecer el anillo, Flutter recrearía el control y le quitaría el foco.
            key: const Key('anillo-foco'),
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: widget.radio,
              border: visible
                  ? Border.all(color: t.ink, width: ManiAnilloFoco.grosor)
                  : null,
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}
