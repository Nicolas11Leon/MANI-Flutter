import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart'
    show formatearPesos;

import '../domain/cobros.dart';
import 'cobros_aliado_cubit.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

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
class CobrosAliadoView extends StatelessWidget {
  const CobrosAliadoView({super.key});

  static const avisoSimulado =
      'SIMULADO · Los cobros del sandbox no mueven dinero real.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManiEncabezadoPantalla(
            ancho: ManiAncho.lista,
            icono: Icons.payments_rounded,
            titulo: 'Mis cobros',
          ),
          Expanded(
            child: ManiAnchoContenido(
              ancho: ManiAncho.lista,
              child: BlocBuilder<CobrosAliadoCubit, CobrosAliadoState>(
                builder: (context, state) {
                  if (state.fase == FaseCobros.cargando) {
                    return const ManiCargando();
                  }
                  if (state.fase == FaseCobros.error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(ManiSpace.xxl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.error!.mensajeUsuario,
                              key: const Key('error-cobros'),
                              textAlign: TextAlign.center,
                            ),
                            ManiGap.vMd,
                            OutlinedButton(
                              key: const Key('reintentar-cobros'),
                              onPressed: context
                                  .read<CobrosAliadoCubit>()
                                  .cargar,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(ManiSpace.lg),
                    children: [
                      const Text(
                        avisoSimulado,
                        key: Key('aviso-simulado-cobros'),
                      ),
                      ManiGap.vMd,
                      if (state.cobros.isEmpty)
                        const ManiEstadoVacio(
                          key: Key('cobros-vacio'),
                          icono: Icons.payments_outlined,
                          titulo: 'Aún no tienes cobros.',
                          texto:
                              'Aparecerán cuando un cliente pague un servicio tuyo.',
                        ),
                      for (final c in state.cobros) _TarjetaCobro(cobro: c),
                    ],
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

class _TarjetaCobro extends StatelessWidget {
  const _TarjetaCobro({required this.cobro});

  final CobroAliado cobro;

  @override
  Widget build(BuildContext context) {
    final r = cobro.retencion;
    final l = cobro.liquidacion;
    return Card(
      key: Key('cobro-${r.pagoId}'),
      margin: const EdgeInsets.only(bottom: ManiSpace.md),
      child: Padding(
        padding: const EdgeInsets.all(ManiSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${formatearPesos(r.monto)} ${r.moneda}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ManiGap.vXs,
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
