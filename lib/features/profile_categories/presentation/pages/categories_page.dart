import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/widgets/mani_pulsable.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/features/profile_categories/presentation/bloc/categories_cubit.dart';
import 'package:mani/core/theme/app_theme.dart';

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
      backgroundColor: ManiColors.surfaceWarm,
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
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ManiSpace.xl,
                    ManiSpace.sm,
                    ManiSpace.xl,
                    ManiSpace.md,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: ManiRadius.brMd,
                          border: Border.all(
                            color: ManiColors.border,
                            width: ManiBorder.regular,
                          ),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.arrow_back,
                            size: 18,
                            color: ManiColors.ink,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      ManiGap.hMd,
                      const Text(
                        'Mis categorías',
                        style: TextStyle(
                          fontSize: ManiFontSize.h3,
                          fontWeight: FontWeight.w600,
                          color: ManiColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    ManiSpace.xl,
                    0,
                    ManiSpace.xl,
                    ManiSpace.lg,
                  ),
                  child: Text(
                    'Selecciona lo que sabes hacer. Solo verás avisos de trabajos en estas áreas.',
                    style: TextStyle(
                      fontSize: ManiFontSize.body,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: ManiColors.inkMuted,
                    ),
                  ),
                ),
                if (state.isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
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
                      padding: const EdgeInsets.fromLTRB(
                        ManiSpace.xl,
                        0,
                        ManiSpace.xl,
                        ManiSpace.md,
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
                                  : Colors.white,
                              borderRadius: ManiRadius.brMd,
                              border: Border.all(
                                color: ManiColors.border,
                                width: ManiBorder.regular,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      const BoxShadow(
                                        color: ManiColors.ink,
                                        offset: Offset(2, 2),
                                        blurRadius: 0,
                                      ),
                                    ]
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
                                            ? Colors.white
                                            : ManiColors.surfaceWarm,
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
                                        ? Colors.white
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
                      horizontal: 13,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: ManiRadius.brMd,
                      border: Border.all(
                        color: ManiColors.danger,
                        width: ManiBorder.regular,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: ManiColors.danger,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: ManiColors.danger,
                        ),
                        ManiGap.hSm,
                        Expanded(
                          child: Text(
                            'Selecciona al menos una categoría para continuar.',
                            style: TextStyle(
                              fontSize: ManiFontSize.bodySm,
                              fontWeight: FontWeight.w700,
                              color: ManiColors.danger,
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
                    26,
                  ),
                  decoration: const BoxDecoration(
                    color: ManiColors.surfaceWarm,
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
                            backgroundColor: ManiColors.danger,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: ManiSpace.lg,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: ManiRadius.brMd,
                              side: ManiBorder.side,
                            ),
                            elevation: 0,
                          ),
                          child: state.isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'GUARDAR',
                                  style: TextStyle(
                                    fontSize: ManiFontSize.bodyLg,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
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
