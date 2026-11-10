import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/network/mensaje_error_gateway.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
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
              ManiRejilla(
                anchoMinimo: 260,
                maxColumnas: 4,
                children: [
                  _Indicador(
                    'metrica-solicitudes',
                    Icons.assignment_outlined,
                    'Solicitudes creadas',
                    '${m.solicitudesCreadas}',
                  ),
                  _Indicador(
                    'metrica-finalizadas',
                    Icons.task_alt,
                    'Finalizadas',
                    '${m.finalizadas}',
                  ),
                  _Indicador(
                    'metrica-canceladas',
                    Icons.cancel_outlined,
                    'Canceladas',
                    '${m.canceladas} (${_tasa(m.tasaCancelacion)})',
                  ),
                  _Indicador(
                    'metrica-cotizaciones',
                    Icons.request_quote_outlined,
                    'Cotizaciones emitidas',
                    '${m.cotizacionesEmitidas}',
                  ),
                  _Indicador(
                    'metrica-aceptacion',
                    Icons.thumb_up_alt_outlined,
                    'Aceptación de cotizaciones',
                    _tasa(m.tasaAceptacion),
                  ),
                  _Indicador(
                    'metrica-pagos',
                    Icons.payments_outlined,
                    'Pagos aprobados',
                    '${m.pagosAprobados} · ${formatearPesos(m.montoAprobado)}',
                  ),
                  _Indicador(
                    'metrica-calificacion',
                    Icons.star_outline_rounded,
                    'Calificación promedio',
                    m.calificacionPromedio == null
                        ? 'Sin calificaciones'
                        : '${m.calificacionPromedio!.toStringAsFixed(2)} (${m.calificaciones})',
                  ),
                  _Indicador(
                    'metrica-quejas',
                    Icons.feedback_outlined,
                    'Quejas',
                    '${m.quejasRegistradas} · ${m.quejasAbiertas} abiertas',
                  ),
                  _Indicador(
                    'metrica-aliados',
                    Icons.engineering_outlined,
                    'Aliados con servicios',
                    '${m.aliadosConServicios}',
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
                  maxColumnas: 5,
                  espacio: 12,
                  children: [
                    for (final e in m.porEstado.entries)
                      ManiCard(
                        key: Key('metrica-estado-${e.key}'),
                        sombra: ManiShadow.sm,
                        padding: const EdgeInsets.symmetric(
                          horizontal: ManiSpace.lg,
                          vertical: ManiSpace.md,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: const TextStyle(
                                  fontSize: ManiFontSize.bodySm,
                                  fontWeight: FontWeight.w700,
                                  color: ManiColors.ink,
                                ),
                              ),
                            ),
                            Text(
                              '${e.value}',
                              style: const TextStyle(
                                fontSize: ManiFontSize.title,
                                fontWeight: FontWeight.w900,
                                color: ManiColors.ink,
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
  const _Indicador(this.clave, this.icono, this.etiqueta, this.valor);

  final String clave;
  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return ManiCard(
      key: Key(clave),
      padding: const EdgeInsets.all(ManiSpace.lg),
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
                    width: ManiBorder.thin,
                  ),
                ),
                child: Icon(icono, size: 16, color: ManiColors.ink),
              ),
              ManiGap.hSm,
              Expanded(
                child: Text(
                  etiqueta.toUpperCase(),
                  style: const TextStyle(
                    fontSize: ManiFontSize.micro,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: ManiColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          ManiGap.vMd,
          Text(
            valor,
            style: const TextStyle(
              fontSize: ManiFontSize.h2,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: ManiColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
