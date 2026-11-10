import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mani/core/theme/app_theme.dart';

enum ManiButtonVariante { primario, peligro, secundario }

/// Botón neo-brutalista MANI. Al presionarlo "se hunde": la sombra dura
/// desaparece y el botón se desplaza a su lugar, como un botón físico. El
/// hundimiento es una transformación, así que no mueve el layout vecino.
///
/// Es alcanzable con teclado (Tab), se activa con Enter o Espacio y muestra
/// un anillo de foco visible.
class ManiButton extends StatefulWidget {
  const ManiButton({
    super.key,
    required this.etiqueta,
    required this.onPressed,
    this.icono,
    this.variante = ManiButtonVariante.primario,
    this.cargando = false,
    this.expandir = false,
  });

  final String etiqueta;
  final VoidCallback? onPressed;
  final IconData? icono;
  final ManiButtonVariante variante;
  final bool cargando;
  final bool expandir;

  @override
  State<ManiButton> createState() => _ManiButtonState();
}

class _ManiButtonState extends State<ManiButton> {
  bool _presionado = false;
  bool _enfocado = false;
  bool _hover = false;

  bool get _habilitado => widget.onPressed != null && !widget.cargando;

  (Color fondo, Color texto) get _colores => switch (widget.variante) {
    ManiButtonVariante.primario => (ManiColors.brand, ManiColors.onBrand),
    ManiButtonVariante.peligro => (ManiColors.danger, ManiColors.onInk),
    ManiButtonVariante.secundario => (ManiColors.surface, ManiColors.ink),
  };

  void _presionar(bool valor) {
    if (_habilitado && _presionado != valor) {
      setState(() => _presionado = valor);
    }
  }

  void _activar() {
    if (_habilitado) widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final (fondo, texto) = _colores;
    final hundido = _presionado || !_habilitado;
    final rapido = ManiMotion.duracion(context, ManiMotion.fast);
    final estilo = ManiText.label.copyWith(
      color: texto,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.3,
    );

    final contenido = Row(
      mainAxisSize: widget.expandir ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.cargando)
          SizedBox.square(
            dimension: ManiSpace.lg,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: texto),
          )
        else if (widget.icono != null)
          Icon(widget.icono, size: 18, color: texto),
        if (widget.cargando || widget.icono != null) ManiGap.hSm,
        Flexible(
          child: Text(
            widget.etiqueta,
            style: estilo,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    const d = ManiShadow.hundimiento;
    return Semantics(
      button: true,
      enabled: _habilitado,
      label: widget.etiqueta,
      onTap: _habilitado ? widget.onPressed : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _habilitado,
        mouseCursor: _habilitado
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        onShowFocusHighlight: (v) => setState(() => _enfocado = v),
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activar();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTapDown: (_) => _presionar(true),
          onTapUp: (_) => _presionar(false),
          onTapCancel: () => _presionar(false),
          onTap: _habilitado ? widget.onPressed : null,
          child: AnimatedOpacity(
            duration: rapido,
            opacity: _habilitado || widget.cargando ? 1 : 0.45,
            child: AnimatedContainer(
              duration: rapido,
              curve: ManiMotion.entrada,
              transform: Matrix4.translationValues(
                hundido ? d : (_hover ? -1 : 0),
                hundido ? d : (_hover ? -1 : 0),
                0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: ManiSpace.xl,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: fondo,
                borderRadius: ManiRadius.brMd,
                border: Border.all(
                  color: ManiColors.border,
                  width: ManiBorder.regular,
                ),
                boxShadow: [
                  if (!hundido) _hover ? ManiShadow.md : ManiShadow.sm,
                  // Anillo de foco: un contorno extra fuera de la sombra.
                  if (_enfocado)
                    const BoxShadow(color: ManiColors.focus, spreadRadius: 3),
                  if (_enfocado)
                    const BoxShadow(color: ManiColors.brand, spreadRadius: 1.5),
                ],
              ),
              child: contenido,
            ),
          ),
        ),
      ),
    );
  }
}
