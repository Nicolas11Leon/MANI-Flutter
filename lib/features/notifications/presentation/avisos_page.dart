import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_esqueleto.dart';
import 'package:mani/core/widgets/mani_estados.dart';
import 'package:mani/core/widgets/mani_franja_simulado.dart';
import 'package:mani/core/widgets/mani_layout.dart';
import 'package:mani/core/widgets/mani_personaje.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/utils/formato_fecha.dart';

import '../domain/aviso.dart';
import 'avisos_cubit.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';

/// Bandeja de avisos (SCRUM-882 y 884): mensajes nuevos del servicio y cambios
/// de estado, para cualquier rol. Si un aviso trae la solicitud, tocarlo llama a
/// [onAbrir] (el router decide a qué pantalla va según el rol).
class AvisosPage extends StatelessWidget {
  const AvisosPage({super.key, this.onAbrir});

  final void Function(Aviso aviso)? onAbrir;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AvisosCubit(sl())..cargar(),
    child: AvisosView(onAbrir: onAbrir),
  );
}

class AvisosView extends StatelessWidget {
  const AvisosView({super.key, this.onAbrir});

  final void Function(Aviso aviso)? onAbrir;

  static const avisoSimulado = 'Simulación: no se envían notificaciones reales';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barraDePantalla(context, titulo: 'Avisos'),
      body: BlocBuilder<AvisosCubit, AvisosState>(
        builder: (context, state) => switch (state.fase) {
          FaseAvisos.cargando => Padding(
            padding: const EdgeInsets.all(16),
            child: ManiEsqueleto.lista(filas: 5),
          ),
          FaseAvisos.error => _error(context, state.error!),
          _ => _bandeja(context, state.bandeja!),
        },
      ),
    );
  }

  Widget _error(BuildContext context, String mensaje) {
    return Center(
      child: SingleChildScrollView(
        child: ManiEstadoVacio(
          key: const Key('error-avisos'),
          pose: PoseMani.ups,
          titulo: 'Algo no salió bien',
          texto: mensaje,
          accion: ManiButton(
            key: const Key('reintentar-avisos'),
            etiqueta: 'Reintentar',
            onPressed: context.read<AvisosCubit>().cargar,
          ),
        ),
      ),
    );
  }

  Widget _bandeja(BuildContext context, BandejaAvisos bandeja) {
    final grupos = _agrupar(bandeja.items, DateTime.now());
    return RefreshIndicator(
      onRefresh: context.read<AvisosCubit>().cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (bandeja.simulada)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ManiFranjaSimulado(
                key: Key('aviso-simulado'),
                texto: avisoSimulado,
              ),
            ),
          if (bandeja.items.isEmpty)
            const KeyedSubtree(
              key: Key('avisos-vacio'),
              child: ManiEstadoVacio(
                pose: PoseMani.descansando,
                titulo: 'Estás al día',
                texto:
                    'Aquí verás los mensajes nuevos y los cambios de estado '
                    'de tus servicios.',
              ),
            ),
          for (final g in grupos) ..._grupo(g.rotulo, g.avisos),
        ],
      ),
    );
  }

  List<Widget> _grupo(String rotulo, List<Aviso> avisos) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Text(
          rotulo.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: ManiColors.inkMuted,
          ),
        ),
      ),
      ManiCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < avisos.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  thickness: 1.0,
                  indent: 68,
                  color: ManiColors.borderSubtle,
                ),
              _FilaAviso(aviso: avisos[i], onAbrir: onAbrir),
            ],
          ],
        ),
      ),
    ];
  }

  /// Agrupa en «Hoy», «Ayer» y «Antes», conservando el orden de llegada.
  static List<({String rotulo, List<Aviso> avisos})> _agrupar(
    List<Aviso> items,
    DateTime ahora,
  ) {
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final grupos = <String, List<Aviso>>{};
    for (final a in items) {
      final f = a.enviadoEn;
      final dia = f == null ? null : DateTime(f.year, f.month, f.day);
      final rotulo = dia == null
          ? 'Antes'
          : dia == hoy
          ? 'Hoy'
          : dia == hoy.subtract(const Duration(days: 1))
          ? 'Ayer'
          : 'Antes';
      grupos.putIfAbsent(rotulo, () => []).add(a);
    }
    return [
      for (final r in const ['Hoy', 'Ayer', 'Antes'])
        if (grupos.containsKey(r)) (rotulo: r, avisos: grupos[r]!),
    ];
  }
}

/// Una fila de la bandeja: icono según el tipo, título, una línea de detalle y la hora a la derecha. Sin leer, lleva un
/// punto rojo a la izquierda del título y el título en negrita.
class _FilaAviso extends StatelessWidget {
  const _FilaAviso({required this.aviso, this.onAbrir});

  final Aviso aviso;
  final void Function(Aviso aviso)? onAbrir;

  @override
  Widget build(BuildContext context) {
    final navegable = onAbrir != null && aviso.solicitudId != null;
    final hora = formatearFechaHora(aviso.enviadoEn);
    return InkWell(
      key: Key('aviso-${aviso.id}'),
      onTap: navegable ? () => onAbrir!(aviso) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              ManiIconoCaja(
                icono: aviso.esMensaje
                    ? Icons.chat_bubble_outline
                    : Icons.notifications_none,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!aviso.leido) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: ManiColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            aviso.titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: aviso.leido
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: ManiColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (aviso.detalle.isNotEmpty)
                      Text(
                        aviso.detalle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: ManiColors.inkMuted,
                        ),
                      ),
                    Text(
                      hora,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: ManiColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (navegable)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: ManiColors.inkMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
