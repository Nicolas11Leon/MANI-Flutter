import 'package:mani/core/widgets/mani_button.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/platform/guardador_archivo.dart';
import 'package:mani/core/widgets/barra_acciones_flujo.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart'
    show formatearPesos;

import '../data/cobros_datasource.dart';
import '../domain/pago.dart';
import 'pago_cubit.dart';
import 'retencion_pago_card.dart';

/// Pago de una cotización aceptada en el sandbox (SCRUM-1432, HU-M11-01).
///
/// Es un simulador: no cobra dinero real ni pide datos de tarjeta. La persona
/// solo elige el desenlace que quiere probar. El monto lo calcula Core a partir
/// de la cotización; [total], si llega, es solo una ayuda para mostrar antes.
class PagoSandboxPage extends StatelessWidget {
  const PagoSandboxPage({super.key, this.total, this.cobros, this.guardador});

  /// Guarda el comprobante en el dispositivo; si no llega, no hay botón de descarga (SCRUM-890).
  final GuardadorArchivo? guardador;

  /// Fuente de la retención en garantía; si no llega, no se muestra (SCRUM-891).
  final FuenteCobros? cobros;

  /// Total de la cotización que se está pagando, para mostrarlo antes de pagar.
  final double? total;

  /// Texto fijo del aviso de sandbox, visible antes y después de pagar.
  static const avisoSandbox =
      'SANDBOX · PAGO SIMULADO. No se cobra dinero real ni se piden datos de '
      'tarjeta.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pago en sandbox')),
      // Barra estándar de los flujos: Atrás y la acción principal, siempre abajo (SCRUM-1647). Con el pago aprobado la
      // acción principal pasa a «Listo» y vuelve a la solicitud.
      bottomNavigationBar: BlocBuilder<PagoCubit, PagoState>(
        builder: (context, state) {
          final aprobado = state.pago?.aprobado ?? false;
          void volver() => Navigator.of(context).maybePop();
          return BarraAccionesFlujo(
            claveAtras: const Key('btn-pago-atras'),
            onAtras: state.pagando ? null : volver,
            clavePrincipal: Key(
              aprobado ? 'btn-pago-listo' : 'btn-pagar-sandbox',
            ),
            etiquetaPrincipal: aprobado ? 'Listo' : 'Pagar (simulado)',
            iconoPrincipal: aprobado
                ? Icons.check_rounded
                : Icons.payments_outlined,
            cargando: state.pagando,
            onPrincipal: state.pagando
                ? null
                : (aprobado ? volver : context.read<PagoCubit>().pagar),
          );
        },
      ),
      body: BlocBuilder<PagoCubit, PagoState>(
        builder: (context, state) {
          final cubit = context.read<PagoCubit>();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                children: [
                  const _AvisoSandbox(),
                  const SizedBox(height: 16),
                  if (total != null)
                    Text(
                      'Total de tu cotización: ${formatearPesos(total!)}',
                      key: const Key('total-cotizacion'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<EscenarioPago>(
                    key: const Key('escenario-pago'),
                    isExpanded: true,
                    initialValue: state.escenario,
                    decoration: const InputDecoration(
                      labelText: 'Resultado que quieres simular',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final e in EscenarioPago.values)
                        DropdownMenuItem(value: e, child: Text(e.etiqueta)),
                    ],
                    onChanged: state.pagando
                        ? null
                        : (e) {
                            if (e != null) cubit.elegirEscenario(e);
                          },
                  ),
                  const SizedBox(height: 16),
                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorPago(error: state.error!),
                  ],
                  if (state.pago != null) ...[
                    const SizedBox(height: 16),
                    _ResultadoPago(pago: state.pago!),
                    if (state.comprobante != null)
                      _Comprobante(
                        comprobante: state.comprobante!,
                        guardador: guardador,
                      ),
                    if (cobros != null && state.pago!.aprobado)
                      RetencionPagoCard(
                        fuente: cobros!,
                        pagoId: state.pago!.id,
                      ),
                    if (state.falloComprobante)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'El pago se aprobó, pero no pudimos traer el comprobante. '
                          'Vuelve a abrir esta pantalla en unos minutos.',
                          key: Key('sin-comprobante'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AvisoSandbox extends StatelessWidget {
  const _AvisoSandbox();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Container(
      key: const Key('aviso-sandbox'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colores.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: colores.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              PagoSandboxPage.avisoSandbox,
              style: TextStyle(color: colores.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPago extends StatelessWidget {
  const _ErrorPago({required this.error});

  final PagoFailure error;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Container(
      key: const Key('error-pago'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colores.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error.mensajeUsuario,
            style: TextStyle(color: colores.onErrorContainer),
          ),
          if (error.correlationId != null) ...[
            const SizedBox(height: 4),
            Text(
              'Código de seguimiento: ${error.correlationId}',
              key: const Key('correlacion-pago'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultadoPago extends StatelessWidget {
  const _ResultadoPago({required this.pago});

  final Pago pago;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Card(
      key: const Key('resultado-pago'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pago ${pago.etiquetaEstado.toLowerCase()}',
              style: texto.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Monto: ${formatearPesos(pago.monto)} ${pago.moneda}'),
            Text('Referencia: ${pago.referenciaProveedor}'),
            if (pago.simulado)
              const Text('PAGO SIMULADO', key: Key('pago-simulado')),
            if (pago.motivo != null && pago.motivo!.isNotEmpty)
              Text('Motivo: ${pago.motivo}'),
            if (pago.estado == EstadoPago.pendiente)
              const Text(
                'El proveedor simulado lo dejó pendiente; puedes volver a '
                'intentarlo con otro resultado.',
              ),
          ],
        ),
      ),
    );
  }
}

class _Comprobante extends StatelessWidget {
  const _Comprobante({required this.comprobante, this.guardador});

  final ComprobantePago comprobante;
  final GuardadorArchivo? guardador;

  Future<void> _descargar(BuildContext context) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final guardado = await guardador!.guardar(
        nombre: comprobante.nombreArchivo,
        bytes: Uint8List.fromList(utf8.encode(comprobante.comoTexto())),
        tipoMime: 'text/plain',
      );
      if (guardado) {
        mensajero.showSnackBar(
          const SnackBar(content: Text('Comprobante guardado.')),
        );
      }
    } catch (_) {
      mensajero.showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos guardar el comprobante. Inténtalo de nuevo.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('comprobante-pago'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comprobante ${comprobante.numero}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Monto: ${formatearPesos(comprobante.monto)} ${comprobante.moneda}',
            ),
            if (comprobante.fecha != null) Text('Fecha: ${comprobante.fecha}'),
            if (comprobante.leyenda != null) ...[
              const SizedBox(height: 8),
              Text(
                comprobante.leyenda!,
                key: const Key('leyenda-comprobante'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (guardador != null) ...[
              const SizedBox(height: 8),
              ManiButton(
                key: const Key('btn-descargar-comprobante'),
                variante: ManiButtonVariante.secundario,
                icono: Icons.download_outlined,
                etiqueta: 'Descargar comprobante',
                onPressed: () => _descargar(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
