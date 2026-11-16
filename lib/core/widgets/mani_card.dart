import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Cuánto se destaca una tarjeta. Solo lo protagonista lleva sombra dura.
enum ManiEnfasis {
  /// Lo que la pantalla quiere que se vea primero: borde de 2.5 y sombra dura.
  protagonista,

  /// Tarjeta de trabajo (listas, formularios): borde fino y sin sombra.
  trabajo,

  /// Agrupa sin marcar: sin borde ni sombra.
  plano,
}

/// Tarjeta MANI. Según el [enfasis] lleva más o menos borde y sombra. Si
/// [seleccionada], resalta con fondo amarillo tenue y borde grueso.
class ManiCard extends StatefulWidget {
  const ManiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppTheme.surface,
    this.seleccionada = false,
    this.onTap,
    this.enfasis = ManiEnfasis.trabajo,
    this.sombra,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool seleccionada;
  final VoidCallback? onTap;
  final ManiEnfasis enfasis;

  /// Si viene, manda sobre el [enfasis].
  final BoxShadow? sombra;

  @override
  State<ManiCard> createState() => _ManiCardState();
}

class _ManiCardState extends State<ManiCard> {
  bool _presionada = false;

  void _presionar(bool valor) {
    if (widget.onTap != null && _presionada != valor) {
      setState(() => _presionada = valor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enfasis = widget.enfasis;
    final radio = BorderRadius.circular(switch (enfasis) {
      ManiEnfasis.protagonista => AppTheme.radiusLg,
      ManiEnfasis.trabajo => AppTheme.radiusMd,
      ManiEnfasis.plano => AppTheme.radiusIcon,
    });
    final grosor = widget.seleccionada
        ? AppTheme.borderMedium
        : switch (enfasis) {
            ManiEnfasis.protagonista => AppTheme.borderMedium,
            ManiEnfasis.trabajo => AppTheme.borderThin,
            ManiEnfasis.plano => 0.0,
          };
    final sombra =
        widget.sombra ??
        (enfasis == ManiEnfasis.protagonista ? AppTheme.hardShadowSm : null);
    final fondo = widget.seleccionada
        ? Color.alphaBlend(
            AppTheme.primaryLight.withValues(alpha: 0.4),
            widget.color,
          )
        : (_presionada ? AppTheme.backgroundSoft : widget.color);
    return AnimatedContainer(
      duration: AppTheme.motionFast,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: radio,
        border: grosor == 0
            ? null
            : Border.all(color: AppTheme.dark, width: grosor),
        boxShadow: [?sombra],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: _presionar,
          borderRadius: radio,
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}
