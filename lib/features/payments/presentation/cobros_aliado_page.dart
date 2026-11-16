import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/widgets/refresco_periodico.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart'
    show formatearPesos;

import '../domain/cobros.dart';
import 'cobros_aliado_cubit.dart';

/// Cobros del aliado: la retención de cada pago y, cuando el servicio finaliza,
/// su liquidación con el desglose de la comisión (SCRUM-894, US-07.2.2).
///
/// Todo es simulado: el sandbox no mueve dinero real.
class CobrosAliadoPage extends StatelessWidget {
  const CobrosAliadoPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => CobrosAliadoCubit(sl())..cargar(),
    child: const CobrosAliadoView(),
  );
}

/// Vista de la pantalla; recibe el cubit del árbol (así la prueban los tests).
///
/// Se actualiza sola mientras está a la vista (SCRUM-1710): la retención pasa
/// a liquidación sin recargar cuando el cliente paga o el servicio finaliza.
class CobrosAliadoView extends StatelessWidget {
  const CobrosAliadoView({
    super.key,
    this.intervaloRefresco = RefrescoPeriodico.intervaloPorDefecto,
  });

  /// `null` desactiva el sondeo (tests).
  final Duration? intervaloRefresco;

  static const avisoSimulado =
      'SIMULADO · Los cobros del sandbox no mueven dinero real.';

  @override
  Widget build(BuildContext context) => RefrescoPeriodico(
    intervalo: intervaloRefresco,
    onRefrescar: () =>
        context.read<CobrosAliadoCubit>().cargar(silencioso: true),
    child: _contenido(context),
  );

  Widget _contenido(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis cobros')),
      body: BlocBuilder<CobrosAliadoCubit, CobrosAliadoState>(
        builder: (context, state) {
          if (state.fase == FaseCobros.cargando) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.fase == FaseCobros.error) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.error!.mensajeUsuario,
                      key: const Key('error-cobros'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const Key('reintentar-cobros'),
                      onPressed: context.read<CobrosAliadoCubit>().cargar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(avisoSimulado, key: Key('aviso-simulado-cobros')),
              const SizedBox(height: 12),
              if (state.cobros.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Text(
                    'Aún no tienes cobros. Aparecerán cuando un cliente pague '
                    'un servicio tuyo.',
                    key: Key('cobros-vacio'),
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final c in state.cobros) _TarjetaCobro(cobro: c),
            ],
          );
        },
      ),
    );
  }
}

class _TarjetaCobro extends StatelessWidget {
  const _TarjetaCobro({required this.cobro});

  final CobroAliado cobro;

  @override
  Widget build(BuildContext context) {
    final r = cobro.retencion;
    final l = cobro.liquidacion;
    return Card(
      key: Key('cobro-${r.pagoId}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${formatearPesos(r.monto)} ${r.moneda}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(r.estado.etiqueta, key: Key('estado-${r.pagoId}')),
            if (l != null) ...[
              const Divider(),
              Text(
                'Comisión (${l.porcentajeComision.toStringAsFixed(l.porcentajeComision % 1 == 0 ? 0 : 2)} %): '
                '${formatearPesos(l.comision)}',
                key: Key('comision-${r.pagoId}'),
              ),
              Text(
                'Neto para ti: ${formatearPesos(l.montoNeto)}',
                key: Key('neto-${r.pagoId}'),
              ),
            ] else
              const Text(
                'Se liquida cuando el servicio finaliza.',
                key: Key('sin-liquidar'),
              ),
          ],
        ),
      ),
    );
  }
}
