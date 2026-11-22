import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/network/mensaje_error_gateway.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart'
    show formatearPesos;
import 'package:mani/features/tariffs/presentation/reporte_fuera_rango_page.dart'
    show fechaIso;

import '../data/metricas_datasource.dart';

class MetricasState extends Equatable {
  const MetricasState({
    required this.desde,
    required this.hasta,
    this.cargando = false,
    this.metricas,
    this.error,
  });

  final DateTime desde;
  final DateTime hasta;
  final bool cargando;
  final MetricasOperativas? metricas;
  final String? error;

  @override
  List<Object?> get props => [desde, hasta, cargando, metricas, error];
}

/// Métricas operativas del tenant (HU-M12-06 / SCRUM-900). Por omisión, el mes
/// en curso. Solo muestra lo que devuelve Core para el tenant de la sesión.
class MetricasCubit extends Cubit<MetricasState> {
  MetricasCubit(this._fuente, {DateTime? hoy})
    : super(
        MetricasState(
          desde: DateTime(
            (hoy ?? DateTime.now()).year,
            (hoy ?? DateTime.now()).month,
          ),
          hasta: hoy ?? DateTime.now(),
        ),
      );

  final FuenteMetricas _fuente;

  void periodo(DateTime desde, DateTime hasta) =>
      emit(MetricasState(desde: desde, hasta: hasta, metricas: state.metricas));

  Future<void> consultar() async {
    emit(
      MetricasState(
        desde: state.desde,
        hasta: state.hasta,
        cargando: true,
        metricas: state.metricas,
      ),
    );
    try {
      final m = await _fuente.consultar(
        fechaIso(state.desde),
        fechaIso(state.hasta),
      );
      emit(MetricasState(desde: state.desde, hasta: state.hasta, metricas: m));
    } catch (e) {
      emit(
        MetricasState(
          desde: state.desde,
          hasta: state.hasta,
          error: mensajeErrorGateway(e),
        ),
      );
    }
  }
}

String _tasa(double? t) =>
    t == null ? '—' : '${(t * 100).toStringAsFixed(1)} %';

class MetricasPage extends StatelessWidget {
  const MetricasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return BlocBuilder<MetricasCubit, MetricasState>(
      builder: (context, state) {
        final cubit = context.read<MetricasCubit>();
        final m = state.metricas;
        return ManiPagina(
          encabezado: ManiEncabezadoPantalla(
            icono: Icons.insights_outlined,
            titulo: 'Métricas operativas',
            descripcion:
                'Indicadores de tu empresa en el periodo elegido (fechas de '
                'Colombia, inclusive).',
            acciones: [
              Wrap(
                spacing: ManiSpace.sm,
                runSpacing: ManiSpace.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ManiBotonPildora(
                    key: const Key('metricas-periodo'),
                    icono: Icons.date_range,
                    etiqueta:
                        '${fechaIso(state.desde)} a ${fechaIso(state.hasta)}',
                    onPressed: () async {
                      final rango = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDateRange: DateTimeRange(
                          start: state.desde,
                          end: state.hasta,
                        ),
                      );
                      if (rango != null) {
                        cubit.periodo(rango.start, rango.end);
                      }
                    },
                  ),
                  ManiButton(
                    key: const Key('metricas-consultar'),
                    etiqueta: 'Consultar',
                    icono: Icons.search,
                    cargando: state.cargando,
                    onPressed: state.cargando ? null : cubit.consultar,
                  ),
                ],
              ),
            ],
          ),
          children: [
            if (state.error != null)
              ManiAvisoTarjeta(
                key: const Key('metricas-error'),
                icono: Icons.error_outline,
                texto: state.error!,
                esError: true,
              )
            else if (m == null)
              const ManiAvisoTarjeta(
                icono: Icons.touch_app_outlined,
                texto: 'Elige el periodo y pulsa «Consultar».',
              )
            else ...[
              if (m.solicitudesCreadas == 0 && m.cotizacionesEmitidas == 0) ...[
                const ManiAvisoTarjeta(
                  key: Key('metricas-sin-datos'),
                  icono: Icons.info_outline,
                  texto: 'No hubo actividad en el periodo',
                ),
                ManiGap.vXl,
              ],
              const ManiTituloSeccion(
                icono: Icons.dashboard_outlined,
                titulo: 'Indicadores del periodo',
              ),
              ManiGap.vLg,
              // Nivel 1: KPIs primarios de volumen e ingresos
              ManiRejilla(
                anchoMinimo: 280,
                maxColumnas: 3,
                children: [
                  _Indicador(
                    clave: 'metrica-solicitudes',
                    icono: Icons.assignment_outlined,
                    etiqueta: 'Solicitudes creadas',
                    valor: '${m.solicitudesCreadas}',
                    tono: ManiTono.marca,
                    destacado: true,
                  ),
                  _Indicador(
                    clave: 'metrica-finalizadas',
                    icono: Icons.task_alt,
                    etiqueta: 'Finalizadas',
                    valor: '${m.finalizadas}',
                    tono: ManiTono.exito,
                    destacado: true,
                  ),
                  _Indicador(
                    clave: 'metrica-pagos',
                    icono: Icons.payments_outlined,
                    etiqueta: 'Pagos aprobados',
                    valor:
                        '${m.pagosAprobados} · ${formatearPesos(m.montoAprobado)}',
                    tono: ManiTono.info,
                    destacado: true,
                  ),
                ],
              ),
              ManiGap.vLg,
              // Nivel 2: Conversión, red de aliados, calidad e incidencias
              ManiRejilla(
                anchoMinimo: 260,
                maxColumnas: 3,
                children: [
                  _Indicador(
                    clave: 'metrica-cotizaciones',
                    icono: Icons.request_quote_outlined,
                    etiqueta: 'Cotizaciones emitidas',
                    valor: '${m.cotizacionesEmitidas}',
                    tono: ManiTono.neutro,
                  ),
                  _Indicador(
                    clave: 'metrica-aceptacion',
                    icono: Icons.thumb_up_alt_outlined,
                    etiqueta: 'Aceptación de cotizaciones',
                    valor: _tasa(m.tasaAceptacion),
                    tono: ManiTono.acento,
                  ),
                  _Indicador(
                    clave: 'metrica-aliados',
                    icono: Icons.engineering_outlined,
                    etiqueta: 'Aliados con servicios',
                    valor: '${m.aliadosConServicios}',
                    tono: ManiTono.info,
                  ),
                  _Indicador(
                    clave: 'metrica-calificacion',
                    icono: Icons.star_outline_rounded,
                    etiqueta: 'Calificación promedio',
                    valor: m.calificacionPromedio == null
                        ? 'Sin calificaciones'
                        : '${m.calificacionPromedio!.toStringAsFixed(2)} (${m.calificaciones})',
                    tono: ManiTono.marca,
                  ),
                  _Indicador(
                    clave: 'metrica-canceladas',
                    icono: Icons.cancel_outlined,
                    etiqueta: 'Canceladas',
                    valor: '${m.canceladas} (${_tasa(m.tasaCancelacion)})',
                    tono: m.canceladas > 0 ? ManiTono.aviso : ManiTono.neutro,
                  ),
                  _Indicador(
                    clave: 'metrica-quejas',
                    icono: Icons.feedback_outlined,
                    etiqueta: 'Quejas',
                    valor:
                        '${m.quejasRegistradas} · ${m.quejasAbiertas} abiertas',
                    tono: m.quejasAbiertas > 0
                        ? ManiTono.peligro
                        : ManiTono.neutro,
                  ),
                ],
              ),
              if (m.porEstado.isNotEmpty) ...[
                ManiGap.vXxl,
                const ManiTituloSeccion(
                  icono: Icons.donut_small_outlined,
                  titulo: 'Solicitudes por estado',
                ),
                ManiGap.vLg,
                ManiRejilla(
                  anchoMinimo: 220,
                  maxColumnas: 4,
                  espacio: 14,
                  children: [
                    for (final e in m.porEstado.entries)
                      ManiCard(
                        key: Key('metrica-estado-${e.key}'),
                        sombra: t.shadowSm,
                        padding: const EdgeInsets.symmetric(
                          horizontal: ManiSpace.lg,
                          vertical: ManiSpace.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    e.key,
                                    style: TextStyle(
                                      fontSize: ManiFontSize.bodySm,
                                      fontWeight: FontWeight.w800,
                                      color: t.ink,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: ManiSpace.sm,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.brandSoft,
                                    borderRadius: ManiRadius.brSm,
                                    border: Border.all(
                                      color: t.border,
                                      width: ManiBorder.thin,
                                    ),
                                  ),
                                  child: Text(
                                    '${e.value}',
                                    style: TextStyle(
                                      fontSize: ManiFontSize.body,
                                      fontWeight: FontWeight.w900,
                                      color: t.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ManiGap.vSm,
                            ClipRRect(
                              borderRadius: ManiRadius.brPill,
                              child: LinearProgressIndicator(
                                minHeight: 6,
                                value: m.solicitudesCreadas > 0
                                    ? (e.value / m.solicitudesCreadas).clamp(
                                        0.0,
                                        1.0,
                                      )
                                    : 0.0,
                                backgroundColor: t.surfaceMuted,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  t.brand,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.clave,
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.tono = ManiTono.marca,
    this.destacado = false,
  });

  final String clave;
  final IconData icono;
  final String etiqueta;
  final String valor;
  final ManiTono tono;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return ManiCard(
      key: Key(clave),
      color: destacado ? t.surface : t.surfaceMuted,
      sombra: destacado ? t.shadow : t.shadowSm,
      padding: const EdgeInsets.all(ManiSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ManiSpace.sm),
                decoration: BoxDecoration(
                  color: destacado ? t.brand : tono.fondo,
                  borderRadius: ManiRadius.brSm,
                  border: Border.all(color: t.border, width: ManiBorder.thin),
                ),
                child: Icon(
                  icono,
                  size: 18,
                  color: destacado ? t.onBrand : tono.texto,
                ),
              ),
              ManiGap.hSm,
              Expanded(
                child: Text(
                  etiqueta.toUpperCase(),
                  style: TextStyle(
                    fontSize: ManiFontSize.micro,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: t.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          ManiGap.vMd,
          Text(
            valor,
            style: TextStyle(
              fontSize: destacado ? ManiFontSize.h1 : ManiFontSize.h2,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: t.ink,
            ),
          ),
        ],
      ),
    );
  }
}
