import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_card.dart';

/// Ancho máximo del contenido de una página con sesión en escritorio.
const anchoMaximoPagina = ManiAncho.pagina;

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
    this.encabezado,
  });

  final List<Widget> children;
  final Future<void> Function()? alRefrescar;
  final double ancho;

  /// Encabezado fijo sobre el contenido (normalmente un
  /// [ManiEncabezadoPantalla]); no se desplaza con el scroll.
  final Widget? encabezado;

  @override
  Widget build(BuildContext context) {
    final contenido = LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: c.maxWidth >= 600 ? ManiSpace.xxxl : ManiSpace.lg,
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
    final cuerpo = alRefrescar == null
        ? contenido
        : RefreshIndicator(
            color: ManiColors.ink,
            backgroundColor: ManiColors.brand,
            onRefresh: alRefrescar!,
            child: contenido,
          );
    if (encabezado == null) return cuerpo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        encabezado!,
        Expanded(child: cuerpo),
      ],
    );
  }
}

/// Encabezado de una pantalla con sesión: abre el área de trabajo, debajo de
/// la barra superior única, alineado con la columna del contenido ([ancho]).
///
/// Ícono en caja de marca, título, descripción opcional y acciones a la
/// derecha. Por debajo de 600 px las acciones pasan a una segunda fila para
/// que el título nunca se aplaste. Si la pantalla se abrió encima de otra,
/// muestra la flecha para volver.
class ManiEncabezadoPantalla extends StatelessWidget {
  const ManiEncabezadoPantalla({
    super.key,
    required this.icono,
    required this.titulo,
    this.descripcion,
    this.acciones = const [],
    this.ancho = ManiAncho.pagina,
    this.tituloKey,
    this.descripcionKey,
  });

  final IconData icono;
  final String titulo;
  final String? descripcion;
  final List<Widget> acciones;

  /// Ancho de la columna de contenido de la pantalla ([ManiAncho]), para que
  /// el título quede alineado con lo que encabeza.
  final double ancho;
  final Key? tituloKey;
  final Key? descripcionKey;

  @override
  Widget build(BuildContext context) {
    final puedeVolver = ModalRoute.of(context)?.canPop ?? false;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: ancho),
        child: LayoutBuilder(
          builder: (context, c) {
            final angosta = c.maxWidth < 600;
            final identidad = Row(
              children: [
                if (puedeVolver) ...[
                  IconButton(
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  ManiGap.hXs,
                ],
                ExcludeSemantics(
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ManiColors.brand,
                      borderRadius: ManiRadius.brSm,
                      border: Border.all(
                        color: ManiColors.border,
                        width: ManiBorder.regular,
                      ),
                      boxShadow: const [ManiShadow.sm],
                    ),
                    child: Icon(icono, color: ManiColors.onBrand, size: 22),
                  ),
                ),
                ManiGap.hMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          titulo,
                          key: tituloKey,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ManiText.h3,
                        ),
                      ),
                      if (descripcion != null) ...[
                        ManiGap.vXxs,
                        Text(
                          descripcion!,
                          key: descripcionKey,
                          maxLines: angosta ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: ManiText.bodySm,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!angosta && acciones.isNotEmpty) ...[
                  ManiGap.hLg,
                  Wrap(
                    spacing: ManiSpace.sm,
                    runSpacing: ManiSpace.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: acciones,
                  ),
                ],
              ],
            );
            return Padding(
              padding: EdgeInsets.fromLTRB(
                angosta ? ManiSpace.lg : ManiSpace.xxl,
                angosta ? ManiSpace.lg : ManiSpace.xxl,
                angosta ? ManiSpace.lg : ManiSpace.xxl,
                ManiSpace.sm,
              ),
              child: angosta && acciones.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identidad,
                        ManiGap.vMd,
                        Wrap(
                          spacing: ManiSpace.sm,
                          runSpacing: ManiSpace.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: acciones,
                        ),
                      ],
                    )
                  : identidad,
            );
          },
        ),
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

/// Botón en píldora con borde negro: color de marca con sombra si es [principal],
/// blanco si no. Es el de las acciones de Mis solicitudes; el texto oscuro
/// sobre la marca o blanco cumple el contraste AA.
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

/// Centra el contenido de una pantalla con un ancho máximo de [ManiAncho]
/// (formulario, lista, panel) y lo alinea arriba. En móvil no cambia nada.
class ManiAnchoContenido extends StatelessWidget {
  const ManiAnchoContenido({
    super.key,
    required this.ancho,
    required this.child,
  });

  final double ancho;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: ancho),
        child: child,
      ),
    );
  }
}
