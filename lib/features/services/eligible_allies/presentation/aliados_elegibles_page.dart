import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_card.dart';

import '../domain/aliado_elegible.dart';
import 'aliados_elegibles_cubit.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

/// Aliados elegibles de la solicitud (SCRUM-1398, 1400 y 1401). Filtra por
/// tipo con chips y muestra la lista en el orden exacto que entrega
/// Dispatch. Si Rules no ordenó la lista, lo dice: «Orden no disponible».
class AliadosElegiblesPage extends StatelessWidget {
  const AliadosElegiblesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AliadosElegiblesCubit, AliadosElegiblesState>(
      builder: (context, state) {
        final cubit = context.read<AliadosElegiblesCubit>();
        final lista = state.lista;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ManiBarraPagina(
              icono: Icons.engineering_rounded,
              titulo: 'Aliados para tu solicitud',
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: RefreshIndicator(
                    color: ManiColors.ink,
                    backgroundColor: ManiColors.brand,
                    onRefresh: cubit.cargar,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ManiSpace.xl,
                        vertical: ManiSpace.xxl,
                      ),
                      children: [
                        _FiltroTipo(
                          seleccionado: state.tipo,
                          onCambiar: state.cargando ? null : cubit.filtrar,
                        ),
                        ManiGap.vLg,
                        if (state.error != null)
                          _Error(
                            mensaje: state.error!,
                            onReintentar: cubit.cargar,
                          ),
                        if (state.cargando && lista == null)
                          const Padding(
                            key: Key('elegibles-cargando'),
                            padding: EdgeInsets.all(ManiSpace.xxxl),
                            child: ManiCargando(),
                          )
                        else if (lista != null) ...[
                          _AvisoOrden(lista),
                          ManiGap.vMd,
                          if (lista.aliados.isEmpty)
                            _Vacio(filtrado: state.tipo != null)
                          else ...[
                            for (final (i, a) in lista.aliados.indexed) ...[
                              _TarjetaAliado(
                                a,
                                puesto: lista.ordenAplicado
                                    ? (a.posicion ?? i + 1)
                                    : null,
                              ),
                              ManiGap.vSm,
                            ],
                            if (lista.total > lista.aliados.length)
                              Padding(
                                padding: const EdgeInsets.all(ManiSpace.sm),
                                child: Text(
                                  'Mostrando ${lista.aliados.length} de ${lista.total} aliados.',
                                  key: const Key('elegibles-parcial'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: ManiColors.inkMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FiltroTipo extends StatelessWidget {
  const _FiltroTipo({required this.seleccionado, required this.onCambiar});

  final TipoAliado? seleccionado;
  final ValueChanged<TipoAliado?>? onCambiar;

  @override
  Widget build(BuildContext context) {
    Widget chip(TipoAliado? tipo, String etiqueta) {
      final activo = seleccionado == tipo;
      return FilterChip(
        key: Key('elegibles-tipo-${tipo?.valor ?? 'TODOS'}'),
        label: Text(
          etiqueta,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: ManiColors.ink,
            fontSize: ManiFontSize.bodySm,
          ),
        ),
        selected: activo,
        selectedColor: ManiColors.brand,
        backgroundColor: ManiColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: ManiRadius.brSm,
          side: ManiBorder.sideThin,
        ),
        onSelected: onCambiar == null ? null : (_) => onCambiar!(tipo),
      );
    }

    return Wrap(
      spacing: ManiSpace.sm,
      runSpacing: ManiSpace.sm,
      children: [
        chip(null, 'Todos'),
        for (final t in TipoAliado.values) chip(t, t.etiqueta),
      ],
    );
  }
}

/// Dice de dónde sale el orden. Sin ranking de Rules no se inventa uno.
class _AvisoOrden extends StatelessWidget {
  const _AvisoOrden(this.lista);

  final ListaElegibles lista;

  @override
  Widget build(BuildContext context) {
    final aplicado = lista.ordenAplicado;
    return Container(
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: aplicado ? ManiColors.infoContainer : ManiColors.surfaceMuted,
        borderRadius: ManiRadius.brSm,
        border: Border.all(color: ManiColors.border, width: ManiBorder.thin),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            aplicado ? Icons.sort : Icons.info_outline,
            size: 18,
            color: ManiColors.ink,
          ),
          ManiGap.hSm,
          Expanded(
            child: Text(
              aplicado
                  ? 'Ordenados por las reglas de tu empresa: primero los más adecuados.'
                  : 'Orden no disponible: los aliados no están ordenados por recomendación.',
              key: Key(aplicado ? 'elegibles-orden' : 'elegibles-sin-orden'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: ManiFontSize.bodySm,
                color: ManiColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAliado extends StatelessWidget {
  const _TarjetaAliado(this.aliado, {this.puesto});

  final AliadoElegible aliado;

  /// Puesto en el ranking; `null` si no hay orden.
  final int? puesto;

  @override
  Widget build(BuildContext context) {
    return ManiCard(
      key: Key('elegible-${aliado.id}'),
      padding: const EdgeInsets.all(ManiSpace.lg),
      sombra: ManiShadow.sm,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: puesto != null ? ManiColors.brand : ManiColors.surface,
              borderRadius: ManiRadius.brSm,
              border: Border.all(
                color: ManiColors.border,
                width: ManiBorder.regular,
              ),
            ),
            child: puesto != null
                ? Text(
                    '$puesto',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: ManiFontSize.bodyLg,
                      color: ManiColors.ink,
                    ),
                  )
                : const Icon(Icons.person_outline, color: ManiColors.ink),
          ),
          ManiGap.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        aliado.nombre.isEmpty ? 'Aliado' : aliado.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: ManiFontSize.bodyLg,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ManiSpace.sm,
                        vertical: ManiSpace.xs,
                      ),
                      decoration: BoxDecoration(
                        color: ManiColors.successContainer,
                        borderRadius: ManiRadius.brXs,
                        border: Border.all(color: ManiColors.border, width: 1),
                      ),
                      child: const Text(
                        'Verificado',
                        style: TextStyle(
                          fontSize: ManiFontSize.micro,
                          fontWeight: FontWeight.w800,
                          color: ManiColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                ManiGap.vXs,
                Text(
                  aliado.etiquetaTipo,
                  style: const TextStyle(
                    fontSize: ManiFontSize.bodySm,
                    color: ManiColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ManiGap.vXs,
                Text(
                  aliado.textoCalificacionAgregada,
                  key: Key('elegible-calificacion-${aliado.id}'),
                  style: const TextStyle(
                    fontSize: ManiFontSize.bodySm,
                    fontWeight: FontWeight.w700,
                    color: ManiColors.ink,
                  ),
                ),
                if (puesto != null && aliado.razones.isNotEmpty) ...[
                  ManiGap.vSm,
                  for (final r in aliado.razones)
                    Text(
                      '• $r',
                      style: const TextStyle(
                        fontSize: ManiFontSize.caption,
                        color: ManiColors.inkMuted,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.filtrado});

  final bool filtrado;

  @override
  Widget build(BuildContext context) => ManiEstadoVacio(
    icono: Icons.engineering_outlined,
    tituloKey: const Key('elegibles-vacio'),
    titulo: filtrado
        ? 'No hay aliados de este tipo para tu solicitud. Prueba con otro filtro.'
        : 'Todavía no hay aliados disponibles para tu solicitud.',
  );
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) => ManiEstadoError(
    key: const Key('elegibles-error'),
    botonKey: const Key('elegibles-reintentar'),
    mensaje: mensaje,
    onReintentar: onReintentar,
  );
}
