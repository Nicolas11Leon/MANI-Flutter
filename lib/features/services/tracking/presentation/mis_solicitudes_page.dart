import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/refresco_periodico.dart';
import 'package:mani/features/services/ratings/data/calificacion_cierre_datasource.dart';
import 'package:mani/features/services/ratings/domain/calificacion_cierre_modelos.dart';
import 'package:mani/features/services/ratings/presentation/calificacion_cierre_cubit.dart';
import 'package:mani/features/services/ratings/presentation/calificacion_cierre_widgets.dart';

import '../domain/solicitud_seguimiento.dart';
import 'mis_solicitudes_cubit.dart';

/// Mis solicitudes (HU-M07-04 / SCRUM-871): estado vigente y zona declarada
/// de cada solicitud del cliente. No muestra la ubicación del aliado. Se
/// actualiza sola mientras está a la vista (SCRUM-1710) y el cliente también
/// puede consultar con «Actualizar».
class MisSolicitudesPage extends StatelessWidget {
  const MisSolicitudesPage({
    super.key,
    this.onNuevaSolicitud,
    this.onVerCotizacion,
    this.onVerAliados,
    this.onPresentarQueja,
    this.previsualizarCancelacion,
    this.intervaloRefresco = RefrescoPeriodico.intervaloPorDefecto,
  });

  /// Cada cuánto se vuelve a consultar el estado (SCRUM-1710). `null`
  /// desactiva el sondeo (tests).
  final Duration? intervaloRefresco;

  final VoidCallback? onNuevaSolicitud;

  /// Presenta una queja sobre el servicio (HU-M12-01 / SCRUM-895). Solo se
  /// ofrece cuando la solicitud ya tuvo aliado; Core vuelve a validarlo.
  final void Function(String solicitudId)? onPresentarQueja;

  /// Consulta a Core la penalización que tendría cancelar (SCRUM-878) para
  /// mostrarla antes de confirmar. Sin ella el diálogo no muestra el resumen.
  final Future<VistaPreviaPenalizacion> Function(String solicitudId)?
  previsualizarCancelacion;

  /// Abre la cotización de la solicitud (SCRUM-867).
  final void Function(String solicitudId)? onVerCotizacion;

  /// Abre los aliados elegibles de una solicitud pendiente (SCRUM-1401).
  final void Function(String solicitudId)? onVerAliados;

  @override
  Widget build(BuildContext context) => RefrescoPeriodico(
    intervalo: intervaloRefresco,
    onRefrescar: () =>
        context.read<MisSolicitudesCubit>().cargar(silencioso: true),
    child: _contenido(context),
  );

  Widget _contenido(BuildContext context) {
    return BlocBuilder<MisSolicitudesCubit, MisSolicitudesState>(
      builder: (context, state) {
        final cubit = context.read<MisSolicitudesCubit>();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: RefreshIndicator(
              color: AppTheme.dark,
              backgroundColor: AppTheme.primary,
              onRefresh: cubit.cargar,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                children: [
                  _Encabezado(state: state, onActualizar: cubit.cargar),
                  const SizedBox(height: 14),
                  const _AvisoZona(),
                  const SizedBox(height: 16),
                  if (state.error != null)
                    _Error(mensaje: state.error!, onReintentar: cubit.cargar),
                  if (state.cargando && state.solicitudes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.dark),
                      ),
                    )
                  else if (state.solicitudes.isEmpty && state.error == null)
                    _Vacio(onNuevaSolicitud: onNuevaSolicitud)
                  else
                    for (final s in state.solicitudes) ...[
                      _TarjetaSolicitud(
                        s,
                        onVerCotizacion:
                            onVerCotizacion == null || !s.tieneCotizacion
                            ? null
                            : () => onVerCotizacion!(s.id),
                        onVerAliados:
                            onVerAliados == null ||
                                s.estado != EstadoSeguimiento.pendiente
                            ? null
                            : () => onVerAliados!(s.id),
                        onPresentarQueja:
                            onPresentarQueja == null ||
                                s.estado == EstadoSeguimiento.pendiente ||
                                s.estado == EstadoSeguimiento.otro
                            ? null
                            : () => onPresentarQueja!(s.id),
                        cancelando: state.cancelandoId == s.id,
                        onCancelar:
                            !s.puedeCancelar || state.cancelandoId != null
                            ? null
                            : () => _confirmarCancelacion(
                                context,
                                cubit,
                                s,
                                previsualizarCancelacion,
                              ),
                      ),
                      const SizedBox(height: 14),
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

/// QAS-08: cancelar es irreversible, así que se confirma antes y se ofrece
/// dejar un motivo opcional (queda en la línea de tiempo del servicio).
Future<void> _confirmarCancelacion(
  BuildContext context,
  MisSolicitudesCubit cubit,
  SolicitudSeguimiento solicitud,
  Future<VistaPreviaPenalizacion> Function(String)? previsualizar,
) async {
  final motivo = await showDialog<String>(
    context: context,
    builder: (_) => _DialogoCancelar(
      solicitud: solicitud,
      vistaPrevia: previsualizar?.call(solicitud.id),
    ),
  );
  if (motivo == null) return;
  final ok = await cubit.cancelar(solicitud.id, motivo: motivo);
  if (ok && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        key: Key('cancelacion-ok'),
        content: Text('Cancelaste la solicitud.'),
      ),
    );
  }
}

class _DialogoCancelar extends StatefulWidget {
  const _DialogoCancelar({required this.solicitud, this.vistaPrevia});

  final SolicitudSeguimiento solicitud;

  /// Penalización que tendría cancelar ahora (SCRUM-878), calculada por Core.
  final Future<VistaPreviaPenalizacion>? vistaPrevia;

  @override
  State<_DialogoCancelar> createState() => _DialogoCancelarState();
}

class _DialogoCancelarState extends State<_DialogoCancelar> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asignada = widget.solicitud.estado != EstadoSeguimiento.pendiente;
    return AlertDialog(
      key: const Key('dialogo-cancelar'),
      title: const Text('¿Cancelar la solicitud?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vas a cancelar «${widget.solicitud.categoria}». '
            'Esta acción no se puede deshacer.'
            '${asignada ? ' Le avisaremos al aliado asignado.' : ''}',
          ),
          if (widget.vistaPrevia != null) ...[
            const SizedBox(height: 12),
            FutureBuilder<VistaPreviaPenalizacion>(
              future: widget.vistaPrevia,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator(
                    key: Key('cancelar-penalizacion-cargando'),
                  );
                }
                if (snap.hasError || snap.data == null) {
                  return const Text(
                    'No pudimos calcular la penalización. Si cancelas, '
                    'se aplicará la política vigente de tu empresa.',
                    key: Key('cancelar-penalizacion-error'),
                  );
                }
                return ResumenPenalizacionCancelacionBanner(
                  preview: snap.data!,
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const Key('cancelar-motivo'),
            controller: _motivo,
            maxLength: 200,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('cancelar-volver'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
        FilledButton(
          key: const Key('cancelar-confirmar'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(_motivo.text.trim()),
          child: const Text('Sí, cancelar'),
        ),
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.state, required this.onActualizar});

  final MisSolicitudesState state;
  final Future<void> Function() onActualizar;

  @override
  Widget build(BuildContext context) {
    final consultado = state.consultadoEn;
    return ManiCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(color: AppTheme.dark, width: 2),
              boxShadow: const [AppTheme.hardShadowSm],
            ),
            child: const Icon(
              Icons.list_alt_rounded,
              color: AppTheme.dark,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mis solicitudes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.dark,
                  ),
                ),
                if (consultado != null)
                  Text(
                    'Consultado: ${formatearFecha(consultado)}',
                    key: const Key('seguimiento-consultado'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (sl.isRegistered<FuenteModuloM08>())
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(color: AppTheme.dark, width: 2),
                  boxShadow: const [AppTheme.hardShadowSm],
                ),
                child: TextButton.icon(
                  key: const Key('seguimiento-ver-historial'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 720,
                          maxHeight: 620,
                        ),
                        child: BlocProvider(
                          create: (_) => HistorialServiciosCubit(
                            sl<FuenteModuloM08>(),
                            esAliado: false,
                          )..cargar(),
                          child: const HistorialServiciosPage(),
                        ),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Historial'),
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(color: AppTheme.dark, width: 2),
              boxShadow: const [AppTheme.hardShadowSm],
            ),
            child: TextButton.icon(
              key: const Key('seguimiento-actualizar'),
              onPressed: state.cargando ? null : onActualizar,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualizar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoZona extends StatelessWidget {
  const _AvisoZona();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.dark, width: 2),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: AppTheme.dark),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'La zona es la que indicaste al publicar la solicitud. '
              'No es la ubicación del aliado: MANI no rastrea su posición.',
              key: Key('seguimiento-aviso-zona'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaSolicitud extends StatelessWidget {
  const _TarjetaSolicitud(
    this.solicitud, {
    this.onVerCotizacion,
    this.onVerAliados,
    this.onPresentarQueja,
    this.onCancelar,
    this.cancelando = false,
  });

  final SolicitudSeguimiento solicitud;
  final VoidCallback? onVerCotizacion;

  /// Solo para solicitudes pendientes (SCRUM-1401).
  final VoidCallback? onVerAliados;

  /// Solo para solicitudes que ya tuvieron aliado (SCRUM-895).
  final VoidCallback? onPresentarQueja;

  /// Cancela antes de la ejecución (SCRUM-877); `null` si no se puede.
  final VoidCallback? onCancelar;
  final bool cancelando;

  @override
  Widget build(BuildContext context) {
    final zona = solicitud.zonaCompleta;
    return ManiCard(
      key: Key('seguimiento-${solicitud.id}'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  solicitud.categoria,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.dark,
                  ),
                ),
              ),
              Chip(label: Text(solicitud.etiquetaEstado)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            zona.isEmpty
                ? 'Zona declarada: sin información'
                : 'Zona declarada: $zona',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estado actualizado: ${formatearFecha(solicitud.actualizadaEn)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          if (onVerCotizacion != null ||
              onVerAliados != null ||
              onPresentarQueja != null ||
              onCancelar != null ||
              cancelando) ...[
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 8,
              children: [
                if (cancelando)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.dark,
                      ),
                    ),
                  )
                else if (onCancelar != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      border: Border.all(color: AppTheme.error, width: 2),
                    ),
                    child: TextButton.icon(
                      key: Key('cancelar-solicitud-${solicitud.id}'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.error,
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancelar solicitud'),
                      onPressed: onCancelar,
                    ),
                  ),
                if (onVerAliados != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      border: Border.all(color: AppTheme.dark, width: 2),
                      boxShadow: const [AppTheme.hardShadowSm],
                    ),
                    child: TextButton.icon(
                      key: Key('ver-aliados-${solicitud.id}'),
                      icon: const Icon(Icons.groups_outlined, size: 18),
                      label: const Text('Ver aliados'),
                      onPressed: onVerAliados,
                    ),
                  ),
                // Queja sobre un servicio con aliado (SCRUM-895).
                if (onPresentarQueja != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      border: Border.all(color: AppTheme.dark, width: 2),
                      boxShadow: const [AppTheme.hardShadowSm],
                    ),
                    child: TextButton.icon(
                      key: Key('presentar-queja-${solicitud.id}'),
                      icon: const Icon(Icons.feedback_outlined, size: 18),
                      label: const Text('Presentar queja'),
                      onPressed: onPresentarQueja,
                    ),
                  ),
                if (onVerCotizacion != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      border: Border.all(color: AppTheme.dark, width: 2),
                      boxShadow: const [AppTheme.hardShadowSm],
                    ),
                    child: TextButton.icon(
                      key: Key('ver-cotizacion-${solicitud.id}'),
                      icon: const Icon(Icons.request_quote_outlined, size: 18),
                      label: const Text('Ver cotización'),
                      onPressed: onVerCotizacion,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({this.onNuevaSolicitud});

  final VoidCallback? onNuevaSolicitud;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Text('Aún no has publicado solicitudes.'),
          if (onNuevaSolicitud != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('seguimiento-nueva'),
              onPressed: onNuevaSolicitud,
              child: const Text('Publicar una solicitud'),
            ),
          ],
        ],
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
    final colores = Theme.of(context).colorScheme;
    return Card(
      color: colores.errorContainer,
      child: ListTile(
        key: const Key('seguimiento-error'),
        leading: Icon(Icons.error_outline, color: colores.onErrorContainer),
        title: Text(mensaje),
        trailing: TextButton(
          onPressed: onReintentar,
          child: const Text('Reintentar'),
        ),
      ),
    );
  }
}

const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// "26 oct 2026, 16:05" en hora local.
String formatearFecha(DateTime fecha) {
  final f = fecha.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${f.day} ${_meses[f.month - 1]} ${f.year}, ${dos(f.hour)}:${dos(f.minute)}';
}
