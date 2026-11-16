import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/shell/app_shell.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_esqueleto.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_estados.dart';
import 'package:mani/core/widgets/mani_layout.dart';
import 'package:mani/core/widgets/mani_personaje.dart';
import 'package:mani/features/services/ratings/data/calificacion_cierre_datasource.dart';
import 'package:mani/features/services/ratings/domain/calificacion_cierre_modelos.dart';
import 'package:mani/features/services/ratings/presentation/calificacion_cierre_cubit.dart';
import 'package:mani/features/services/ratings/presentation/calificacion_cierre_widgets.dart';

import '../domain/solicitud_seguimiento.dart';
import 'mis_solicitudes_cubit.dart';

/// Mis solicitudes (HU-M07-04 / SCRUM-871): estado vigente y zona declarada
/// de cada solicitud del cliente. No muestra la ubicación del aliado ni se
/// actualiza sola: el cliente consulta de nuevo con «Actualizar».
class MisSolicitudesPage extends StatelessWidget {
  const MisSolicitudesPage({
    super.key,
    this.onNuevaSolicitud,
    this.onVerCotizacion,
    this.onVerAliados,
    this.onPresentarQueja,
    this.previsualizarCancelacion,
  });

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
  Widget build(BuildContext context) {
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
                  if (MediaQuery.sizeOf(context).width < anchoMenuExpandido &&
                      sl.isRegistered<FuenteModuloM08>())
                    TituloDePantalla(
                      titulo: 'Mis pedidos',
                      acciones: [
                        AccionDePantalla(
                          clave: const Key('seguimiento-ver-historial'),
                          icono: Icons.history,
                          etiqueta: 'Historial',
                          alTocar: () => _abrirHistorial(context),
                        ),
                      ],
                    ),
                  _Encabezado(state: state, onActualizar: cubit.cargar),
                  const SizedBox(height: 14),
                  const _AvisoZona(),
                  const SizedBox(height: 16),
                  if (state.error != null)
                    _Error(
                      mensaje: state.error!,
                      onReintentar: cubit.cargar,
                      conLista: state.solicitudes.isNotEmpty,
                    ),
                  if (state.cargando && state.solicitudes.isEmpty)
                    ManiEsqueleto.lista()
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
        ManiButton(
          key: const Key('cancelar-volver'),
          etiqueta: 'Volver',
          variante: ManiButtonVariante.secundario,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ManiButton(
          key: const Key('cancelar-confirmar'),
          etiqueta: 'Sí, cancelar',
          variante: ManiButtonVariante.peligro,
          onPressed: () => Navigator.of(context).pop(_motivo.text.trim()),
        ),
      ],
    );
  }
}

/// El historial de servicios del cliente, en un diálogo.
void _abrirHistorial(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: BlocProvider(
          create: (_) =>
              HistorialServiciosCubit(sl<FuenteModuloM08>(), esAliado: false)
                ..cargar(),
          child: const HistorialServiciosPage(),
        ),
      ),
    ),
  );
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.state, required this.onActualizar});

  final MisSolicitudesState state;
  final Future<void> Function() onActualizar;

  @override
  Widget build(BuildContext context) {
    final consultado = state.consultadoEn;
    // En celular el título y «Historial» viven en la barra del armazón; «Actualizar» sobra (se desliza para
    // actualizar). Solo queda el dato de cuándo se consultó.
    if (MediaQuery.sizeOf(context).width < anchoMenuExpandido) {
      if (consultado == null) return const SizedBox.shrink();
      return Text(
        'Consultado: ${formatearFecha(consultado)}',
        key: const Key('seguimiento-consultado'),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      );
    }
    return ManiCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          const ManiIconoCaja(
            icono: Icons.list_alt_rounded,
            forma: ManiIconoForma.fuerte,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mis pedidos',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
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
                  onPressed: () => _abrirHistorial(context),
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

/// Aviso de que la zona es la que declaró el cliente. Es una franja plana que se puede cerrar y no vuelve mientras dure
/// la sesión.
class _AvisoZona extends StatefulWidget {
  const _AvisoZona();

  @override
  State<_AvisoZona> createState() => _AvisoZonaState();
}

class _AvisoZonaState extends State<_AvisoZona> {
  static bool _cerrado = false;

  @override
  Widget build(BuildContext context) {
    if (_cerrado) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppTheme.avisoFondo,
        borderRadius: BorderRadius.circular(AppTheme.radiusIcon),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppTheme.avisoTexto),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'La zona es la que indicaste al publicar la solicitud. '
              'No es la ubicación del aliado: MANI no rastrea su posición.',
              key: Key('seguimiento-aviso-zona'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.avisoTexto,
              ),
            ),
          ),
          IconButton(
            key: const Key('seguimiento-aviso-zona-cerrar'),
            tooltip: 'Cerrar aviso',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => setState(() => _cerrado = true),
            icon: const Icon(Icons.close, size: 20, color: AppTheme.avisoTexto),
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
              const ManiIconoCaja(icono: Icons.handyman_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  solicitud.categoria,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ManiEstado(
                texto: solicitud.etiquetaEstado,
                tono: _tonoDe(solicitud.estado),
              ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
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
                  ),
                // Una sola acción principal según el estado.
                if (onVerCotizacion != null)
                  ManiButton(
                    key: Key('ver-cotizacion-${solicitud.id}'),
                    etiqueta: 'Ver cotización',
                    icono: Icons.request_quote_outlined,
                    onPressed: onVerCotizacion,
                  )
                else if (onVerAliados != null)
                  ManiButton(
                    key: Key('ver-aliados-${solicitud.id}'),
                    etiqueta: 'Ver aliados',
                    icono: Icons.groups_outlined,
                    variante: ManiButtonVariante.secundario,
                    onPressed: onVerAliados,
                  ),
                if (!cancelando &&
                    (onCancelar != null || onPresentarQueja != null))
                  PopupMenuButton<VoidCallback>(
                    key: Key('menu-solicitud-${solicitud.id}'),
                    tooltip: 'Más opciones',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (accion) => accion(),
                    itemBuilder: (_) => [
                      if (onPresentarQueja != null)
                        PopupMenuItem(
                          key: Key('presentar-queja-${solicitud.id}'),
                          value: onPresentarQueja!,
                          child: const Text('Presentar queja'),
                        ),
                      if (onCancelar != null)
                        PopupMenuItem(
                          key: Key('cancelar-solicitud-${solicitud.id}'),
                          value: onCancelar!,
                          child: const Text(
                            'Cancelar solicitud',
                            style: TextStyle(
                              color: AppTheme.errorStrong,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

ManiTono _tonoDe(EstadoSeguimiento estado) => switch (estado) {
  EstadoSeguimiento.pendiente => ManiTono.atencion,
  EstadoSeguimiento.asignada ||
  EstadoSeguimiento.cotizando ||
  EstadoSeguimiento.aceptada ||
  EstadoSeguimiento.enEjecucion => ManiTono.enCurso,
  EstadoSeguimiento.finalizada => ManiTono.listo,
  EstadoSeguimiento.rechazada || EstadoSeguimiento.cancelada => ManiTono.mal,
  EstadoSeguimiento.otro => ManiTono.neutro,
};

class _Vacio extends StatelessWidget {
  const _Vacio({this.onNuevaSolicitud});

  final VoidCallback? onNuevaSolicitud;

  @override
  Widget build(BuildContext context) {
    return ManiEstadoVacio(
      pose: PoseMani.buscando,
      titulo: 'Aún no tienes pedidos',
      texto: 'Cuéntanos qué necesitas y te conectamos con un aliado.',
      accion: onNuevaSolicitud == null
          ? null
          : ManiButton(
              key: const Key('seguimiento-nueva'),
              etiqueta: 'Pedir un servicio',
              onPressed: onNuevaSolicitud,
            ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({
    required this.mensaje,
    required this.onReintentar,
    required this.conLista,
  });

  final String mensaje;
  final Future<void> Function() onReintentar;

  /// Si ya hay pedidos en pantalla, el error es una franja y no una pantalla de error: no los empuja fuera de la vista.
  final bool conLista;

  @override
  Widget build(BuildContext context) {
    if (!conLista) {
      return KeyedSubtree(
        key: const Key('seguimiento-error'),
        child: ManiEstadoError(texto: mensaje, alReintentar: onReintentar),
      );
    }
    return Container(
      key: const Key('seguimiento-error'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppTheme.errorLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusIcon),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: AppTheme.errorStrong,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.errorStrong,
              ),
            ),
          ),
          ManiButton(
            etiqueta: 'Reintentar',
            variante: ManiButtonVariante.texto,
            onPressed: onReintentar,
          ),
        ],
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
