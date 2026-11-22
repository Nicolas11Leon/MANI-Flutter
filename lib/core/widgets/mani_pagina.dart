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
    final t = context.mani;
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
            color: t.onBrand,
            backgroundColor: t.brand,
            onRefresh: alRefrescar!,
            child: contenido,
          );
    if (encabezado == null) {
      return ColoredBox(color: t.background, child: cuerpo);
    }
    return ColoredBox(
      color: t.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          encabezado!,
          Expanded(child: cuerpo),
        ],
      ),
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
/// Encabezado de página con una sola acción (forma de SCRUM-1646): delega en
/// [ManiEncabezadoPantalla].
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
  Widget build(BuildContext context) => ManiEncabezadoPantalla(
    icono: icono,
    titulo: titulo,
    descripcion: descripcion,
    acciones: [?accion],
  );
}

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
    final t = context.mani;
    final puedeVolver = ModalRoute.of(context)?.canPop ?? false;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(
          bottom: BorderSide(color: t.borderSubtle, width: ManiBorder.thin),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, c) {
          final angosta = c.maxWidth < 600;
          final identidad = _identidad(context, puedeVolver, angosta);
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: angosta ? ManiSpace.lg : ManiSpace.xxl,
              vertical: angosta ? ManiSpace.md : ManiSpace.lg,
            ),
            // En pantalla angosta las acciones bajan debajo del título.
            child: angosta && acciones.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [identidad, ManiGap.vMd, _accionesEnFila()],
                  )
                : identidad,
          );
        },
      ),
    );
  }

  /// Volver (si hay a dónde), icono, título y descripción; en pantalla ancha
  /// también las acciones, a la derecha.
  Widget _identidad(BuildContext context, bool puedeVolver, bool angosta) {
    final t = context.mani;
    return Row(
      children: [
        if (puedeVolver) ...[
          IconButton(
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_rounded, color: t.ink),
          ),
          ManiGap.hXs,
        ],
        _IconoEncabezado(icono: icono),
        ManiGap.hMd,
        Expanded(child: _textos(t, angosta)),
        if (!angosta && acciones.isNotEmpty) ...[
          ManiGap.hLg,
          _accionesEnFila(),
        ],
      ],
    );
  }

  Widget _textos(ManiTokens t, bool angosta) {
    return Column(
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
            style: ManiText.h3.copyWith(color: t.ink),
          ),
        ),
        if (descripcion != null) ...[
          ManiGap.vXxs,
          Text(
            descripcion!,
            key: descripcionKey,
            maxLines: angosta ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: ManiText.bodySm.copyWith(color: t.inkMuted),
          ),
        ],
      ],
    );
  }

  Widget _accionesEnFila() => Wrap(
    spacing: ManiSpace.sm,
    runSpacing: ManiSpace.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: acciones,
  );
}

/// Icono de la pantalla sobre un cuadro del color de marca.
class _IconoEncabezado extends StatelessWidget {
  const _IconoEncabezado({required this.icono});

  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return ExcludeSemantics(
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.brand,
          borderRadius: ManiRadius.brSm,
          border: Border.all(color: t.border, width: ManiBorder.regular),
          boxShadow: [t.shadowSm],
        ),
        child: Icon(icono, color: t.onBrand, size: 22),
      ),
    );
  }
}

/// Título de sección: ícono en caja de marca, texto en mayúsculas y línea
/// divisoria estructural. Separa los bloques de una página y jerarquiza
/// tableros.
class ManiTituloSeccion extends StatelessWidget {
  const ManiTituloSeccion({
    super.key,
    this.icono,
    required this.titulo,
    this.accion,
  });

  /// Sin ícono, el título va solo (secciones del inicio móvil, SCRUM-1647).
  final IconData? icono;
  final String titulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return Container(
      padding: const EdgeInsets.only(bottom: ManiSpace.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: t.border, width: ManiBorder.regular),
        ),
      ),
      child: Row(
        children: [
          if (icono != null) ...[
            Container(
              padding: const EdgeInsets.all(ManiSpace.sm),
              decoration: BoxDecoration(
                color: t.brand,
                borderRadius: ManiRadius.brSm,
                border: Border.all(color: t.border, width: ManiBorder.regular),
                boxShadow: [t.shadowSm],
              ),
              child: Icon(icono, color: t.onBrand, size: 18),
            ),
            ManiGap.hSm,
          ],
          Expanded(
            child: Text(
              titulo.toUpperCase(),
              style: TextStyle(
                fontSize: ManiFontSize.bodySm,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                color: t.ink,
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

/// Botón en píldora con borde: color de marca con sombra si es [principal],
/// superficie si no.
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
    final t = context.mani;
    final fg = principal ? t.onBrand : t.ink;
    final estilo = TextButton.styleFrom(
      foregroundColor: fg,
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
        color: principal ? t.brand : t.surface,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: t.border, width: ManiBorder.regular),
        boxShadow: [t.shadowSm],
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
              icon: Icon(icono, size: 18, color: fg),
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
    final t = context.mani;
    final colorTexto = esError ? ManiColors.dangerText : t.ink;
    return ManiCard(
      color: esError ? ManiColors.dangerContainer : t.surface,
      sombra: t.shadowSm,
      child: Row(
        children: [
          Icon(icono, color: colorTexto),
          ManiGap.hMd,
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontWeight: FontWeight.w700, color: colorTexto),
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
