import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Ancho máximo del contenido en escritorio, el mismo de las pantallas de
/// registro: así todas las pantallas comparten columna y márgenes.
const anchoMaximoContenido = 1200.0;

/// Ancho a partir del cual las pantallas usan dos columnas, como el registro.
const anchoEscritorio = 850.0;

/// Centra el contenido con el ancho máximo y los márgenes del registro.
class ManiContenido extends StatelessWidget {
  const ManiContenido({super.key, required this.child, this.ancho});

  final Widget child;

  /// Ancho máximo propio, para formularios más angostos que la página.
  final double? ancho;

  static EdgeInsets margenes(double anchoPantalla) => anchoPantalla >= 600
      ? const EdgeInsets.symmetric(
          horizontal: ManiSpace.paginaAncha,
          vertical: ManiSpace.xxl,
        )
      : const EdgeInsets.all(ManiSpace.lg);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: ancho ?? anchoMaximoContenido),
        child: child,
      ),
    );
  }
}

/// Banner de cabecera de una pantalla: ícono en caja amarilla, título y
/// descripción en tarjeta blanca con borde y sombra dura (registro).
class ManiEncabezado extends StatelessWidget {
  const ManiEncabezado({
    super.key,
    required this.icono,
    required this.titulo,
    this.descripcion,
    this.tituloKey,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? descripcion;
  final Key? tituloKey;

  /// Botón opcional a la derecha (en móvil pasa debajo del texto).
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, key: tituloKey, style: ManiText.h3),
        if (descripcion != null) ...[
          ManiGap.vXs,
          Text(descripcion!, style: ManiText.bodySm),
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.xxl,
        vertical: ManiSpace.lg,
      ),
      decoration: maniCaja(),
      child: LayoutBuilder(
        builder: (context, c) {
          final cabecera = Row(
            children: [
              ManiIconoCaja(icono: icono),
              ManiGap.hLg,
              Expanded(child: texto),
            ],
          );
          if (accion == null) return cabecera;
          if (c.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [cabecera, ManiGap.vLg, accion!],
            );
          }
          return Row(
            children: [
              Expanded(child: cabecera),
              ManiGap.hLg,
              accion!,
            ],
          );
        },
      ),
    );
  }
}

/// Ícono sobre caja amarilla con borde, como en las tarjetas del registro.
class ManiIconoCaja extends StatelessWidget {
  const ManiIconoCaja({
    super.key,
    required this.icono,
    this.tamano = 26,
    this.color = ManiColors.brand,
  });

  final IconData icono;
  final double tamano;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(tamano >= 24 ? ManiSpace.md : ManiSpace.sm),
      decoration: BoxDecoration(
        color: color,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
      ),
      child: Icon(icono, color: ManiColors.ink, size: tamano),
    );
  }
}

/// Título de una tarjeta de sección ("1. Datos del Cliente" en el registro).
class ManiTituloSeccion extends StatelessWidget {
  const ManiTituloSeccion({
    super.key,
    required this.icono,
    required this.texto,
  });

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, color: ManiColors.ink, size: 20),
        ManiGap.hSm,
        Expanded(
          child: Text(
            texto,
            style: ManiText.subtitle.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

/// Etiqueta en mayúsculas sobre cada campo ("CORREO ELECTRÓNICO").
class ManiEtiquetaCampo extends StatelessWidget {
  const ManiEtiquetaCampo(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ManiSpace.sm),
      child: Text(texto.toUpperCase(), style: ManiText.overline),
    );
  }
}

/// Decoración de tarjeta del registro: blanco, borde de 2 px y sombra dura.
/// Alias de [maniDecoracion] con la firma que ya usan las pantallas.
BoxDecoration maniCaja({
  Color color = ManiColors.surface,
  BoxShadow sombra = ManiShadow.md,
}) => maniDecoracion(color: color, sombra: sombra);
