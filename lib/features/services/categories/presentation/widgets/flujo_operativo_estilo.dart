import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

import '../../domain/entities/flujo_operativo.dart';

/// Ícono y colores de cada flujo, compartidos por tarjetas, selector y badge.
extension EstiloFlujoOperativo on FlujoOperativo {
  IconData get icono => switch (this) {
    FlujoOperativo.cotizacionPrevia => Icons.request_quote_outlined,
    FlujoOperativo.tarifaEstandar => Icons.sell_outlined,
  };

  Color get fondo => switch (this) {
    FlujoOperativo.cotizacionPrevia => ManiColors.accentContainer,
    FlujoOperativo.tarifaEstandar => ManiColors.successContainer,
  };

  Color get acento => switch (this) {
    FlujoOperativo.cotizacionPrevia => ManiColors.accent,
    FlujoOperativo.tarifaEstandar => ManiColors.success,
  };

  /// Cómo lo lee el cliente en el catálogo.
  String get textoCliente => switch (this) {
    FlujoOperativo.cotizacionPrevia =>
      'Recibirás una cotización antes de empezar',
    FlujoOperativo.tarifaEstandar => 'Precio fijo de referencia',
  };
}

class FlujoOperativoBadge extends StatelessWidget {
  const FlujoOperativoBadge({super.key, required this.flujo});

  /// `null` = flujo desconocido en BD.
  final FlujoOperativo? flujo;

  @override
  Widget build(BuildContext context) {
    final f = flujo;
    final fondo = f?.fondo ?? context.mani.borderSubtle;
    final acento = f?.acento ?? context.mani.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.sm,
        vertical: ManiSpace.xs,
      ),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: ManiRadius.brPill,
        border: Border.all(color: context.mani.border, width: ManiBorder.thin),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(f?.icono ?? Icons.help_outline, size: 13, color: acento),
          ManiGap.hXs,
          Text(
            f?.etiqueta ?? 'Flujo sin definir',
            style: TextStyle(
              fontSize: ManiFontSize.micro,
              fontWeight: FontWeight.w800,
              color: acento,
            ),
          ),
        ],
      ),
    );
  }
}
