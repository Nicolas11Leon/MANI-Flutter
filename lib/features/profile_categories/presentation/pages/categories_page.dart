import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/widgets/mani_pulsable.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/features/profile_categories/presentation/bloc/categories_cubit.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

/// Pantalla de selección de categorías del aliado (US-03.1.3).
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
      backgroundColor: ManiColors.background,
      body: SafeArea(
        child: BlocConsumer<CategoriesCubit, CategoriesState>(
          listenWhen: (prev, curr) =>
              (curr.saveSuccess && !prev.saveSuccess) ||
              (curr.saveFailure != null && prev.saveFailure == null),
          listener: (context, state) {
            final messenger = ScaffoldMessenger.of(context);
            if (state.saveSuccess) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Categorías guardadas')),
              );
            } else if (state.saveFailure != null) {
              messenger.showSnackBar(
                SnackBar(content: Text(state.saveFailure!.mensajeUsuario)),
              );
            }
          },
          builder: (context, state) {
            final cubit = context.read<CategoriesCubit>();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ManiEncabezadoPantalla(
                  ancho: ManiAncho.formulario,
                  icono: Icons.handyman_rounded,
                  titulo: 'Mis categorías',
                  descripcion:
                      'Selecciona lo que sabes hacer. Solo verás avisos de trabajos en estas áreas.',
                ),
                if (state.isLoading)
                  const Expanded(child: ManiCargando())
                else if (state.loadFailure != null)
                  Expanded(
                    child: _Mensaje(
                      texto: state.loadFailure!.mensajeUsuario,
                      accion: TextButton(
                        key: const ValueKey('btn-reintentar-categorias'),
                        onPressed: cubit.loadCategories,
                        child: const Text('Reintentar'),
                      ),
                    ),
                  )
                else if (state.categories.isEmpty)
                  const Expanded(
                    child: _Mensaje(
                      texto:
                          'Tu organización aún no tiene categorías activas. '
                          'Contacta al administrador.',
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            ManiSpace.xl +
                            (MediaQuery.sizeOf(context).width >
                                    ManiAncho.formulario
                                ? (MediaQuery.sizeOf(context).width -
                                          ManiAncho.formulario) /
                                      2
                                : 0),
                        vertical: ManiSpace.lg,
                      ),
                      itemCount: state.categories.length,
                      separatorBuilder: (_, _) => ManiGap.vSm,
                      itemBuilder: (context, index) {
                        final cat = state.categories[index];
                        final isSelected = state.selectedIds.contains(cat.id);
                        return ManiPulsable(
                          key: ValueKey('categoria-${cat.id}'),
                          onTap: state.isSaving
                              ? null
                              : () => cubit.toggleCategory(cat.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: ManiSpace.md,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? ManiColors.brand
                                  : ManiColors.surface,
                              borderRadius: ManiRadius.brMd,
                              border: Border.all(
                                color: ManiColors.border,
                                width: ManiBorder.regular,
                              ),
                              boxShadow: isSelected
                                  ? const [ManiShadow.sm]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? ManiColors.surface
                                            : ManiColors.surfaceMuted,
                                        borderRadius: ManiRadius.brMd,
                                        border: Border.all(
                                          color: ManiColors.border,
                                          width: ManiBorder.regular,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        cat.emoji,
                                        style: const TextStyle(
                                          fontSize: ManiFontSize.bodyLg,
                                        ),
                                      ),
                                    ),
                                    ManiGap.hMd,
                                    Text(
                                      cat.label,
                                      style: const TextStyle(
                                        fontSize: ManiFontSize.bodyLg,
                                        fontWeight: FontWeight.w800,
                                        color: ManiColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? ManiColors.surface
                                        : Colors.transparent,
                                    borderRadius: ManiRadius.brSm,
                                    border: Border.all(
                                      color: ManiColors.border,
                                      width: ManiBorder.regular,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: ManiColors.ink,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (state.showError)
                  Container(
                    margin: const EdgeInsets.fromLTRB(
                      ManiSpace.xl,
                      0,
                      ManiSpace.xl,
                      ManiSpace.sm,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: ManiSpace.md,
                      vertical: ManiSpace.md,
                    ),
                    decoration: BoxDecoration(
                      color: ManiColors.dangerContainer,
                      borderRadius: ManiRadius.brMd,
                      border: Border.all(
                        color: ManiColors.border,
                        width: ManiBorder.regular,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: ManiColors.dangerText,
                        ),
                        ManiGap.hSm,
                        Expanded(
                          child: Text(
                            'Selecciona al menos una categoría para continuar.',
                            style: TextStyle(
                              fontSize: ManiFontSize.bodySm,
                              fontWeight: FontWeight.w700,
                              color: ManiColors.dangerText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    ManiSpace.xl,
                    ManiSpace.md,
                    ManiSpace.xl,
                    ManiSpace.xxl,
                  ),
                  decoration: const BoxDecoration(
                    color: ManiColors.surface,
                    border: Border(top: ManiBorder.side),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${state.selectedIds.length} categoría(s) seleccionada(s)',
                        style: const TextStyle(
                          fontSize: ManiFontSize.bodySm,
                          fontWeight: FontWeight.w700,
                          color: ManiColors.inkMuted,
                        ),
                      ),
                      ManiGap.vSm,
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: const ValueKey('btn-guardar-categorias'),
                          onPressed:
                              state.isLoading ||
                                  state.isSaving ||
                                  state.loadFailure != null
                              ? null
                              : cubit.save,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: ManiSpace.lg,
                            ),
                          ),
                          child: state.isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ManiColors.onBrand,
                                  ),
                                )
                              : const Text('GUARDAR'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto, this.accion});

  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ManiSpace.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: ManiFontSize.body,
                fontWeight: FontWeight.w600,
                color: ManiColors.inkMuted,
              ),
            ),
            if (accion != null) ...[ManiGap.vMd, accion!],
          ],
        ),
      ),
    );
  }
}
