import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_confirmacion.dart';
import 'package:mani/core/widgets/mani_snackbar.dart';

import '../../domain/entities/categoria_servicio.dart';
import '../bloc/categorias_cubit.dart';
import '../widgets/categoria_card.dart';
import '../widgets/formulario_categoria.dart';

/// US-03.1.1 — Catálogo de categorías de servicio del Administrador del
/// Tenant: ver las categorías existentes y crear nuevas con su flujo
/// operativo. Requiere un [CategoriasCubit] provisto por el contexto.
class GestionCategoriasPage extends StatelessWidget {
  const GestionCategoriasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<CategoriasCubit, CategoriasState>(
      listenWhen: (antes, ahora) =>
          ahora.aviso != null && antes.aviso != ahora.aviso,
      listener: (context, state) => showManiSnackBar(
        context,
        state.aviso!.mensaje,
        esError: state.aviso!.esError,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              const _BarraSuperior(),
              Expanded(
                child: BlocBuilder<CategoriasCubit, CategoriasState>(
                  buildWhen: (a, b) => a.carga != b.carga,
                  builder: (context, state) => switch (state.carga) {
                    CargaCategorias.inicial ||
                    CargaCategorias.cargando => const Center(
                      child: CircularProgressIndicator(color: AppTheme.dark),
                    ),
                    CargaCategorias.error => _ErrorCarga(
                      mensaje:
                          state.error?.mensajeUsuario ??
                          'No pudimos cargar tus categorías.',
                      onReintentar: () =>
                          context.read<CategoriasCubit>().cargar(),
                    ),
                    CargaCategorias.listo => const _Catalogo(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Catalogo extends StatelessWidget {
  const _Catalogo();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoriasCubit, CategoriasState>(
      builder: (context, state) {
        final visibles = state.visibles;
        return LayoutBuilder(
          builder: (context, constraints) {
            final ancho = constraints.maxWidth;
            final columnas = ancho >= 1100 ? 3 : (ancho >= 700 ? 2 : 1);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      sliver: SliverToBoxAdapter(
                        child: _Encabezado(
                          total: state.categorias.length,
                          activas: state.activas,
                          ocultas: state.ocultas,
                        ),
                      ),
                    ),
                    if (state.categorias.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _CatalogoVacio(),
                      )
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        sliver: SliverToBoxAdapter(
                          child: _CampoBusqueda(
                            onCambio: context.read<CategoriasCubit>().buscar,
                          ),
                        ),
                      ),
                      if (visibles.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'Ninguna categoría coincide con "${state.busqueda.trim()}".',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 24, 32),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columnas,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  mainAxisExtent: 172,
                                ),
                            itemCount: visibles.length,
                            itemBuilder: (_, i) => CategoriaCard(
                              categoria: visibles[i],
                              recienCreada:
                                  visibles[i].id == state.recienCreadaId,
                              cambiandoEstado: state.cambiandoEstadoDe(
                                visibles[i].id,
                              ),
                              onCambiarEstado: (activa) => _cambiarEstado(
                                context,
                                visibles[i],
                                activa: activa,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Desactivar una categoría es crítico y pide confirmación; activarla no
/// (decisión del PO en SCRUM-1650).
Future<void> _cambiarEstado(
  BuildContext context,
  CategoriaServicio categoria, {
  required bool activa,
}) async {
  final cubit = context.read<CategoriasCubit>();
  if (categoria.activa && !activa) {
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Desactivar ${categoria.nombre}?',
      mensaje:
          'Los clientes dejarán de verla en Nueva solicitud. '
          'Los servicios en curso no se afectan.',
      etiquetaConfirmar: 'Desactivar',
    );
    if (!confirmado) return;
  }
  await cubit.cambiarEstado(categoria, activa: activa);
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.total,
    required this.activas,
    required this.ocultas,
  });

  final int total;
  final int activas;
  final int ocultas;

  @override
  Widget build(BuildContext context) {
    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tu catálogo de servicios',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          total == 0
              ? 'Crea las categorías que tus clientes verán al pedir un servicio.'
              : '$activas ${activas == 1 ? 'visible' : 'visibles'} para clientes'
                    '${ocultas > 0 ? ' · $ocultas ${ocultas == 1 ? 'oculta' : 'ocultas'}' : ''}',
          key: const ValueKey('resumen-categorias'),
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    final boton = ManiButton(
      key: const ValueKey('btn-nueva-categoria'),
      etiqueta: 'Nueva categoría',
      icono: Icons.add_rounded,
      onPressed: () => mostrarFormularioCategoria(context),
    );

    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 560
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: titulo),
                const SizedBox(width: 16),
                boton,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [titulo, const SizedBox(height: 14), boton],
            ),
    );
  }
}

class _CampoBusqueda extends StatelessWidget {
  const _CampoBusqueda({required this.onCambio});

  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      borderSide: const BorderSide(color: AppTheme.dark, width: 2),
    );
    return TextField(
      key: const ValueKey('buscar-categoria'),
      onChanged: onCambio,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppTheme.surface,
        hintText: 'Buscar categoría',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppTheme.textSecondary,
        ),
        enabledBorder: borde,
        focusedBorder: borde.copyWith(
          borderSide: const BorderSide(color: AppTheme.dark, width: 2.5),
        ),
      ),
    );
  }
}

class _CatalogoVacio extends StatelessWidget {
  const _CatalogoVacio();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.dark, width: 2),
              boxShadow: const [AppTheme.hardShadowSm],
            ),
            child: const Icon(
              Icons.category_rounded,
              size: 36,
              color: AppTheme.dark,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aún no tienes categorías',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sin categorías tus clientes no pueden pedir servicios. Empieza por la que más solicitan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          ManiButton(
            key: const ValueKey('btn-primera-categoria'),
            etiqueta: 'Crear la primera categoría',
            icono: Icons.add_rounded,
            onPressed: () => mostrarFormularioCategoria(context),
          ),
        ],
      ),
    );
  }
}

class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior();

  @override
  Widget build(BuildContext context) {
    final puedeVolver = Navigator.of(context).canPop();
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.dark, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (puedeVolver) ...[
            IconButton(
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.dark),
            ),
            const SizedBox(width: 4),
          ],
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.dark, width: 2),
              boxShadow: const [AppTheme.hardShadowSm],
            ),
            child: const Icon(
              Icons.category_rounded,
              color: AppTheme.dark,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Categorías de servicio',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.dark,
                  ),
                ),
                Text(
                  'Panel del administrador',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('btn-actualizar-categorias'),
            tooltip: 'Actualizar',
            onPressed: () =>
                context.read<CategoriasCubit>().cargar(silencioso: true),
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.dark),
          ),
        ],
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.dark),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ManiButton(
              key: const ValueKey('btn-reintentar-categorias'),
              etiqueta: 'Reintentar',
              icono: Icons.refresh_rounded,
              onPressed: onReintentar,
            ),
          ],
        ),
      ),
    );
  }
}
