import 'package:flutter/material.dart';
import 'package:mani/core/network/mensaje_error_gateway.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart'
    show formatearPesos;

import '../data/tarifas_datasource.dart';
import '../domain/tarifa.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Tarifa de referencia vigente al cotizar (HU-M10-02 / SCRUM-886).
///
/// La ven el aliado asignado mientras cotiza y el cliente al revisar la
/// cotización. Sin tarifa vigente lo dice (C2): no inventa un rango. Core
/// decide quién la puede ver y solo devuelve la del tenant de la sesión (C3).
class ReferenciaTarifaSeccion extends StatefulWidget {
  const ReferenciaTarifaSeccion({
    super.key,
    required this.fuente,
    required this.solicitudId,
  });

  final FuenteTarifas fuente;
  final String solicitudId;

  @override
  State<ReferenciaTarifaSeccion> createState() =>
      _ReferenciaTarifaSeccionState();
}

class _ReferenciaTarifaSeccionState extends State<ReferenciaTarifaSeccion> {
  late Future<ReferenciaTarifa> _referencia;

  @override
  void initState() {
    super.initState();
    _referencia = widget.fuente.referencia(widget.solicitudId);
  }

  void _reintentar() => setState(
    () => _referencia = widget.fuente.referencia(widget.solicitudId),
  );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return FutureBuilder<ReferenciaTarifa>(
      future: _referencia,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Card(
            key: Key('referencia-cargando'),
            child: ListTile(
              leading: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Consultando la tarifa de referencia…'),
            ),
          );
        }
        if (snap.hasError) {
          return Card(
            key: const Key('referencia-error'),
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('No se pudo consultar la tarifa de referencia'),
              subtitle: Text(mensajeErrorGateway(snap.error!)),
              trailing: TextButton(
                onPressed: _reintentar,
                child: const Text('Reintentar'),
              ),
            ),
          );
        }
        final tarifa = snap.data!.tarifa;
        if (tarifa == null) {
          return const Card(
            key: Key('referencia-no-disponible'),
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Tarifa de referencia no disponible'),
              subtitle: Text(
                'La categoría de esta solicitud no tiene una tarifa vigente.',
              ),
            ),
          );
        }
        return Card(
          key: const Key('referencia-disponible'),
          child: Padding(
            padding: const EdgeInsets.all(ManiSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tarifa de referencia · ${tarifa.categoriaNombre}',
                  style: tema.titleSmall,
                ),
                ManiGap.vXs,
                Text(
                  '${formatearPesos(tarifa.valorMin)} – ${formatearPesos(tarifa.valorMax)} ${tarifa.moneda}',
                  key: const Key('referencia-rango'),
                  style: tema.titleMedium,
                ),
                Text('Valor típico: ${formatearPesos(tarifa.valorTipico)}'),
                Text(tarifa.vigencia, style: tema.bodySmall),
                if (tarifa.condiciones != null)
                  Text(
                    'Condiciones: ${tarifa.condiciones}',
                    style: tema.bodySmall,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
