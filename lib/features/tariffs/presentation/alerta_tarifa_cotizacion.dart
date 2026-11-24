import 'package:flutter/material.dart';
import 'package:mani/core/network/mensaje_error_gateway.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart'
    show formatearPesos;

import '../data/tarifas_datasource.dart';
import '../domain/evaluacion_tarifa.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Alerta de tarifa de la cotización vigente (HU-M06-02 / SCRUM-866, RF-16).
///
/// Bidireccional: la ven el aliado que cotizó y el cliente que decide, con el
/// mismo resultado de Rules. Fuera de banda muestra la referencia y el motivo
/// (C1); dentro de banda no inventa una alerta. Sin tarifa, o si Rules no
/// responde, lo dice y no muestra un resultado propio (C2). Core decide quién
/// la puede ver (C3). Nunca cambia la cotización.
class AlertaTarifaCotizacion extends StatefulWidget {
  const AlertaTarifaCotizacion({
    super.key,
    required this.fuente,
    required this.cotizacionId,
    required this.esAliado,
  });

  final FuenteTarifas fuente;
  final String cotizacionId;
  final bool esAliado;

  @override
  State<AlertaTarifaCotizacion> createState() => _AlertaTarifaCotizacionState();
}

class _AlertaTarifaCotizacionState extends State<AlertaTarifaCotizacion> {
  late Future<EvaluacionTarifa> _evaluacion;

  @override
  void initState() {
    super.initState();
    _evaluacion = widget.fuente.evaluacion(widget.cotizacionId);
  }

  @override
  void didUpdateWidget(AlertaTarifaCotizacion anterior) {
    super.didUpdateWidget(anterior);
    // Una versión nueva de la cotización se evalúa de nuevo.
    if (anterior.cotizacionId != widget.cotizacionId) {
      _evaluacion = widget.fuente.evaluacion(widget.cotizacionId);
    }
  }

  void _reintentar() {
    final nueva = widget.fuente.evaluacion(widget.cotizacionId);
    setState(() {
      _evaluacion = nueva;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EvaluacionTarifa>(
      future: _evaluacion,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ListTile(
            key: Key('alerta-tarifa-cargando'),
            dense: true,
            leading: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('Comparando con la tarifa de referencia…'),
          );
        }
        if (snap.hasError) {
          return Card(
            key: const Key('alerta-tarifa-error'),
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text(
                'No se pudo comparar la cotización con la tarifa de referencia',
              ),
              subtitle: Text(mensajeErrorGateway(snap.error!)),
              trailing: TextButton(
                onPressed: _reintentar,
                child: const Text('Reintentar'),
              ),
            ),
          );
        }
        final e = snap.data!;
        return switch (e.resultado) {
          ResultadoTarifa.sinTarifa => const ListTile(
            key: Key('alerta-tarifa-sin-tarifa'),
            dense: true,
            leading: Icon(Icons.info_outline),
            title: Text('Sin tarifa de referencia para comparar'),
            subtitle: Text(
              'La categoría no tenía una tarifa vigente cuando se emitió '
              'esta cotización.',
            ),
          ),
          ResultadoTarifa.dentroDeRango => ListTile(
            key: const Key('alerta-tarifa-en-rango'),
            dense: true,
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Dentro del rango de referencia'),
            subtitle: Text(_rango(e)),
          ),
          _ => _Alerta(e: e, esAliado: widget.esAliado),
        };
      },
    );
  }
}

String _rango(EvaluacionTarifa e) =>
    'Referencia: ${formatearPesos(e.valorMin!)} – '
            '${formatearPesos(e.valorMax!)} ${e.moneda ?? ''}'
        .trim();

String _porcentaje(double? v) {
  if (v == null) return '';
  final texto = v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1).replaceAll('.', ',');
  return '$texto %';
}

class _Alerta extends StatelessWidget {
  const _Alerta({required this.e, required this.esAliado});

  final EvaluacionTarifa e;
  final bool esAliado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final encima = e.resultado == ResultadoTarifa.porEncima;
    final limite = encima ? e.valorMax! : e.valorMin!;
    final motivo = encima
        ? 'El total (${formatearPesos(e.total)}) supera el máximo de '
              'referencia (${formatearPesos(limite)}) en '
              '${_porcentaje(e.desviacionPorcentaje)}.'
        : 'El total (${formatearPesos(e.total)}) está por debajo del mínimo '
              'de referencia (${formatearPesos(limite)}) en '
              '${_porcentaje(e.desviacionPorcentaje)}.';
    final consejo = esAliado
        ? 'El cliente también ve este aviso. Si te pide un ajuste, puedes '
              'enviar una nueva versión.'
        : 'El aliado también ve este aviso. Puedes aceptarla, pedir un ajuste '
              'o rechazarla.';
    return Card(
      key: Key(encima ? 'alerta-tarifa-encima' : 'alerta-tarifa-debajo'),
      color: ManiColors.warningContainer,
      shape: RoundedRectangleBorder(
        borderRadius: ManiRadius.brMd,
        side: const BorderSide(color: ManiColors.warning),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ManiSpace.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: ManiColors.warning),
            ManiGap.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    encima
                        ? 'Cotización por encima del rango de referencia'
                        : 'Cotización por debajo del rango de referencia',
                    style: tema.textTheme.titleSmall,
                  ),
                  ManiGap.vXs,
                  Text(motivo, key: const Key('alerta-tarifa-motivo')),
                  Text(
                    '${_rango(e)} · típico ${formatearPesos(e.valorTipico!)}',
                    style: tema.textTheme.bodySmall,
                  ),
                  ManiGap.vXs,
                  Text(consejo, style: tema.textTheme.bodySmall),
                  Text(
                    'La cotización no cambia por este aviso.',
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
