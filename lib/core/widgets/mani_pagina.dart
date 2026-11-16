import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_layout.dart';

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
          vertical: 24,
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
      color: AppTheme.dark,
      backgroundColor: AppTheme.primary,
      onRefresh: alRefrescar!,
      child: contenido,
    );
  }
}

/// Encabezado de página. En celular el título ya está en la barra, así que solo lleva la descripción y la acción;
/// desde 600 px de ancho es una tarjeta con el icono, el título y la acción a la derecha.
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
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 600) return _celular();
        return _ancho();
      },
    );
  }

  Widget _celular() {
    if (descripcion == null && accion == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (descripcion != null)
          Text(
            descripcion!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
        if (descripcion != null && accion != null) const SizedBox(height: 12),
        ?accion,
      ],
    );
  }

  Widget _ancho() {
    final texto = Row(
      children: [
        ManiIconoCaja(icono: icono, forma: ManiIconoForma.fuerte),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.dark,
                ),
              ),
              if (descripcion != null) ...[
                const SizedBox(height: 4),
                Text(
                  descripcion!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return ManiCard(
      padding: const EdgeInsets.all(20),
      child: accion == null
          ? texto
          : Row(
              children: [
                Expanded(child: texto),
                const SizedBox(width: 16),
                accion!,
              ],
            ),
    );
  }
}

/// Título de sección: texto de 18 px en tipo oración, sin caja ni subrayado; icono opcional y acción a la derecha
/// (p. ej. «Ver todos»). Separa los bloques de una página.
class ManiTituloSeccion extends StatelessWidget {
  const ManiTituloSeccion({
    super.key,
    required this.titulo,
    this.icono,
    this.accion,
  });

  final String titulo;
  final IconData? icono;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icono != null) ...[
          Icon(icono, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              titulo,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.dark,
              ),
            ),
          ),
        ),
        ?accion,
      ],
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

/// Envoltura de [ManiButton] con el nombre antiguo; se retira cuando todas las pantallas usen `ManiButton`.
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
    return ManiButton(
      etiqueta: etiqueta,
      onPressed: onPressed,
      icono: icono,
      variante: principal
          ? ManiButtonVariante.primario
          : ManiButtonVariante.secundario,
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
      color: esError ? AppTheme.errorLight : AppTheme.surface,
      child: Row(
        children: [
          Icon(icono, color: esError ? AppTheme.errorStrong : AppTheme.dark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.dark,
              ),
            ),
          ),
          if (accion != null) ...[const SizedBox(width: 12), accion!],
        ],
      ),
    );
  }
}
