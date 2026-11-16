import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// `primario` es el nivel 1 (amarillo con sombra); `secundario`, `peligro` y `oscuro` son planos; `texto` no lleva
/// fondo ni borde. `oscuro` es el que va sobre amarillo, donde un botón amarillo no se vería.
enum ManiButtonVariante { primario, peligro, secundario, oscuro, texto }

/// Botón neo-brutalista MANI. Al presionarlo "se hunde": la sombra dura
/// desaparece y el botón se desplaza a su posición, como un botón físico.
class ManiButton extends StatefulWidget {
  const ManiButton({
    super.key,
    required this.etiqueta,
    required this.onPressed,
    this.icono,
    this.variante = ManiButtonVariante.primario,
    this.cargando = false,
    this.expandir = false,
    this.colorTexto,
  });

  final String etiqueta;
  final VoidCallback? onPressed;
  final IconData? icono;
  final ManiButtonVariante variante;
  final bool cargando;
  final bool expandir;

  /// Cambia el color del texto y el icono (p. ej. `errorStrong` en una variante `texto` destructiva).
  final Color? colorTexto;

  @override
  State<ManiButton> createState() => _ManiButtonState();
}

class _ManiButtonState extends State<ManiButton> {
  bool _presionado = false;
  bool _sobre = false;

  bool get _habilitado => widget.onPressed != null && !widget.cargando;

  (Color fondo, Color texto) get _colores => switch (widget.variante) {
    ManiButtonVariante.primario => (AppTheme.primary, AppTheme.dark),
    ManiButtonVariante.peligro => (AppTheme.errorStrong, Colors.white),
    ManiButtonVariante.secundario => (AppTheme.surface, AppTheme.dark),
    ManiButtonVariante.oscuro => (AppTheme.dark, Colors.white),
    ManiButtonVariante.texto => (Colors.transparent, AppTheme.dark),
  };

  bool get _conRelieve => widget.variante == ManiButtonVariante.primario;

  /// El secundario y el de texto se marcan al presionar con el crema suave.
  Color _sobreFondo(Color fondo) {
    if (!_presionado || !_habilitado) return fondo;
    return switch (widget.variante) {
      ManiButtonVariante.secundario ||
      ManiButtonVariante.texto => AppTheme.backgroundSoft,
      _ => fondo,
    };
  }

  void _presionar(bool valor) {
    if (_habilitado && _presionado != valor) {
      setState(() => _presionado = valor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (fondo, textoBase) = _colores;
    final texto = widget.colorTexto ?? textoBase;
    final hundido = _conRelieve && (_presionado || !_habilitado);
    final estilo = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: texto,
      fontSize: 14,
      fontWeight: FontWeight.w800,
      decoration: widget.variante == ManiButtonVariante.texto && _sobre
          ? TextDecoration.underline
          : null,
      decorationColor: texto,
    );

    final contenido = Row(
      mainAxisSize: widget.expandir ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.cargando)
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: texto),
          )
        else if (widget.icono != null)
          Icon(widget.icono, size: 18, color: texto),
        if (widget.cargando || widget.icono != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.etiqueta,
            style: estilo,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _habilitado,
      label: widget.etiqueta,
      onTap: _habilitado ? widget.onPressed : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _presionar(true),
        onTapUp: (_) => _presionar(false),
        onTapCancel: () => _presionar(false),
        onTap: _habilitado ? widget.onPressed : null,
        child: MouseRegion(
          onEnter: (_) => setState(() => _sobre = true),
          onExit: (_) => setState(() => _sobre = false),
          cursor: _habilitado
              ? SystemMouseCursors.click
              : SystemMouseCursors.forbidden,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: _habilitado || widget.cargando ? 1 : 0.45,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              transform: Matrix4.translationValues(
                hundido ? 3 : 0,
                hundido ? 3 : 0,
                0,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: widget.variante == ManiButtonVariante.texto
                    ? 8
                    : 20,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: _sobreFondo(fondo),
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                border: switch (widget.variante) {
                  ManiButtonVariante.primario => Border.all(
                    color: AppTheme.dark,
                    width: 2,
                  ),
                  ManiButtonVariante.secundario => Border.all(
                    color: AppTheme.dark,
                    width: AppTheme.borderThin,
                  ),
                  _ => null,
                },
                boxShadow: [if (_conRelieve && !hundido) AppTheme.hardShadowSm],
              ),
              // 24 de contenido + 12 + 12 de relleno = 48 px de alto mínimo.
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 24),
                child: contenido,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
