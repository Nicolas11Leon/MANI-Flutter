import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_card.dart';

import '../domain/calificacion_cierre_modelos.dart';
import 'calificacion_cierre_cubit.dart';
import 'package:mani/core/widgets/mani_estado.dart';

/// Estados en los que el servicio ya se puede calificar (Core responde
/// MANI-CAL-409E en los demás).
const estadosCalificables = {'FINALIZADA', 'CERRADA'};

/// Calificación y cierre en la pantalla del servicio (SCRUM-874, 875 y 1418):
/// solo aparece cuando la solicitud está FINALIZADA o CERRADA. Antes de eso no
/// ocupa espacio; el estado lo trae Core con las calificaciones.
class CalificacionServicioFinalizado extends StatelessWidget {
  const CalificacionServicioFinalizado({super.key, required this.esAliado});

  final bool esAliado;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalificacionCierreCubit, CalificacionCierreState>(
      buildWhen: (a, b) => a.resumen?.estado != b.resumen?.estado,
      builder: (context, state) {
        final estado = state.resumen?.estado.trim().toUpperCase();
        if (estado == null || !estadosCalificables.contains(estado)) {
          return const SizedBox.shrink(key: Key('m08-calificacion-oculta'));
        }
        return CalificacionCierreSeccion(esAliado: esAliado);
      },
    );
  }
}

/// Sección de calificación bidireccional (SCRUM-874 y SCRUM-875) y cierre
/// condicionado (SCRUM-1418).
class CalificacionCierreSeccion extends StatefulWidget {
  const CalificacionCierreSeccion({super.key, required this.esAliado});

  /// `false` cuando califica el cliente (SCRUM-874); `true` cuando califica el
  /// aliado (SCRUM-875).
  final bool esAliado;

  @override
  State<CalificacionCierreSeccion> createState() =>
      _CalificacionCierreSeccionState();
}

class _CalificacionCierreSeccionState extends State<CalificacionCierreSeccion> {
  int _puntaje = 0;
  final _comentarioCtrl = TextEditingController();

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalificacionCierreCubit, CalificacionCierreState>(
      builder: (context, state) {
        final cubit = context.read<CalificacionCierreCubit>();
        final resumen = state.resumen;
        final miCalificacion = widget.esAliado
            ? resumen?.aliadoACliente
            : resumen?.clienteAAliado;
        final otraCalificacion = widget.esAliado
            ? resumen?.clienteAAliado
            : resumen?.aliadoACliente;

        return ManiCard(
          key: const Key('m08-calificacion-cierre-card'),
          padding: const EdgeInsets.all(ManiSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(ManiSpace.sm),
                    decoration: BoxDecoration(
                      color: ManiColors.brand,
                      borderRadius: ManiRadius.brSm,
                      border: Border.all(
                        color: ManiColors.border,
                        width: ManiBorder.regular,
                      ),
                      boxShadow: const [ManiShadow.sm],
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: ManiColors.ink,
                      size: 20,
                    ),
                  ),
                  ManiGap.hMd,
                  Expanded(
                    child: Text(
                      widget.esAliado
                          ? 'Calificar al cliente y estado de cierre'
                          : 'Calificar al aliado y estado de cierre',
                      style: const TextStyle(
                        fontSize: ManiFontSize.bodyLg,
                        fontWeight: FontWeight.w900,
                        color: ManiColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              ManiGap.vMd,
              if (resumen != null) _BannerEstadoCierre(cierre: resumen.cierre),
              _MensajesFeedback(
                error: state.error,
                mensajeExito: state.mensajeExito,
              ),
              ManiGap.vMd,
              _CuerpoCalificacionPropia(
                miCalificacion: miCalificacion,
                puntajeSeleccionado: _puntaje,
                comentarioCtrl: _comentarioCtrl,
                enviando: state.enviando,
                onSeleccionarPuntaje: (v) => setState(() => _puntaje = v),
                onEnviar: () => cubit.calificar(
                  puntaje: _puntaje,
                  comentario: _comentarioCtrl.text,
                ),
              ),
              if (otraCalificacion != null) ...[
                const Divider(height: 24),
                Text(
                  'Calificación recibida: ★ ${otraCalificacion.puntaje}/5',
                  key: const Key('m08-otra-calificacion-registrada'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: ManiColors.ink,
                  ),
                ),
              ],
              ManiGap.vMd,
              OutlinedButton(
                key: const Key('m08-cerrar-solicitud-btn'),
                onPressed: state.enviando ? null : cubit.cerrarSolicitud,
                child: const Text('Verificar cierre definitivo'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BannerEstadoCierre extends StatelessWidget {
  const _BannerEstadoCierre({required this.cierre});

  final EstadoCierreSolicitud cierre;

  @override
  Widget build(BuildContext context) {
    final completo = cierre.cierreCompleto;
    return Container(
      key: const Key('m08-estado-cierre-banner'),
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: completo ? ManiColors.successContainer : ManiColors.brandSoft,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
      ),
      child: Row(
        children: [
          Icon(
            completo
                ? Icons.verified_outlined
                : Icons.hourglass_bottom_outlined,
            color: ManiColors.ink,
          ),
          ManiGap.hSm,
          Expanded(
            child: Text(
              cierre.etiquetaEstadoCierre,
              key: const Key('m08-estado-cierre-texto'),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: ManiColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MensajesFeedback extends StatelessWidget {
  const _MensajesFeedback({this.error, this.mensajeExito});

  final String? error;
  final String? mensajeExito;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error != null) ...[
          ManiGap.vSm,
          Text(
            error!,
            key: const Key('m08-calificacion-error'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (mensajeExito != null) ...[
          ManiGap.vSm,
          Text(
            mensajeExito!,
            key: const Key('m08-calificacion-exito'),
            style: const TextStyle(
              color: ManiColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _CuerpoCalificacionPropia extends StatelessWidget {
  const _CuerpoCalificacionPropia({
    required this.miCalificacion,
    required this.puntajeSeleccionado,
    required this.comentarioCtrl,
    required this.enviando,
    required this.onSeleccionarPuntaje,
    required this.onEnviar,
  });

  final CalificacionServicio? miCalificacion;
  final int puntajeSeleccionado;
  final TextEditingController comentarioCtrl;
  final bool enviando;
  final ValueChanged<int> onSeleccionarPuntaje;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    final calif = miCalificacion;
    if (calif != null) {
      final comentario = calif.comentario ?? '';
      return Container(
        padding: const EdgeInsets.all(ManiSpace.md),
        decoration: BoxDecoration(
          color: ManiColors.background,
          borderRadius: ManiRadius.brMd,
          border: Border.all(color: ManiColors.border, width: ManiBorder.thin),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu calificación enviada: ★ ${calif.puntaje}/5',
              key: const Key('m08-mi-calificacion-registrada'),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: ManiColors.ink,
              ),
            ),
            if (comentario.isNotEmpty) ...[
              ManiGap.vXs,
              Text('Comentario: $comentario'),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona un puntaje de 1 a 5 estrellas:',
          style: TextStyle(fontWeight: FontWeight.w700, color: ManiColors.ink),
        ),
        ManiGap.vSm,
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                key: Key('m08-estrella-$i'),
                icon: Icon(
                  i <= puntajeSeleccionado ? Icons.star : Icons.star_border,
                  color: ManiColors.ink,
                  size: 28,
                ),
                onPressed: enviando ? null : () => onSeleccionarPuntaje(i),
              ),
          ],
        ),
        ManiGap.vSm,
        TextField(
          key: const Key('m08-comentario-input'),
          controller: comentarioCtrl,
          maxLength: 500,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Comentario (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        ManiGap.vSm,
        FilledButton(
          key: const Key('m08-enviar-calificacion-btn'),
          onPressed: enviando ? null : onEnviar,
          child: const Text('Enviar calificación'),
        ),
      ],
    );
  }
}

/// Pantalla de historial de servicios del cliente (SCRUM-879) o de trabajos
/// del aliado (SCRUM-880).
class HistorialServiciosPage extends StatelessWidget {
  const HistorialServiciosPage({super.key, this.onAbrirServicio});

  /// Abre la pantalla del servicio (cotización, ejecución y calificación).
  final void Function(String solicitudId)? onAbrirServicio;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HistorialServiciosCubit, HistorialServiciosState>(
      builder: (context, state) {
        final cubit = context.read<HistorialServiciosCubit>();
        final titulo = cubit.esAliado
            ? 'Historial de trabajos'
            : 'Historial de servicios';
        final textoVacio = cubit.esAliado
            ? 'Sin trabajos asignados en tu historial.'
            : 'Sin servicios registrados en tu historial.';

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(ManiSpace.xl),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(ManiSpace.sm),
                      decoration: BoxDecoration(
                        color: ManiColors.brand,
                        borderRadius: ManiRadius.brSm,
                        border: Border.all(
                          color: ManiColors.border,
                          width: ManiBorder.regular,
                        ),
                        boxShadow: const [ManiShadow.sm],
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: ManiColors.ink,
                        size: 20,
                      ),
                    ),
                    ManiGap.hMd,
                    Expanded(
                      child: Text(
                        titulo,
                        key: const Key('m08-historial-titulo'),
                        style: const TextStyle(
                          fontSize: ManiFontSize.h3,
                          fontWeight: FontWeight.w900,
                          color: ManiColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                ManiGap.vLg,
                if (state.error != null)
                  Text(
                    state.error!,
                    key: const Key('m08-historial-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (state.cargando && state.registros.isEmpty)
                  const ManiCargando()
                else if (state.registros.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(ManiSpace.xxl),
                    child: Text(
                      textoVacio,
                      key: const Key('m08-historial-vacio'),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  for (final item in state.registros)
                    _TarjetaHistorialItem(
                      item: item,
                      esAliado: cubit.esAliado,
                      onAbrir: onAbrirServicio == null
                          ? null
                          : () => onAbrirServicio!(item.id),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TarjetaHistorialItem extends StatelessWidget {
  const _TarjetaHistorialItem({
    required this.item,
    required this.esAliado,
    this.onAbrir,
  });

  final RegistroHistorialServicio item;
  final bool esAliado;
  final VoidCallback? onAbrir;

  @override
  Widget build(BuildContext context) {
    final etiquetaContraparte = esAliado ? 'Cliente' : 'Aliado';
    return Card(
      key: Key('m08-historial-item-${item.id}'),
      child: Padding(
        padding: const EdgeInsets.all(ManiSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.categoria,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  key: Key('m08-historial-estado-${item.id}'),
                  label: Text(item.estado),
                ),
              ],
            ),
            ManiGap.vXs,
            Text(item.descripcion),
            Text('Zona: ${item.zona} · Dirección: ${item.direccion}'),
            if (item.nombreContraparte != null)
              Text('$etiquetaContraparte: ${item.nombreContraparte}'),
            if (item.valorTotal != null)
              Text('Valor total: \$${item.valorTotal!.toStringAsFixed(0)}'),
            if (item.penalizacionAplicada)
              Text(
                'Penalización aplicada: \$${item.penalizacionMonto.toStringAsFixed(0)}',
                key: Key('m08-historial-penalizacion-${item.id}'),
              ),
            if (item.calificacionEmitida != null)
              Text(
                'Calificación emitida: ★ ${item.calificacionEmitida!.puntaje}/5',
              ),
            if (item.calificacionRecibida != null)
              Text(
                'Calificación recibida: ★ ${item.calificacionRecibida!.puntaje}/5',
              ),
            if (onAbrir != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: Key('m08-historial-abrir-${item.id}'),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(
                    estadosCalificables.contains(item.estado.toUpperCase()) &&
                            item.calificacionEmitida == null
                        ? 'Calificar servicio'
                        : 'Ver servicio',
                  ),
                  onPressed: onAbrir,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ResumenPenalizacionCancelacionBanner extends StatelessWidget {
  const ResumenPenalizacionCancelacionBanner({
    super.key,
    required this.preview,
  });

  final VistaPreviaPenalizacion preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('m08-penalizacion-preview-banner'),
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: preview.aplicaPenalizacion
            ? ManiColors.brandSoft
            : ManiColors.surface,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
        boxShadow: const [ManiShadow.sm],
      ),
      child: Text(
        preview.resumenUsuario,
        key: const Key('m08-penalizacion-preview-texto'),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: ManiColors.ink,
        ),
      ),
    );
  }
}
