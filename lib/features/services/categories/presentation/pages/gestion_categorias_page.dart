import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_pagina.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_confirmacion.dart';
import 'package:mani/core/widgets/mani_snackbar.dart';

import '../../domain/entities/categoria_servicio.dart';
import '../bloc/categorias_cubit.dart';
import '../widgets/categoria_card.dart';
import '../widgets/formulario_categoria.dart';
import 'package:mani/core/widgets/mani_estado.dart';

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
        backgroundColor: ManiColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const _BarraSuperior(),
              Expanded(
                child: BlocBuilder<CategoriasCubit, CategoriasState>(
                  buildWhen: (a, b) => a.carga != b.carga,
                  builder: (context, state) => switch (state.carga) {
                    CargaCategorias.inicial ||
                    CargaCategorias.cargando => const ManiCargando(),
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
                constraints: const BoxConstraints(maxWidth: ManiAncho.panel),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        ManiSpace.xl,
                        ManiSpace.xxl,
                        ManiSpace.xl,
                        ManiSpace.sm,
                      ),
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
                        padding: const EdgeInsets.fromLTRB(
                          ManiSpace.xl,
                          ManiSpace.sm,
                          ManiSpace.xl,
                          ManiSpace.lg,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _CampoBusqueda(
                            onCambio: context.read<CategoriasCubit>().buscar,
                          ),
                        ),
                      ),
                      if (visibles.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(ManiSpace.xxxl),
                            child: Text(
                              'Ninguna categoría coincide con "${state.busqueda.trim()}".',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: ManiColors.inkMuted,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            ManiSpace.xl,
                            0,
                            ManiSpace.xxl,
                            ManiSpace.xxxl,
                          ),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columnas,
                                  mainAxisSpacing: ManiSpace.lg,
                                  crossAxisSpacing: ManiSpace.lg,
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
        ManiGap.vXs,
        Text(
          total == 0
              ? 'Crea las categorías que tus clientes verán al pedir un servicio.'
              : '$activas ${activas == 1 ? 'visible' : 'visibles'} para clientes'
                    '${ocultas > 0 ? ' · $ocultas ${ocultas == 1 ? 'oculta' : 'ocultas'}' : ''}',
          key: const ValueKey('resumen-categorias'),
          style: const TextStyle(
            color: ManiColors.inkMuted,
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
                ManiGap.hLg,
                boton,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [titulo, ManiGap.vMd, boton],
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
      borderRadius: ManiRadius.brMd,
      borderSide: ManiBorder.side,
    );
    return TextField(
      key: const ValueKey('buscar-categoria'),
      onChanged: onCambio,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: ManiColors.surface,
        hintText: 'Buscar categoría',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: ManiColors.inkMuted,
        ),
        enabledBorder: borde,
        focusedBorder: borde.copyWith(borderSide: ManiBorder.sideThick),
      ),
    );
  }
}

class _CatalogoVacio extends StatelessWidget {
  const _CatalogoVacio();

  @override
  Widget build(BuildContext context) => ManiEstadoVacio(
    icono: Icons.category_rounded,
    titulo: 'Aún no tienes categorías',
    texto:
        'Sin categorías tus clientes no pueden pedir servicios. Empieza por la que más solicitan.',
    acciones: [
      ManiButton(
        key: const ValueKey('btn-primera-categoria'),
        etiqueta: 'Crear la primera categoría',
        icono: Icons.add_rounded,
        onPressed: () => mostrarFormularioCategoria(context),
      ),
    ],
  );
}

class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior();

  @override
  Widget build(BuildContext context) {
    return ManiEncabezadoPantalla(
      ancho: ManiAncho.panel,
      icono: Icons.category_rounded,
      titulo: 'Categorías de servicio',
      descripcion: 'Panel del administrador',
      acciones: [
        IconButton(
          key: const ValueKey('btn-actualizar-categorias'),
          tooltip: 'Actualizar',
          onPressed: () =>
              context.read<CategoriasCubit>().cargar(silencioso: true),
          icon: const Icon(Icons.refresh_rounded, color: ManiColors.ink),
        ),
      ],
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
        padding: const EdgeInsets.all(ManiSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: ManiColors.ink,
            ),
            ManiGap.vMd,
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            ManiGap.vLg,
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
