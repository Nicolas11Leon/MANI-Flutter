import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/platform/guardador_archivo.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart'
    show formatearPesos;

import '../data/cobros_datasource.dart';
import '../domain/pago.dart';
import 'pago_cubit.dart';
import 'retencion_pago_card.dart';
import 'package:mani/core/theme/app_theme.dart';

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
      body: BlocBuilder<PagoCubit, PagoState>(
        builder: (context, state) {
          final cubit = context.read<PagoCubit>();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: ManiSpace.xl,
                  vertical: ManiSpace.xxl,
                ),
                children: [
                  const _AvisoSandbox(),
                  ManiGap.vLg,
                  if (total != null)
                    Text(
                      'Total de tu cotización: ${formatearPesos(total!)}',
                      key: const Key('total-cotizacion'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ManiGap.vLg,
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
                  ManiGap.vLg,
                  ManiButton(
                    key: const Key('btn-pagar-sandbox'),
                    etiqueta: 'Pagar (simulado)',
                    icono: Icons.payments_outlined,
                    expandir: true,
                    cargando: state.pagando,
                    onPressed: state.pagando ? null : cubit.pagar,
                  ),
                  if (state.error != null) ...[
                    ManiGap.vLg,
                    _ErrorPago(error: state.error!),
                  ],
                  if (state.pago != null) ...[
                    ManiGap.vLg,
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
                        padding: EdgeInsets.only(top: ManiSpace.sm),
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
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: colores.tertiaryContainer,
        borderRadius: ManiRadius.brSm,
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: colores.onTertiaryContainer),
          ManiGap.hSm,
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
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: colores.errorContainer,
        borderRadius: ManiRadius.brSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error.mensajeUsuario,
            style: TextStyle(color: colores.onErrorContainer),
          ),
          if (error.correlationId != null) ...[
            ManiGap.vXs,
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
        padding: const EdgeInsets.all(ManiSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pago ${pago.etiquetaEstado.toLowerCase()}',
              style: texto.titleMedium,
            ),
            ManiGap.vSm,
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
        padding: const EdgeInsets.all(ManiSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comprobante ${comprobante.numero}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ManiGap.vSm,
            Text(
              'Monto: ${formatearPesos(comprobante.monto)} ${comprobante.moneda}',
            ),
            if (comprobante.fecha != null) Text('Fecha: ${comprobante.fecha}'),
            if (comprobante.leyenda != null) ...[
              ManiGap.vSm,
              Text(
                comprobante.leyenda!,
                key: const Key('leyenda-comprobante'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (guardador != null) ...[
              ManiGap.vSm,
              OutlinedButton.icon(
                key: const Key('btn-descargar-comprobante'),
                onPressed: () => _descargar(context),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Descargar comprobante'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
