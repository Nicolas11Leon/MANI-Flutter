import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/utils/formato_fecha.dart';

import '../domain/aviso.dart';
import 'avisos_cubit.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

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

  static const avisoSimulado =
      'SIMULADO · Estos avisos no se envían como push real.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManiEncabezadoPantalla(
            ancho: ManiAncho.lista,
            icono: Icons.notifications_rounded,
            titulo: 'Avisos',
          ),
          Expanded(
            child: ManiAnchoContenido(
              ancho: ManiAncho.lista,
              child: BlocBuilder<AvisosCubit, AvisosState>(
                builder: (context, state) {
                  if (state.fase == FaseAvisos.cargando) {
                    return const ManiCargando();
                  }
                  if (state.fase == FaseAvisos.error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(ManiSpace.xxl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.error!,
                              key: const Key('error-avisos'),
                              textAlign: TextAlign.center,
                            ),
                            ManiGap.vMd,
                            ManiButton(
                              key: const Key('reintentar-avisos'),
                              variante: ManiButtonVariante.secundario,
                              etiqueta: 'Reintentar',
                              onPressed: context.read<AvisosCubit>().cargar,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final bandeja = state.bandeja!;
                  return RefreshIndicator(
                    onRefresh: context.read<AvisosCubit>().cargar,
                    child: ListView(
                      padding: const EdgeInsets.all(ManiSpace.lg),
                      children: [
                        if (bandeja.simulada)
                          const Padding(
                            padding: EdgeInsets.only(bottom: ManiSpace.md),
                            child: Text(
                              avisoSimulado,
                              key: Key('aviso-simulado'),
                            ),
                          ),
                        if (bandeja.items.isEmpty)
                          const ManiEstadoVacio(
                            key: Key('avisos-vacio'),
                            icono: Icons.notifications_none_rounded,
                            titulo: 'No tienes avisos todavía.',
                            texto:
                                'Aquí verás los mensajes nuevos y los cambios de '
                                'estado de tus servicios.',
                          ),
                        for (final a in bandeja.items)
                          _TarjetaAviso(aviso: a, onAbrir: onAbrir),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAviso extends StatelessWidget {
  const _TarjetaAviso({required this.aviso, this.onAbrir});

  final Aviso aviso;
  final void Function(Aviso aviso)? onAbrir;

  @override
  Widget build(BuildContext context) {
    final navegable = onAbrir != null && aviso.solicitudId != null;
    return Card(
      key: Key('aviso-${aviso.id}'),
      margin: const EdgeInsets.only(bottom: ManiSpace.md),
      child: ListTile(
        leading: Icon(
          aviso.esMensaje
              ? Icons.chat_bubble_outline
              : Icons.notifications_none,
        ),
        title: Text(
          aviso.titulo,
          style: TextStyle(
            fontWeight: aviso.leido ? FontWeight.normal : FontWeight.w700,
          ),
        ),
        subtitle: Text(
          [
            if (aviso.detalle.isNotEmpty) aviso.detalle,
            formatearFechaHora(aviso.enviadoEn),
          ].join('\n'),
        ),
        isThreeLine: aviso.detalle.isNotEmpty,
        trailing: navegable ? const Icon(Icons.chevron_right) : null,
        onTap: navegable ? () => onAbrir!(aviso) : null,
      ),
    );
  }
}
