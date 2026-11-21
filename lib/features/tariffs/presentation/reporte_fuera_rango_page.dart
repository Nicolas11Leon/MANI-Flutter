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

import '../data/tarifas_datasource.dart';
import '../domain/tarifa.dart';

String fechaIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ReporteFueraDeRangoState extends Equatable {
  const ReporteFueraDeRangoState({
    required this.desde,
    required this.hasta,
    this.cargando = false,
    this.reporte,
    this.error,
  });

  final DateTime desde;
  final DateTime hasta;
  final bool cargando;
  final ReporteFueraDeRango? reporte;
  final String? error;

  @override
  List<Object?> get props => [desde, hasta, cargando, reporte, error];
}

/// Reporte de cotizaciones fuera de rango (HU-M10-03 / SCRUM-887). Por omisión
/// consulta los últimos 30 días. La evaluación la hace Rules en Core; si Rules
/// no responde, el error se muestra y no se calcula nada en la app (C2).
class ReporteFueraDeRangoCubit extends Cubit<ReporteFueraDeRangoState> {
  ReporteFueraDeRangoCubit(this._fuente, {DateTime? hoy})
    : super(
        ReporteFueraDeRangoState(
          desde: (hoy ?? DateTime.now()).subtract(const Duration(days: 29)),
          hasta: hoy ?? DateTime.now(),
        ),
      );

  final FuenteTarifas _fuente;

  void periodo(DateTime desde, DateTime hasta) => emit(
    ReporteFueraDeRangoState(
      desde: desde,
      hasta: hasta,
      reporte: state.reporte,
    ),
  );

  Future<void> consultar() async {
    emit(
      ReporteFueraDeRangoState(
        desde: state.desde,
        hasta: state.hasta,
        cargando: true,
        reporte: state.reporte,
      ),
    );
    try {
      final reporte = await _fuente.reporteFueraDeRango(
        fechaIso(state.desde),
        fechaIso(state.hasta),
      );
      emit(
        ReporteFueraDeRangoState(
          desde: state.desde,
          hasta: state.hasta,
          reporte: reporte,
        ),
      );
    } catch (e) {
      emit(
        ReporteFueraDeRangoState(
          desde: state.desde,
          hasta: state.hasta,
          error: mensajeErrorGateway(e),
        ),
      );
    }
  }
}

class ReporteFueraDeRangoPage extends StatelessWidget {
  const ReporteFueraDeRangoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return BlocBuilder<ReporteFueraDeRangoCubit, ReporteFueraDeRangoState>(
      builder: (context, state) {
        final cubit = context.read<ReporteFueraDeRangoCubit>();
        final reporte = state.reporte;
        return ColoredBox(
          color: t.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ManiEncabezadoPantalla(
                ancho: ManiAncho.lista,
                icono: Icons.trending_up_rounded,
                titulo: 'Cotizaciones fuera de rango',
                descripcion:
                    'Cotizaciones del periodo que el motor de reglas evaluó por '
                    'debajo o por encima de la tarifa de referencia que regía.',
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ManiAncho.lista,
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(ManiSpace.xl),
                      children: [
                        Wrap(
                          spacing: ManiSpace.sm,
                          runSpacing: ManiSpace.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              key: const Key('reporte-periodo'),
                              icon: const Icon(Icons.date_range),
                              label: Text(
                                '${fechaIso(state.desde)} a ${fechaIso(state.hasta)}',
                              ),
                              onPressed: () async {
                                final rango = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 1),
                                  ),
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
                              key: const Key('reporte-consultar'),
                              etiqueta: 'Consultar',
                              icono: Icons.search,
                              cargando: state.cargando,
                              onPressed: state.cargando
                                  ? null
                                  : cubit.consultar,
                            ),
                          ],
                        ),
                        ManiGap.vLg,
                        if (state.error != null)
                          Card(
                            key: const Key('reporte-error'),
                            child: ListTile(
                              leading: const Icon(Icons.error_outline),
                              title: Text(state.error!),
                            ),
                          )
                        else if (reporte != null) ...[
                          ManiCard(
                            color: t.surfaceMuted,
                            sombra: t.shadowSm,
                            padding: const EdgeInsets.symmetric(
                              horizontal: ManiSpace.lg,
                              vertical: ManiSpace.md,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.analytics_outlined,
                                  size: 20,
                                  color: t.ink,
                                ),
                                ManiGap.hSm,
                                Expanded(
                                  child: Text(
                                    '${reporte.totalCotizaciones} cotizaciones · '
                                    '${reporte.evaluadas} evaluadas · '
                                    '${reporte.sinTarifa} sin tarifa · '
                                    '${reporte.cotizaciones.length} fuera de rango',
                                    key: const Key('reporte-totales'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: t.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ManiGap.vLg,
                          if (reporte.cotizaciones.isEmpty)
                            const ManiEstadoVacio(
                              key: Key('reporte-vacio'),
                              icono: Icons.check_circle_outline,
                              titulo:
                                  'No hay cotizaciones fuera de rango en el periodo',
                            )
                          else
                            for (final c in reporte.cotizaciones) ...[
                              ManiCard(
                                key: Key('reporte-cotizacion-${c.id}'),
                                sombra: t.shadowSm,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ManiSpace.lg,
                                  vertical: ManiSpace.sm,
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: ManiColors.dangerContainer,
                                      borderRadius: ManiRadius.brSm,
                                      border: Border.all(
                                        color: t.border,
                                        width: ManiBorder.thin,
                                      ),
                                    ),
                                    child: Icon(
                                      c.porEncima
                                          ? Icons.arrow_upward_rounded
                                          : Icons.arrow_downward_rounded,
                                      color: ManiColors.dangerText,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    '${c.categoria} · ${formatearPesos(c.total)} '
                                    '(${c.porEncima ? 'por encima' : 'por debajo'} '
                                    '${c.desviacionPorcentaje.toStringAsFixed(2)} %)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: t.ink,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Aliado: ${c.aliado} · Rango v${c.tarifaVersion}: '
                                    '${formatearPesos(c.tarifaMin)} – ${formatearPesos(c.tarifaMax)}',
                                    style: TextStyle(color: t.inkMuted),
                                  ),
                                ),
                              ),
                              ManiGap.vMd,
                            ],
                        ],
                      ],
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
