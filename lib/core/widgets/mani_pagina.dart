import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_card.dart';

/// Ancho máximo del contenido de una página con sesión en escritorio.
const anchoMaximoPagina = 1400.0;

/// Página con sesión en el estilo de MANI: márgenes de escritorio, contenido
/// centrado hasta [anchoMaximoPagina] y scroll que construye todo (las
/// secciones existen aunque queden fuera de vista). Con [alRefrescar], se
/// recarga al deslizar hacia abajo.
class ManiPagina extends StatelessWidget {
  const ManiPagina({
    super.key,
    required this.children,
    this.alRefrescar,
    this.ancho = anchoMaximoPagina,
  });

  final List<Widget> children;
  final Future<void> Function()? alRefrescar;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    final contenido = LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: c.maxWidth >= 600 ? 32 : 16,
          vertical: ManiSpace.xxl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ancho),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
    if (alRefrescar == null) return contenido;
    return RefreshIndicator(
      color: ManiColors.ink,
      backgroundColor: ManiColors.brand,
      onRefresh: alRefrescar!,
      child: contenido,
    );
  }
}

/// Encabezado de página: tarjeta con el ícono en caja amarilla, título y
/// descripción, y una acción opcional a la derecha (debajo en móvil). Es el
/// mismo de la pantalla del servicio.
class ManiEncabezadoPagina extends StatelessWidget {
  const ManiEncabezadoPagina({
    super.key,
    required this.icono,
    required this.titulo,
    this.descripcion,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? descripcion;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final texto = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(ManiSpace.sm),
          decoration: BoxDecoration(
            color: ManiColors.brand,
            borderRadius: ManiRadius.brMd,
            border: Border.all(
              color: ManiColors.border,
              width: ManiBorder.regular,
            ),
            boxShadow: const [ManiShadow.sm],
          ),
          child: Icon(icono, color: ManiColors.ink, size: 24),
        ),
        ManiGap.hMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: ManiFontSize.h3,
                  fontWeight: FontWeight.w900,
                  color: ManiColors.ink,
                ),
              ),
              if (descripcion != null) ...[
                ManiGap.vXs,
                Text(
                  descripcion!,
                  style: const TextStyle(
                    fontSize: ManiFontSize.bodySm,
                    fontWeight: FontWeight.w600,
                    color: ManiColors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return ManiCard(
      padding: const EdgeInsets.all(ManiSpace.xl),
      child: LayoutBuilder(
        builder: (context, c) {
          if (accion == null) return texto;
          if (c.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [texto, ManiGap.vMd, accion!],
            );
          }
          return Row(
            children: [
              Expanded(child: texto),
              ManiGap.hLg,
              accion!,
            ],
          );
        },
      ),
    );
  }
}

/// Título de sección: ícono en caja amarilla, texto en mayúsculas y subrayado
/// negro. Separa los bloques de una página (y las columnas del servicio).
class ManiTituloSeccion extends StatelessWidget {
  const ManiTituloSeccion({
    super.key,
    required this.icono,
    required this.titulo,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: ManiSpace.sm),
      decoration: const BoxDecoration(border: Border(bottom: ManiBorder.side)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(ManiSpace.sm),
            decoration: BoxDecoration(
              color: ManiColors.brand,
              borderRadius: ManiRadius.brSm,
              border: Border.all(
                color: ManiColors.border,
                width: ManiBorder.regular,
              ),
            ),
            child: Icon(icono, color: ManiColors.ink, size: 18),
          ),
          ManiGap.hSm,
          Expanded(
            child: Text(
              titulo.toUpperCase(),
              style: const TextStyle(
                fontSize: ManiFontSize.bodySm,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                color: ManiColors.ink,
              ),
            ),
          ),
          ?accion,
        ],
      ),
    );
  }
}

/// Reparte las tarjetas en columnas de igual ancho: tantas como quepan con
/// [anchoMinimo] cada una, hasta [maxColumnas]; una sola en móvil.
class ManiRejilla extends StatelessWidget {
  const ManiRejilla({
    super.key,
    required this.children,
    this.anchoMinimo = 320,
    this.maxColumnas = 3,
    this.espacio = 16,
  });

  final List<Widget> children;
  final double anchoMinimo;
  final int maxColumnas;
  final double espacio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = (c.maxWidth / anchoMinimo).floor().clamp(
          1,
          maxColumnas,
        );
        final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final h in children) SizedBox(width: ancho, child: h),
          ],
        );
      },
    );
  }
}

/// Botón en píldora con borde negro: amarillo con sombra si es [principal],
/// blanco si no. Es el de las acciones de Mis solicitudes; el texto oscuro
/// sobre amarillo o blanco cumple el contraste AA.
class ManiBotonPildora extends StatelessWidget {
  const ManiBotonPildora({
    super.key,
    required this.etiqueta,
    required this.onPressed,
    this.icono,
    this.principal = false,
  });

  final String etiqueta;
  final VoidCallback? onPressed;
  final IconData? icono;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final estilo = TextButton.styleFrom(
      foregroundColor: ManiColors.ink,
      textStyle: const TextStyle(
        fontSize: ManiFontSize.bodySm,
        fontWeight: FontWeight.w800,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.md,
        vertical: ManiSpace.sm,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: principal ? ManiColors.brand : ManiColors.surface,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
        boxShadow: const [ManiShadow.sm],
      ),
      child: icono == null
          ? TextButton(
              onPressed: onPressed,
              style: estilo,
              child: Text(etiqueta),
            )
          : TextButton.icon(
              onPressed: onPressed,
              style: estilo,
              icon: Icon(icono, size: 18),
              label: Text(etiqueta),
            ),
    );
  }
}

/// Estado vacío o de error dentro de una página: tarjeta con ícono y texto,
/// y una acción opcional (p. ej. «Reintentar»).
class ManiAvisoTarjeta extends StatelessWidget {
  const ManiAvisoTarjeta({
    super.key,
    required this.icono,
    required this.texto,
    this.accion,
    this.esError = false,
  });

  final IconData icono;
  final String texto;
  final Widget? accion;
  final bool esError;

  @override
  Widget build(BuildContext context) {
    return ManiCard(
      color: esError ? ManiColors.dangerContainer : ManiColors.surface,
      sombra: ManiShadow.sm,
      child: Row(
        children: [
          Icon(icono, color: esError ? ManiColors.dangerText : ManiColors.ink),
          ManiGap.hMd,
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: ManiColors.ink,
              ),
            ),
          ),
          if (accion != null) ...[ManiGap.hMd, accion!],
        ],
      ),
    );
  }
}
