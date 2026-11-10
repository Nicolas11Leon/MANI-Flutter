import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Tarjeta neo-brutalista MANI: borde negro, esquinas redondeadas y sombra
/// dura. Si [seleccionada], resalta con fondo amarillo tenue y sombra mayor.
///
/// Con [onTap] es interactiva: en web se eleva al pasar el mouse (la sombra
/// crece y la tarjeta sube 1 px, sin mover el layout) y muestra un anillo de
/// foco al recorrerla con el teclado.
class ManiCard extends StatefulWidget {
  const ManiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ManiSpace.lg),
    this.color = ManiColors.surface,
    this.seleccionada = false,
    this.onTap,
    this.sombra = ManiShadow.md,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool seleccionada;
  final VoidCallback? onTap;
  final BoxShadow? sombra;

  static const Color colorSeleccion = ManiColors.brandSoft;

  @override
  State<ManiCard> createState() => _ManiCardState();
}

class _ManiCardState extends State<ManiCard> {
  bool _hover = false;
  bool _foco = false;

  @override
  Widget build(BuildContext context) {
    final interactiva = widget.onTap != null;
    final elevada = interactiva && _hover && !widget.seleccionada;
    final sombra = widget.sombra == null
        ? null
        : widget.seleccionada || elevada
        ? ManiShadow.lg
        : widget.sombra!;

    return AnimatedContainer(
      duration: ManiMotion.duracion(context, ManiMotion.fast),
      curve: ManiMotion.entrada,
      transform: Matrix4.translationValues(
        elevada ? -1 : 0,
        elevada ? -1 : 0,
        0,
      ),
      decoration: BoxDecoration(
        color: widget.seleccionada ? ManiCard.colorSeleccion : widget.color,
        borderRadius: ManiRadius.brLg,
        border: Border.all(
          color: ManiColors.border,
          width: _foco ? ManiBorder.thick + 0.5 : ManiBorder.regular,
        ),
        boxShadow: [?sombra],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHover: interactiva ? (v) => setState(() => _hover = v) : null,
          onFocusChange: interactiva ? (v) => setState(() => _foco = v) : null,
          borderRadius: ManiRadius.brLg,
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}
