import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/network/mensaje_error_gateway.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart'
    show formatearPesos;

import '../data/tarifas_datasource.dart';
import '../domain/tarifa.dart';
import 'package:mani/core/theme/app_theme.dart';

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
    return BlocBuilder<ReporteFueraDeRangoCubit, ReporteFueraDeRangoState>(
      builder: (context, state) {
        final cubit = context.read<ReporteFueraDeRangoCubit>();
        final tema = Theme.of(context).textTheme;
        final reporte = state.reporte;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(ManiSpace.lg),
              children: [
                Text('Cotizaciones fuera de rango', style: tema.headlineSmall),
                ManiGap.vXs,
                const Text(
                  'Cotizaciones del periodo que el motor de reglas evaluó por '
                  'debajo o por encima de la tarifa de referencia que regía.',
                ),
                ManiGap.vMd,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                      key: const Key('reporte-consultar'),
                      etiqueta: 'Consultar',
                      icono: Icons.search,
                      cargando: state.cargando,
                      onPressed: state.cargando ? null : cubit.consultar,
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
                  Text(
                    '${reporte.totalCotizaciones} cotizaciones · '
                    '${reporte.evaluadas} evaluadas · '
                    '${reporte.sinTarifa} sin tarifa · '
                    '${reporte.cotizaciones.length} fuera de rango',
                    key: const Key('reporte-totales'),
                  ),
                  ManiGap.vSm,
                  if (reporte.cotizaciones.isEmpty)
                    const Card(
                      key: Key('reporte-vacio'),
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text(
                          'No hay cotizaciones fuera de rango en el periodo',
                        ),
                      ),
                    )
                  else
                    for (final c in reporte.cotizaciones)
                      Card(
                        key: Key('reporte-cotizacion-${c.id}'),
                        child: ListTile(
                          leading: Icon(
                            c.porEncima
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          title: Text(
                            '${c.categoria} · ${formatearPesos(c.total)} '
                            '(${c.porEncima ? 'por encima' : 'por debajo'} '
                            '${c.desviacionPorcentaje.toStringAsFixed(2)} %)',
                          ),
                          subtitle: Text(
                            'Aliado: ${c.aliado} · Rango v${c.tarifaVersion}: '
                            '${formatearPesos(c.tarifaMin)} – ${formatearPesos(c.tarifaMax)}',
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
