import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Tono semántico de un estado (servicio, cotización, queja, verificación).
/// Es la única fuente de colores de estado: las insignias de cada módulo
/// eligen un tono en lugar de declarar colores propios.
enum ManiTono {
  neutro(ManiColors.surfaceMuted, ManiColors.ink),
  marca(ManiColors.brandSoft, ManiColors.ink),
  exito(ManiColors.successContainer, ManiColors.successText),
  aviso(ManiColors.warningContainer, ManiColors.warningText),
  peligro(ManiColors.dangerContainer, ManiColors.dangerText),
  info(ManiColors.infoContainer, ManiColors.infoText),
  acento(ManiColors.accentContainer, ManiColors.accent),

  // Tonos de la píldora [ManiEstado] (SCRUM-1646, trabajo de Nicolás).
  enCurso(ManiColors.brandSoft, ManiColors.ink),
  atencion(ManiColors.warningContainer, ManiColors.warningText),
  listo(ManiColors.successContainer, ManiColors.successText),
  mal(ManiColors.dangerContainer, ManiColors.dangerText);

  const ManiTono(this.fondo, this.texto);

  /// Fondo tenue del estado.
  final Color fondo;

  /// Texto e ícono legibles sobre [fondo] (WCAG AA).
  final Color texto;
}

/// Insignia de estado: píldora con borde, ícono y texto en mayúsculas. El
/// ícono acompaña al color para que el estado no dependa solo de él.
/// Píldora de estado sin mayúsculas: un punto y el texto. Es la forma corta
/// de [ManiStatusBadge] que usan las tarjetas de solicitud, cotización y cobro.
class ManiEstado extends StatelessWidget {
  const ManiEstado({
    super.key,
    required this.texto,
    this.tono = ManiTono.neutro,
  });

  final String texto;
  final ManiTono tono;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: tono.fondo,
        borderRadius: ManiRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: tono.texto,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: ManiText.caption.copyWith(
                color: tono.texto,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ManiStatusBadge extends StatelessWidget {
  const ManiStatusBadge({
    super.key,
    required this.etiqueta,
    required this.tono,
    this.icono,
    this.compacto = false,
    this.mayusculas = true,
  });

  final String etiqueta;
  final ManiTono tono;
  final IconData? icono;
  final bool compacto;
  final bool mayusculas;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? ManiSpace.sm : 10,
        vertical: compacto ? ManiSpace.xxs + 1 : ManiSpace.xs + 1,
      ),
      decoration: BoxDecoration(
        color: tono.fondo,
        borderRadius: ManiRadius.brPill,
        border: Border.all(color: t.border, width: ManiBorder.thin),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: compacto ? 12 : 14, color: tono.texto),
            ManiGap.hXs,
          ],
          Flexible(
            child: Text(
              mayusculas ? etiqueta.toUpperCase() : etiqueta,
              overflow: TextOverflow.ellipsis,
              style: ManiText.overline.copyWith(
                fontSize: compacto ? ManiFontSize.nano : ManiFontSize.micro,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: tono.texto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío: ícono en círculo de marca, título, explicación y acciones.
class ManiEstadoVacio extends StatelessWidget {
  const ManiEstadoVacio({
    super.key,
    required this.titulo,
    this.texto,
    this.icono = Icons.inbox_outlined,
    this.acciones = const [],
    this.tituloKey,
  });

  final IconData icono;
  final String titulo;
  final Key? tituloKey;
  final String? texto;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: ManiSpace.huge,
        horizontal: ManiSpace.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.all(ManiSpace.lg),
              decoration: BoxDecoration(
                color: t.brand,
                shape: BoxShape.circle,
                border: Border.all(color: t.border, width: ManiBorder.regular),
                boxShadow: [t.shadowSm],
              ),
              child: Icon(icono, size: 32, color: t.onBrand),
            ),
          ),
          ManiGap.vLg,
          Text(
            titulo,
            key: tituloKey,
            textAlign: TextAlign.center,
            style: ManiText.title.copyWith(color: t.ink),
          ),
          if (texto != null) ...[
            ManiGap.vSm,
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                texto!,
                textAlign: TextAlign.center,
                style: ManiText.body.copyWith(color: t.inkMuted),
              ),
            ),
          ],
          if (acciones.isNotEmpty) ...[
            ManiGap.vXl,
            Wrap(
              spacing: ManiSpace.md,
              runSpacing: ManiSpace.md,
              alignment: WrapAlignment.center,
              children: acciones,
            ),
          ],
        ],
      ),
    );
  }
}

/// Error recuperable: tarjeta roja tenue con el mensaje y "Reintentar".
class ManiEstadoError extends StatelessWidget {
  const ManiEstadoError({
    super.key,
    required this.mensaje,
    this.onReintentar,
    this.etiquetaReintentar = 'Reintentar',
    this.botonKey,
  });

  final String mensaje;
  final VoidCallback? onReintentar;
  final String etiquetaReintentar;
  final Key? botonKey;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ManiSpace.lg,
          vertical: ManiSpace.md,
        ),
        decoration: maniDecoracion(
          color: ManiColors.dangerContainer,
          borde: t.border,
          sombra: t.shadowSm,
          radio: ManiRadius.brMd,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: ManiColors.dangerText,
            ),
            ManiGap.hMd,
            Expanded(
              child: Text(
                mensaje,
                style: ManiText.body.copyWith(
                  color: ManiColors.dangerText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onReintentar != null) ...[
              ManiGap.hSm,
              TextButton.icon(
                key: botonKey,
                onPressed: onReintentar,
                style: TextButton.styleFrom(
                  foregroundColor: ManiColors.dangerText,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(etiquetaReintentar),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Indicador de carga centrado, anunciado a lectores de pantalla.
class ManiCargando extends StatelessWidget {
  const ManiCargando({super.key, this.mensaje, this.padding});

  final String? mensaje;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return Semantics(
      label: mensaje ?? 'Cargando',
      liveRegion: true,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(ManiSpace.xxl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 3, color: t.ink),
              ),
              if (mensaje != null) ...[
                ManiGap.vMd,
                Text(
                  mensaje!,
                  style: ManiText.bodySm.copyWith(color: t.inkMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bloque de esqueleto que late suavemente mientras llega el contenido. Con
/// movimiento reducido queda estático.
class ManiSkeleton extends StatefulWidget {
  const ManiSkeleton({
    super.key,
    this.ancho = double.infinity,
    this.alto = 14,
    this.radio = ManiRadius.brSm,
  });

  final double ancho;
  final double alto;
  final BorderRadius radio;

  @override
  State<ManiSkeleton> createState() => _ManiSkeletonState();
}

class _ManiSkeletonState extends State<ManiSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducir = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reducir) {
      _c.stop();
      _c.value = 0.7;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: _c,
        child: Container(
          width: widget.ancho,
          height: widget.alto,
          decoration: BoxDecoration(
            color: t.borderSubtle,
            borderRadius: widget.radio,
          ),
        ),
      ),
    );
  }
}

/// Lista de tarjetas esqueleto con la forma de una tarjeta de servicio.
class ManiSkeletonLista extends StatelessWidget {
  const ManiSkeletonLista({super.key, this.cantidad = 3});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return Semantics(
      label: 'Cargando',
      liveRegion: true,
      child: Column(
        children: [
          for (var i = 0; i < cantidad; i++) ...[
            Container(
              padding: const EdgeInsets.all(ManiSpace.lg),
              decoration: maniDecoracion(
                color: t.surface,
                borde: t.border,
                sombra: null,
              ),
              child: const Row(
                children: [
                  ManiSkeleton(ancho: 44, alto: 44, radio: ManiRadius.brMd),
                  SizedBox(width: ManiSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ManiSkeleton(ancho: 180, alto: 14),
                        SizedBox(height: ManiSpace.sm),
                        ManiSkeleton(alto: 10),
                        SizedBox(height: ManiSpace.xs),
                        ManiSkeleton(ancho: 120, alto: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i < cantidad - 1) ManiGap.vMd,
          ],
        ],
      ),
    );
  }
}

/// Cambio animado entre estados de una vista (cargando → contenido → error):
/// funde y desliza 8 px hacia arriba el contenido nuevo. Cada estado debe
/// tener una `key` distinta para que la transición se dispare.
class ManiTransicionEstado extends StatelessWidget {
  const ManiTransicionEstado({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: ManiMotion.duracion(context, ManiMotion.base),
      switchInCurve: ManiMotion.entrada,
      switchOutCurve: ManiMotion.salida,
      layoutBuilder: (actual, previos) => Stack(
        alignment: Alignment.topCenter,
        children: [...previos, ?actual],
      ),
      transitionBuilder: (child, animacion) => FadeTransition(
        opacity: animacion,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animacion),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Sección de formulario o de detalle: tarjeta con título, descripción
/// opcional y acción a la derecha.
class ManiSeccion extends StatelessWidget {
  const ManiSeccion({
    super.key,
    required this.titulo,
    required this.child,
    this.icono,
    this.descripcion,
    this.accion,
  });

  final String titulo;
  final IconData? icono;
  final String? descripcion;
  final Widget? accion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return Container(
      padding: const EdgeInsets.all(ManiSpace.xl),
      decoration: maniDecoracion(
        color: t.surface,
        borde: t.border,
        sombra: t.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icono != null) ...[
                Icon(icono, size: 20, color: t.ink),
                ManiGap.hSm,
              ],
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    titulo,
                    style: ManiText.subtitle.copyWith(color: t.ink),
                  ),
                ),
              ),
              ?accion,
            ],
          ),
          if (descripcion != null) ...[
            ManiGap.vXs,
            Text(
              descripcion!,
              style: ManiText.bodySm.copyWith(color: t.inkMuted),
            ),
          ],
          ManiGap.vLg,
          child,
        ],
      ),
    );
  }
}

/// Diálogo de confirmación estándar. Devuelve `true` si el usuario confirma.
/// Con [destructiva], el botón de confirmar es rojo.
Future<bool> mostrarManiConfirmacion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String confirmar = 'Confirmar',
  String cancelar = 'Cancelar',
  bool destructiva = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelar),
        ),
        FilledButton(
          style: destructiva
              ? FilledButton.styleFrom(
                  backgroundColor: ManiColors.danger,
                  foregroundColor: ManiColors.onInk,
                )
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmar),
        ),
      ],
    ),
  );
  return r ?? false;
}
