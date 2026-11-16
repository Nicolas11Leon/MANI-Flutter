import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/shell/recargar_al_activar.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_esqueleto.dart';
import 'package:mani/core/widgets/mani_estados.dart';
import 'package:mani/core/widgets/mani_pagina.dart';
import 'package:mani/core/widgets/mani_personaje.dart';
import 'package:mani/core/widgets/mani_snackbar.dart';
import 'package:mani/features/profile_categories/domain/entities/category_entity.dart';
import 'package:mani/features/profile_categories/presentation/bloc/categories_cubit.dart';

/// Mis especialidades: el aliado elige en qué categorías trabaja (US-03.1.3).
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CategoriesCubit>(),
      child: const CategoriesView(),
    );
  }
}

/// Vista de la pantalla; recibe el cubit del árbol (así la prueban los tests).
class CategoriesView extends StatelessWidget {
  const CategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: BlocConsumer<CategoriesCubit, CategoriesState>(
          listenWhen: (prev, curr) =>
              (curr.saveSuccess && !prev.saveSuccess) ||
              (curr.saveFailure != null && prev.saveFailure == null),
          listener: (context, state) {
            if (state.saveSuccess) {
              showManiSnackBar(context, 'Especialidades guardadas');
              // La bandeja del aliado se pone al día con sus nuevas especialidades.
              activacionDePestanas.invalidar();
            } else if (state.saveFailure != null) {
              showManiSnackBar(
                context,
                state.saveFailure!.mensajeUsuario,
                esError: true,
              );
            }
          },
          builder: (context, state) {
            final cubit = context.read<CategoriesCubit>();
            final Widget cuerpo;
            if (state.isLoading) {
              cuerpo = ManiPagina(
                children: [
                  const _Encabezado(),
                  const SizedBox(height: 16),
                  ManiEsqueleto.tarjetas(cantidad: 4),
                ],
              );
            } else if (state.loadFailure != null) {
              cuerpo = ManiPagina(
                children: [
                  ManiEstadoVacio(
                    pose: PoseMani.ups,
                    titulo: 'Algo no salió bien',
                    texto: state.loadFailure!.mensajeUsuario,
                    accion: ManiButton(
                      key: const ValueKey('btn-reintentar-categorias'),
                      etiqueta: 'Reintentar',
                      onPressed: cubit.loadCategories,
                    ),
                  ),
                ],
              );
            } else if (state.categories.isEmpty) {
              cuerpo = const ManiPagina(
                children: [
                  ManiEstadoVacio(
                    titulo: 'Aún no hay categorías',
                    texto:
                        'Tu organización aún no tiene categorías activas. '
                        'Contacta al administrador.',
                  ),
                ],
              );
            } else {
              cuerpo = ManiPagina(
                children: [
                  const _Encabezado(),
                  const SizedBox(height: 16),
                  Text(
                    _contador(state.selectedIds.length),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ManiRejilla(
                    anchoMinimo: 150,
                    maxColumnas: 4,
                    espacio: 12,
                    children: [
                      for (final cat in state.categories)
                        _Ficha(
                          categoria: cat,
                          seleccionada: state.selectedIds.contains(cat.id),
                          alTocar: state.isSaving
                              ? null
                              : () => cubit.toggleCategory(cat.id),
                        ),
                    ],
                  ),
                  if (state.selectedIds.isEmpty) ...[
                    const SizedBox(height: 16),
                    const _Indicacion(),
                  ],
                ],
              );
            }
            return Column(
              children: [
                Expanded(child: cuerpo),
                _BarraGuardar(
                  habilitado:
                      !state.isLoading &&
                      !state.isSaving &&
                      state.loadFailure == null &&
                      state.categories.isNotEmpty &&
                      state.selectedIds.isNotEmpty,
                  guardando: state.isSaving,
                  alGuardar: cubit.save,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _contador(int n) =>
      n == 1 ? '1 seleccionada' : '$n seleccionadas';
}

class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    return const ManiEncabezadoPagina(
      icono: Icons.category_outlined,
      titulo: 'Mis especialidades',
      descripcion:
          'Elige lo que sabes hacer. Solo te llegarán solicitudes de estas áreas.',
    );
  }
}

/// Una categoría como ficha: tarjeta de 88 px, con la marca de verificación cuando está elegida.
class _Ficha extends StatelessWidget {
  const _Ficha({
    required this.categoria,
    required this.seleccionada,
    required this.alTocar,
  });

  final CategoryEntity categoria;
  final bool seleccionada;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: seleccionada,
      inMutuallyExclusiveGroup: false,
      label: categoria.label,
      excludeSemantics: true,
      onTap: alTocar,
      child: SizedBox(
        key: ValueKey('categoria-${categoria.id}'),
        height: 88,
        child: Stack(
          children: [
            Positioned.fill(
              child: ManiCard(
                seleccionada: seleccionada,
                onTap: alTocar,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: seleccionada
                            ? AppTheme.surface
                            : AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusIcon,
                        ),
                      ),
                      child: Text(
                        categoria.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        categoria.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.dark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (seleccionada)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppTheme.dark,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sin selección no es un error, es una indicación: va en el tono de aviso y no en rojo.
class _Indicacion extends StatelessWidget {
  const _Indicacion();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.avisoFondo,
        borderRadius: BorderRadius.circular(AppTheme.radiusIcon),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: AppTheme.avisoTexto),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Elige al menos una para continuar.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.avisoTexto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraGuardar extends StatelessWidget {
  const _BarraGuardar({
    required this.habilitado,
    required this.guardando,
    required this.alGuardar,
  });

  final bool habilitado;
  final bool guardando;
  final VoidCallback alGuardar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.dark, width: AppTheme.borderThin),
        ),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ManiButton(
            key: const ValueKey('btn-guardar-categorias'),
            etiqueta: 'Guardar',
            expandir: true,
            cargando: guardando,
            onPressed: habilitado ? alGuardar : null,
          ),
        ),
      ),
    );
  }
}
