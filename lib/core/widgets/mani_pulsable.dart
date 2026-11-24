import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Área pulsable accesible para controles con diseño propio (tarjetas de
/// opción, botones neo-brutalistas hechos con `Container`).
///
/// Reemplaza a un `GestureDetector(onTap:)` desnudo: además del toque, se
/// alcanza con Tab, se activa con Enter o Espacio, anuncia "botón" a los
/// lectores de pantalla, muestra el cursor de mano y dibuja un anillo de foco
/// alrededor de [child] cuando se navega con teclado.
class ManiPulsable extends StatefulWidget {
  const ManiPulsable({
    super.key,
    required this.onTap,
    required this.child,
    this.behavior,
    this.radio = ManiRadius.brMd,
    this.etiqueta,
  });

  final VoidCallback? onTap;
  final Widget child;
  final HitTestBehavior? behavior;

  /// Radio del anillo de foco; debería coincidir con el de [child].
  final BorderRadius radio;

  /// Etiqueta para lectores de pantalla cuando [child] no tiene texto.
  final String? etiqueta;

  @override
  State<ManiPulsable> createState() => _ManiPulsableState();
}

class _ManiPulsableState extends State<ManiPulsable> {
  bool _foco = false;

  @override
  Widget build(BuildContext context) {
    final habilitado = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: habilitado,
      label: widget.etiqueta,
      child: FocusableActionDetector(
        enabled: habilitado,
        mouseCursor: habilitado
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (v) => setState(() => _foco = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: widget.behavior,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: widget.radio,
              border: _foco
                  ? Border.all(
                      color: ManiColors.focus,
                      width: 3,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    )
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
