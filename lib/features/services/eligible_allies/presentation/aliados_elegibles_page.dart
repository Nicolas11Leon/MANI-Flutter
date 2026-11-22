import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_avatar.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_estado.dart'
    hide ManiEstadoVacio, ManiEstadoError;
import 'package:mani/core/widgets/mani_estados.dart';
import 'package:mani/core/widgets/mani_personaje.dart';

import '../domain/aliado_elegible.dart';
import 'aliados_elegibles_cubit.dart';

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
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: RefreshIndicator(
              color: ManiColors.ink,
              backgroundColor: ManiColors.brand,
              onRefresh: cubit.cargar,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                children: [
                  const Text(
                    'Aliados para tu solicitud',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: ManiColors.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FiltroTipo(
                    seleccionado: state.tipo,
                    onCambiar: state.cargando ? null : cubit.filtrar,
                  ),
                  const SizedBox(height: 16),
                  if (state.error != null)
                    _Error(mensaje: state.error!, onReintentar: cubit.cargar),
                  if (state.cargando && lista == null)
                    const Padding(
                      key: Key('elegibles-cargando'),
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(color: ManiColors.ink),
                      ),
                    )
                  else if (lista != null) ...[
                    _AvisoOrden(lista),
                    const SizedBox(height: 12),
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
                        const SizedBox(height: 10),
                      ],
                      if (lista.total > lista.aliados.length)
                        Padding(
                          padding: const EdgeInsets.all(8),
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
            fontSize: 13,
          ),
        ),
        selected: activo,
        selectedColor: ManiColors.brand,
        backgroundColor: ManiColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ManiRadius.lg),
          side: const BorderSide(color: ManiColors.ink, width: 1.5),
        ),
        onSelected: onCambiar == null ? null : (_) => onCambiar!(tipo),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: aplicado ? ManiColors.brandSoft : ManiColors.surfaceMuted,
        borderRadius: BorderRadius.circular(ManiRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            aplicado ? Icons.sort : Icons.info_outline,
            size: 18,
            color: ManiColors.ink,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              aplicado
                  ? 'Ordenados por las reglas de tu empresa: primero los más adecuados.'
                  : 'Orden no disponible: los aliados no están ordenados por recomendación.',
              key: Key(aplicado ? 'elegibles-orden' : 'elegibles-sin-orden'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
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
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ManiAvatar(
                nombre: aliado.nombre.isEmpty ? 'Aliado' : aliado.nombre,
              ),
              if (puesto != null)
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ManiColors.brand,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ManiColors.ink,
                        width: ManiBorder.thin,
                      ),
                    ),
                    child: Text(
                      '$puesto',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: ManiColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
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
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const ManiEstado(texto: 'Verificado', tono: ManiTono.listo),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  aliado.etiquetaTipo,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ManiColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  aliado.textoCalificacionAgregada,
                  key: Key('elegible-calificacion-${aliado.id}'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ManiColors.ink,
                  ),
                ),
                if (puesto != null && aliado.razones.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  for (final r in aliado.razones)
                    Text(
                      '• $r',
                      style: const TextStyle(
                        fontSize: 12,
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
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('elegibles-vacio'),
      child: ManiEstadoVacio(
        pose: PoseMani.buscando,
        titulo: 'Aún no hay aliados para esta solicitud',
        texto: filtrado
            ? 'No hay aliados de este tipo para tu solicitud. Prueba con otro filtro.'
            : 'Todavía no hay aliados disponibles para tu solicitud. Te avisaremos cuando alguno la tome.',
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('elegibles-error'),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: ManiColors.dangerContainer,
        borderRadius: BorderRadius.circular(ManiRadius.md),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: ManiColors.dangerText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                color: ManiColors.dangerText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ManiButton(
            key: const Key('elegibles-reintentar'),
            etiqueta: 'Reintentar',
            variante: ManiButtonVariante.texto,
            onPressed: onReintentar,
          ),
        ],
      ),
    );
  }
}
