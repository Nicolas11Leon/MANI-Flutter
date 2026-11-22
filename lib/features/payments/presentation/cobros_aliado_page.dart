import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';
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
    final t = context.mani;
    return Scaffold(
      backgroundColor: t.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ManiEncabezadoPantalla(
            ancho: ManiAncho.lista,
            icono: Icons.payments_rounded,
            titulo: 'Mis cobros',
            descripcion:
                'Seguimiento de retenciones, comisiones y liquidaciones netas.',
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
                              style: TextStyle(
                                color: t.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            ManiGap.vMd,
                            ManiButton(
                              key: const Key('reintentar-cobros'),
                              variante: ManiButtonVariante.secundario,
                              etiqueta: 'Reintentar',
                              onPressed: context
                                  .read<CobrosAliadoCubit>()
                                  .cargar,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(ManiSpace.xl),
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ManiSpace.lg,
                          vertical: ManiSpace.md,
                        ),
                        decoration: BoxDecoration(
                          color: t.surfaceWarm,
                          borderRadius: ManiRadius.brMd,
                          border: Border.all(
                            color: t.border,
                            width: ManiBorder.regular,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.science_outlined,
                              size: 20,
                              color: t.ink,
                            ),
                            ManiGap.hSm,
                            Expanded(
                              child: Text(
                                avisoSimulado,
                                key: const Key('aviso-simulado-cobros'),
                                style: TextStyle(
                                  fontSize: ManiFontSize.bodySm,
                                  fontWeight: FontWeight.w800,
                                  color: t.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ManiGap.vLg,
                      if (state.cobros.isEmpty)
                        const ManiEstadoVacio(
                          key: Key('cobros-vacio'),
                          icono: Icons.payments_outlined,
                          titulo: 'Aún no tienes cobros.',
                          texto:
                              'Aparecerán cuando un cliente pague un servicio tuyo.',
                        ),
                      for (final c in state.cobros) ...[
                        _TarjetaCobro(cobro: c),
                        ManiGap.vMd,
                      ],
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
    final t = context.mani;
    final r = cobro.retencion;
    final l = cobro.liquidacion;
    return ManiCard(
      key: Key('cobro-${r.pagoId}'),
      sombra: t.shadowSm,
      padding: const EdgeInsets.all(ManiSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatearPesos(r.monto)} ${r.moneda}',
                style: TextStyle(
                  fontSize: ManiFontSize.h3,
                  fontWeight: FontWeight.w900,
                  color: t.ink,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ManiSpace.sm,
                  vertical: ManiSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: l != null ? ManiColors.successContainer : t.brandSoft,
                  borderRadius: ManiRadius.brSm,
                  border: Border.all(color: t.border, width: ManiBorder.thin),
                ),
                child: Text(
                  r.estado.etiqueta,
                  key: Key('estado-${r.pagoId}'),
                  style: TextStyle(
                    fontSize: ManiFontSize.caption,
                    fontWeight: FontWeight.w800,
                    color: l != null ? ManiColors.successText : t.ink,
                  ),
                ),
              ),
            ],
          ),
          ManiGap.vMd,
          Divider(color: t.borderSubtle, height: 1),
          ManiGap.vMd,
          if (l != null) ...[
            Text(
              'Comisión (${l.porcentajeComision.toStringAsFixed(l.porcentajeComision % 1 == 0 ? 0 : 2)} %): '
              '${formatearPesos(l.comision)}',
              key: Key('comision-${r.pagoId}'),
              style: TextStyle(
                fontSize: ManiFontSize.bodySm,
                fontWeight: FontWeight.w600,
                color: t.inkMuted,
              ),
            ),
            ManiGap.vXs,
            Text(
              'Neto para ti: ${formatearPesos(l.montoNeto)}',
              key: Key('neto-${r.pagoId}'),
              style: TextStyle(
                fontSize: ManiFontSize.bodyLg,
                fontWeight: FontWeight.w900,
                color: t.ink,
              ),
            ),
          ] else
            Text(
              'Se liquida cuando el servicio finaliza.',
              key: const Key('sin-liquidar'),
              style: TextStyle(
                fontSize: ManiFontSize.bodySm,
                fontWeight: FontWeight.w600,
                color: t.inkMuted,
              ),
            ),
        ],
      ),
    );
  }
}
