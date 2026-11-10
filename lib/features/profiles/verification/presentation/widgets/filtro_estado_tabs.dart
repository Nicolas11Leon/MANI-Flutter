import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

import '../../domain/entities/solicitud_aliado.dart';
import 'estado_verificacion_badge.dart';

/// Pestañas segmentadas Pendientes / Aprobados / Rechazados con su conteo.
class FiltroEstadoTabs extends StatelessWidget {
  const FiltroEstadoTabs({
    super.key,
    required this.seleccionado,
    required this.conteo,
    required this.onCambiar,
  });

  final EstadoVerificacion seleccionado;
  final int Function(EstadoVerificacion) conteo;
  final ValueChanged<EstadoVerificacion> onCambiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ManiColors.surface,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
        boxShadow: const [ManiShadow.sm],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final estado in EstadoVerificacion.values) ...[
            if (estado.index > 0)
              Container(width: 2, height: 48, color: ManiColors.ink),
            Expanded(
              child: _Tab(
                estado: estado,
                activo: estado == seleccionado,
                cantidad: conteo(estado),
                onTap: onCambiar,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.estado,
    required this.activo,
    required this.cantidad,
    required this.onTap,
  });

  final EstadoVerificacion estado;
  final bool activo;
  final int cantidad;
  final ValueChanged<EstadoVerificacion> onTap;

  String get _etiqueta => switch (estado) {
    EstadoVerificacion.pendiente => 'Pendientes',
    EstadoVerificacion.aprobado => 'Aprobados',
    EstadoVerificacion.rechazado => 'Rechazados',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: activo,
      button: true,
      label: '$_etiqueta: $cantidad',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('tab-${estado.name}'),
        onTap: () => onTap(estado),
        child: AnimatedContainer(
          duration: ManiMotion.fast,
          height: 48,
          color: activo ? ManiColors.brand : ManiColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: ManiSpace.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _etiqueta,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ManiFontSize.caption,
                    fontWeight: FontWeight.w800,
                    color: activo ? ManiColors.ink : ManiColors.inkMuted,
                  ),
                ),
              ),
              ManiGap.hSm,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: activo ? ManiColors.ink : estado.fondo,
                  borderRadius: ManiRadius.brPill,
                ),
                child: Text(
                  '$cantidad',
                  style: TextStyle(
                    fontSize: ManiFontSize.micro,
                    fontWeight: FontWeight.w900,
                    color: activo ? ManiColors.brand : estado.acento,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
