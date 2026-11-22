import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mani/core/theme/app_theme.dart';

/// `enlace` es la acción de menor jerarquía (texto subrayado, sin borde ni
/// sombra): ver u ocultar contraseña, «¿Olvidaste tu contraseña?», reintentar
/// dentro de una fila.
/// `oscuro` (relleno oscuro y texto blanco en los dos modos: va sobre la tarjeta
/// de marca, que es amarilla también en modo oscuro) y `texto` (igual a
/// `enlace`) vienen de la navegación móvil y el inicio de SCRUM-1646/1647.
enum ManiButtonVariante { primario, peligro, secundario, enlace, oscuro, texto }

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
    this.etiquetaAccesible,
    this.colorTexto,
  });

  final String etiqueta;
  final VoidCallback? onPressed;
  final IconData? icono;
  final ManiButtonVariante variante;
  final bool cargando;
  final bool expandir;

  /// Texto para lectores de pantalla cuando la etiqueta visible es corta
  /// (por ejemplo «VER» → «Ver contraseña»).
  final String? etiquetaAccesible;

  /// Color del texto cuando la pantalla necesita otro (por ejemplo, sobre una
  /// franja de color). Si es nulo se usa el de la variante.
  final Color? colorTexto;

  @override
  State<ManiButton> createState() => _ManiButtonState();
}

class _ManiButtonState extends State<ManiButton> {
  bool _presionado = false;
  bool _enfocado = false;
  bool _hover = false;

  bool get _habilitado => widget.onPressed != null && !widget.cargando;

  (Color fondo, Color texto) _colores(ManiTokens t) =>
      switch (widget.variante) {
        ManiButtonVariante.primario => (t.brand, t.onBrand),
        ManiButtonVariante.peligro => (ManiColors.danger, ManiColors.onInk),
        ManiButtonVariante.secundario => (t.surface, t.ink),
        ManiButtonVariante.enlace ||
        ManiButtonVariante.texto => (Colors.transparent, t.ink),
        ManiButtonVariante.oscuro => (t.onBrand, ManiColors.onInk),
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
    final t = context.mani;
    if (widget.variante == ManiButtonVariante.enlace ||
        widget.variante == ManiButtonVariante.texto) {
      return _enlace(t);
    }
    final (fondo, textoVariante) = _colores(t);
    final texto = widget.colorTexto ?? textoVariante;
    final hundido = _presionado || !_habilitado;
    final rapido = ManiMotion.duracion(context, ManiMotion.fast);
    final desplazamiento = _desplazamiento(hundido);
    return Semantics(
      button: true,
      enabled: _habilitado,
      label: widget.etiquetaAccesible ?? widget.etiqueta,
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
                desplazamiento,
                desplazamiento,
                0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: ManiSpace.xl,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: fondo,
                borderRadius: ManiRadius.brMd,
                border: Border.all(color: t.border, width: ManiBorder.regular),
                boxShadow: _sombras(t, hundido),
              ),
              child: _contenido(texto),
            ),
          ),
        ),
      ),
    );
  }

  /// Hundido baja a la posición de la sombra; con el cursor encima sube 1 px.
  double _desplazamiento(bool hundido) {
    if (hundido) return ManiShadow.hundimiento;
    return _hover ? -1 : 0;
  }

  List<BoxShadow> _sombras(ManiTokens t, bool hundido) => [
    if (!hundido) _hover ? t.shadow : t.shadowSm,
    // Anillo de foco: un contorno extra fuera de la sombra.
    if (_enfocado) BoxShadow(color: t.border, spreadRadius: 3),
    if (_enfocado) BoxShadow(color: t.brand, spreadRadius: 1.5),
  ];

  /// Indicador de carga o icono, y la etiqueta.
  Widget _contenido(Color texto) {
    final conIcono = widget.cargando || widget.icono != null;
    return Row(
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
        if (conIcono) ManiGap.hSm,
        Flexible(
          child: Text(
            widget.etiqueta,
            style: ManiText.label.copyWith(
              color: texto,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Variante `enlace`: texto subrayado con foco y teclado del botón nativo.
  Widget _enlace(ManiTokens t) {
    return Semantics(
      button: true,
      enabled: _habilitado,
      label: widget.etiquetaAccesible ?? widget.etiqueta,
      excludeSemantics: true,
      child: TextButton(
        onPressed: _habilitado ? widget.onPressed : null,
        style: TextButton.styleFrom(
          foregroundColor: t.ink,
          padding: const EdgeInsets.symmetric(
            horizontal: ManiSpace.sm,
            vertical: ManiSpace.xs,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: Text(
          widget.etiqueta,
          style: ManiText.bodySm.copyWith(
            color: widget.colorTexto ?? t.ink,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
