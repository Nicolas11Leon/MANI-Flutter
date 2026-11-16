import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_esqueleto.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_estados.dart';
import 'package:mani/core/widgets/mani_franja_simulado.dart';
import 'package:mani/core/widgets/mani_personaje.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart'
    show formatearPesos;

import '../domain/cobros.dart';
import 'cobros_aliado_cubit.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';

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

  static const avisoSimulado = 'Simulación: no mueve dinero real';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barraDePantalla(context, titulo: 'Mis cobros'),
      body: BlocBuilder<CobrosAliadoCubit, CobrosAliadoState>(
        builder: (context, state) {
          if (state.fase == FaseCobros.cargando) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ManiEsqueleto.lista(),
            );
          }
          if (state.fase == FaseCobros.error) {
            return Center(
              child: SingleChildScrollView(
                child: ManiEstadoVacio(
                  key: const Key('error-cobros'),
                  pose: PoseMani.ups,
                  titulo: 'Algo no salió bien',
                  texto: state.error!.mensajeUsuario,
                  accion: ManiButton(
                    key: const Key('reintentar-cobros'),
                    etiqueta: 'Reintentar',
                    onPressed: context.read<CobrosAliadoCubit>().cargar,
                  ),
                ),
              ),
            );
          }
          final porLiquidar = state.cobros
              .where((c) => c.liquidacion == null)
              .fold<double>(0, (suma, c) => suma + c.retencion.monto);
          final liquidado = state.cobros.fold<double>(
            0,
            (suma, c) => suma + (c.liquidacion?.montoNeto ?? 0),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const ManiFranjaSimulado(
                key: Key('aviso-simulado-cobros'),
                texto: avisoSimulado,
              ),
              const SizedBox(height: 12),
              if (state.cobros.isEmpty)
                const KeyedSubtree(
                  key: Key('cobros-vacio'),
                  child: ManiEstadoVacio(
                    pose: PoseMani.descansando,
                    titulo: 'Aún no tienes cobros',
                    texto:
                        'Aparecerán cuando un cliente pague un servicio tuyo.',
                  ),
                )
              else ...[
                _Resumen(porLiquidar: porLiquidar, liquidado: liquidado),
                const SizedBox(height: 12),
                for (final c in state.cobros) _TarjetaCobro(cobro: c),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Dos cifras arriba: lo que falta por liquidar y lo que ya se liquidó (sumas de la lista que ya se trae).
class _Resumen extends StatelessWidget {
  const _Resumen({required this.porLiquidar, required this.liquidado});

  final double porLiquidar;
  final double liquidado;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Cifra('Por liquidar', porLiquidar)),
        const SizedBox(width: 12),
        Expanded(child: _Cifra('Liquidado', liquidado)),
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(this.etiqueta, this.valor);

  final String etiqueta;
  final double valor;

  @override
  Widget build(BuildContext context) {
    return ManiCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatearPesos(valor),
            style: AppTheme.titulo(
              size: 24,
              height: 30 / 24,
              color: AppTheme.dark,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ManiCard(
        key: Key('cobro-${r.pagoId}'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatearPesos(r.monto)} ${r.moneda}',
                    style: AppTheme.titulo(size: 18).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                ManiEstado(
                  key: Key('estado-${r.pagoId}'),
                  texto: r.estado.etiqueta,
                  tono: switch (r.estado) {
                    EstadoRetencion.retenida => ManiTono.atencion,
                    EstadoRetencion.liberada => ManiTono.listo,
                    EstadoRetencion.otro => ManiTono.neutro,
                  },
                ),
              ],
            ),
            if (l != null) ...[
              const SizedBox(height: 8),
              const Divider(
                color: AppTheme.divisor,
                thickness: AppTheme.borderHair,
                height: 16,
              ),
              _Linea(
                'Comisión MANI (${l.porcentajeComision.toStringAsFixed(l.porcentajeComision % 1 == 0 ? 0 : 2)} %)',
                formatearPesos(l.comision),
                clave: Key('comision-${r.pagoId}'),
              ),
              const SizedBox(height: 4),
              _Linea(
                'Recibes',
                formatearPesos(l.montoNeto),
                clave: Key('neto-${r.pagoId}'),
                fuerte: true,
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Se liquida cuando el servicio finaliza.',
                key: Key('sin-liquidar'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renglón plano: etiqueta a la izquierda y valor con cifras tabulares a la derecha.
class _Linea extends StatelessWidget {
  const _Linea(this.etiqueta, this.valor, {this.clave, this.fuerte = false});

  final String etiqueta;
  final String valor;
  final Key? clave;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: clave,
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: fuerte ? 16 : 14,
              fontWeight: fuerte ? FontWeight.w800 : FontWeight.w500,
              color: fuerte ? AppTheme.dark : AppTheme.textSecondary,
            ),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: fuerte ? 16 : 14,
            fontWeight: fuerte ? FontWeight.w800 : FontWeight.w700,
            color: AppTheme.dark,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
