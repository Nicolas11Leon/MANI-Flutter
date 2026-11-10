import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_card.dart';

import '../bloc/crear_solicitud_cubit.dart';
import '../utils/estilo_solicitud.dart';
import 'encabezado_paso.dart';

/// Paso 1: ¿qué servicio necesitas? Un toque elige y avanza.
class PasoCategoria extends StatelessWidget {
  const PasoCategoria({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CrearSolicitudCubit>().state;
    final categorias = state.catalogo.categorias;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EncabezadoPaso(
          titulo: '¿Qué servicio necesitas?',
          subtitulo: 'Elige la categoría que mejor describe tu problema.',
        ),
        ManiGap.vLg,
        if (categorias.isEmpty)
          const _SinCategorias()
        else
          LayoutBuilder(
            builder: (context, c) {
              final columnas = c.maxWidth >= 560 ? 2 : 1;
              return GridView.count(
                crossAxisCount: columnas,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columnas == 2 ? 2.6 : 4.2,
                children: [
                  for (final cat in categorias)
                    ManiCard(
                      key: ValueKey('categoria-${cat.id}'),
                      seleccionada: cat.id == state.categoriaId,
                      sombra: ManiShadow.sm,
                      padding: const EdgeInsets.symmetric(
                        horizontal: ManiSpace.md,
                        vertical: ManiSpace.sm,
                      ),
                      onTap: () => context
                          .read<CrearSolicitudCubit>()
                          .elegirCategoria(cat.id),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: ManiColors.brand,
                              borderRadius: ManiRadius.brMd,
                              border: Border.all(
                                color: ManiColors.border,
                                width: ManiBorder.regular,
                              ),
                            ),
                            child: Icon(
                              iconoCategoria(cat.nombre),
                              color: ManiColors.ink,
                            ),
                          ),
                          ManiGap.hMd,
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: ManiFontSize.body,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                ManiGap.vXxs,
                                Text(
                                  textoModalidad(cat.modalidad),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: ManiFontSize.caption,
                                    color: ManiColors.inkMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: ManiColors.inkSubtle,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _SinCategorias extends StatelessWidget {
  const _SinCategorias();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ManiSpace.xl),
      decoration: BoxDecoration(
        color: ManiColors.surface,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 36, color: ManiColors.ink),
          ManiGap.vSm,
          Text(
            'Aún no hay servicios disponibles',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: ManiFontSize.bodyLg,
            ),
          ),
          ManiGap.vXs,
          Text(
            'Tu empresa de servicios todavía no publicó categorías. '
            'Vuelve a intentarlo más tarde.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ManiColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
