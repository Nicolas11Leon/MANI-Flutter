import 'package:flutter/material.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart'
    show formatearPesos;

import '../data/cobros_datasource.dart';
import '../domain/cobros.dart';
import '../domain/pago.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Estado de la retención en garantía de un pago aprobado (SCRUM-891 y 892).
/// Es una simulación: lo dice siempre, para que no se lea como custodia real.
class RetencionPagoCard extends StatefulWidget {
  const RetencionPagoCard({
    super.key,
    required this.fuente,
    required this.pagoId,
  });

  final FuenteCobros fuente;
  final String pagoId;

  @override
  State<RetencionPagoCard> createState() => _RetencionPagoCardState();
}

class _RetencionPagoCardState extends State<RetencionPagoCard> {
  late final Future<RetencionPago> _retencion = widget.fuente.retencion(
    widget.pagoId,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RetencionPago>(
      future: _retencion,
      builder: (context, snap) {
        if (snap.hasError) {
          final e = snap.error;
          return Padding(
            padding: const EdgeInsets.only(top: ManiSpace.sm),
            child: Text(
              e is PagoFailure
                  ? e.mensajeUsuario
                  : 'No pudimos consultar la retención.',
              key: const Key('sin-retencion'),
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: ManiSpace.sm),
            child: LinearProgressIndicator(),
          );
        }
        final r = snap.data!;
        return Card(
          key: const Key('retencion-pago'),
          margin: const EdgeInsets.only(top: ManiSpace.sm),
          child: Padding(
            padding: const EdgeInsets.all(ManiSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.estado.etiqueta}: ${formatearPesos(r.monto)} ${r.moneda}',
                  key: const Key('estado-retencion'),
                ),
                if (r.simulada)
                  const Text(
                    'Simulado: no es custodia de dinero real. Se libera al '
                    'finalizar el servicio.',
                    key: Key('leyenda-retencion'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
