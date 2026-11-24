import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

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
        // La calificación del otro participante es privada: Core no la
        // envía y la app solo indica si ya existe (el cierre lo necesita).
        final otroYaCalifico =
            resumen != null &&
            (widget.esAliado
                ? resumen.cierre.tieneCalificacionCliente
                : resumen.cierre.tieneCalificacionAliado);
        final contraparte = widget.esAliado ? 'El cliente' : 'El aliado';

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
                      color: context.mani.brand,
                      borderRadius: ManiRadius.brSm,
                      border: Border.all(
                        color: context.mani.border,
                        width: ManiBorder.regular,
                      ),
                      boxShadow: const [ManiShadow.sm],
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      color: context.mani.onBrand,
                      size: 20,
                    ),
                  ),
                  ManiGap.hMd,
                  Expanded(
                    child: Text(
                      widget.esAliado
                          ? 'Calificar al cliente y estado de cierre'
                          : 'Calificar al aliado y estado de cierre',
                      style: TextStyle(
                        fontSize: ManiFontSize.bodyLg,
                        fontWeight: FontWeight.w900,
                        color: context.mani.ink,
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
              const Divider(height: 24),
              // La calificación del otro participante es privada (SCRUM-1418): solo se dice si ya existe.
              Text(
                otroYaCalifico
                    ? '$contraparte ya registró su calificación.'
                    : '$contraparte aún no ha calificado.',
                key: Key(
                  otroYaCalifico
                      ? 'm08-otra-calificacion-registrada'
                      : 'm08-otra-calificacion-pendiente',
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: context.mani.ink,
                ),
              ),
              ManiGap.vXs,
              Text(
                'Las calificaciones son privadas: ni tú ves la que te dan ni '
                'la otra parte ve la tuya. Solo el administrador puede verlas.',
                key: Key('m08-aviso-calificacion-privada'),
                style: TextStyle(
                  fontSize: ManiFontSize.caption,
                  color: context.mani.inkMuted,
                ),
              ),
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
        color: completo ? ManiColors.successContainer : context.mani.brandSoft,
        borderRadius: ManiRadius.brMd,
        border: Border.all(
          color: context.mani.border,
          width: ManiBorder.regular,
        ),
      ),
      child: Row(
        children: [
          Icon(
            completo
                ? Icons.verified_outlined
                : Icons.hourglass_bottom_outlined,
            color: context.mani.ink,
          ),
          ManiGap.hSm,
          Expanded(
            child: Text(
              cierre.etiquetaEstadoCierre,
              key: const Key('m08-estado-cierre-texto'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.mani.ink,
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
            style: TextStyle(
              color: context.mani.ink,
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
          color: context.mani.background,
          borderRadius: ManiRadius.brMd,
          border: Border.all(
            color: context.mani.border,
            width: ManiBorder.thin,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu calificación enviada: ★ ${calif.puntaje}/5',
              key: const Key('m08-mi-calificacion-registrada'),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: context.mani.ink,
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
        Text(
          'Selecciona un puntaje de 1 a 5 estrellas:',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: context.mani.ink,
          ),
        ),
        ManiGap.vSm,
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                key: Key('m08-estrella-$i'),
                icon: Icon(
                  i <= puntajeSeleccionado ? Icons.star : Icons.star_border,
                  color: context.mani.ink,
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
  const HistorialServiciosPage({
    super.key,
    this.onAbrirServicio,
    this.embebido = false,
  });

  /// Abre la pantalla del servicio (cotización, ejecución y calificación).
  final void Function(String solicitudId)? onAbrirServicio;

  /// Si es `true`, se muestra como panel lateral o sección embebida dentro de
  /// otra pantalla (como «Mis solicitudes»).
  final bool embebido;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return BlocBuilder<HistorialServiciosCubit, HistorialServiciosState>(
      builder: (context, state) {
        final cubit = context.read<HistorialServiciosCubit>();
        final titulo = cubit.esAliado
            ? 'Historial de trabajos'
            : 'Historial de servicios';
        final textoVacio = cubit.esAliado
            ? 'Sin trabajos asignados en tu historial.'
            : 'Sin servicios registrados en tu historial.';

        final cuerpoItems = <Widget>[
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: ManiSpace.md),
              child: Text(
                state.error!,
                key: const Key('m08-historial-error'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (state.cargando && state.registros.isEmpty)
            const ManiCargando()
          else if (state.registros.isEmpty)
            ManiCard(
              color: t.surfaceMuted,
              sombra: t.shadowSm,
              padding: const EdgeInsets.all(ManiSpace.xl),
              child: Text(
                textoVacio,
                key: const Key('m08-historial-vacio'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: t.inkMuted,
                ),
              ),
            )
          else
            for (final item in state.registros) ...[
              _TarjetaHistorialItem(
                item: item,
                esAliado: cubit.esAliado,
                onAbrir: onAbrirServicio == null
                    ? null
                    : () => onAbrirServicio!(item.id),
              ),
              ManiGap.vMd,
            ],
        ];

        if (embebido) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ManiTituloSeccion(
                icono: Icons.history_rounded,
                titulo: titulo,
                accion: IconButton(
                  tooltip: 'Actualizar historial',
                  onPressed: state.cargando ? null : cubit.cargar,
                  icon: Icon(Icons.refresh_rounded, size: 18, color: t.ink),
                ),
              ),
              ManiGap.vMd,
              ...cuerpoItems,
            ],
          );
        }

        return ColoredBox(
          color: t.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ManiEncabezadoPantalla(
                icono: Icons.history_rounded,
                titulo: titulo,
                tituloKey: const Key('m08-historial-titulo'),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ManiAncho.panel,
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(ManiSpace.xxl),
                      children: cuerpoItems,
                    ),
                  ),
                ),
              ),
            ],
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
    final t = context.mani;
    final etiquetaContraparte = esAliado ? 'Cliente' : 'Aliado';
    return ManiCard(
      key: Key('m08-historial-item-${item.id}'),
      sombra: t.shadowSm,
      padding: const EdgeInsets.all(ManiSpace.lg),
      onTap: onAbrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.categoria,
                  style: TextStyle(
                    fontSize: ManiFontSize.bodyLg,
                    fontWeight: FontWeight.w900,
                    color: t.ink,
                  ),
                ),
              ),
              Chip(
                key: Key('m08-historial-estado-${item.id}'),
                label: Text(item.estado),
              ),
            ],
          ),
          ManiGap.vXs,
          Text(item.descripcion, style: TextStyle(color: t.ink)),
          ManiGap.vXxs,
          Text(
            'Zona: ${item.zona} · Dirección: ${item.direccion}',
            style: TextStyle(fontSize: ManiFontSize.bodySm, color: t.inkMuted),
          ),
          if (item.nombreContraparte != null)
            Text(
              '$etiquetaContraparte: ${item.nombreContraparte}',
              style: TextStyle(
                fontSize: ManiFontSize.bodySm,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          if (item.valorTotal != null)
            Text(
              'Valor total: \$${item.valorTotal!.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: ManiFontSize.bodySm,
                fontWeight: FontWeight.w800,
                color: t.ink,
              ),
            ),
          if (item.penalizacionAplicada)
            Text(
              'Penalización aplicada: \$${item.penalizacionMonto.toStringAsFixed(0)}',
              key: Key('m08-historial-penalizacion-${item.id}'),
              style: const TextStyle(
                fontSize: ManiFontSize.bodySm,
                fontWeight: FontWeight.w700,
                color: ManiColors.dangerText,
              ),
            ),
          if (item.calificacionEmitida != null)
            Text(
              'Calificación emitida: ★ ${item.calificacionEmitida!.puntaje}/5',
              style: TextStyle(fontSize: ManiFontSize.bodySm, color: t.ink),
            ),
          // La calificación recibida es privada (SCRUM-1418): solo se indica si existe.
          if (item.calificacionRecibidaRegistrada)
            Text(
              '${esAliado ? 'El cliente' : 'El aliado'} ya te calificó (privada)',
              key: Key('m08-historial-recibida-${item.id}'),
              style: TextStyle(fontSize: ManiFontSize.bodySm, color: t.ink),
            ),
          if (onAbrir != null) ...[
            ManiGap.vSm,
            Align(
              alignment: Alignment.centerRight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.brand,
                  borderRadius: ManiRadius.brMd,
                  border: Border.all(color: t.border, width: ManiBorder.thin),
                  boxShadow: [t.shadowSm],
                ),
                child: TextButton.icon(
                  key: Key('m08-historial-abrir-${item.id}'),
                  icon: Icon(Icons.open_in_new, size: 16, color: t.onBrand),
                  label: Text(
                    estadosCalificables.contains(item.estado.toUpperCase()) &&
                            item.calificacionEmitida == null
                        ? 'Calificar servicio'
                        : 'Ver servicio',
                    style: TextStyle(
                      color: t.onBrand,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: onAbrir,
                ),
              ),
            ),
          ],
        ],
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
            ? context.mani.brandSoft
            : context.mani.surface,
        borderRadius: ManiRadius.brMd,
        border: Border.all(
          color: context.mani.border,
          width: ManiBorder.regular,
        ),
        boxShadow: const [ManiShadow.sm],
      ),
      child: Text(
        preview.resumenUsuario,
        key: const Key('m08-penalizacion-preview-texto'),
        style: TextStyle(fontWeight: FontWeight.w800, color: context.mani.ink),
      ),
    );
  }
}
