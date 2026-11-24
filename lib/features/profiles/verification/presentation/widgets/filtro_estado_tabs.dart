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
        color: context.mani.surface,
        borderRadius: ManiRadius.brMd,
        border: Border.all(
          color: context.mani.border,
          width: ManiBorder.regular,
        ),
        boxShadow: const [ManiShadow.sm],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final estado in EstadoVerificacion.values) ...[
            if (estado.index > 0)
              Container(
                width: ManiBorder.regular,
                height: 52,
                color: context.mani.ink,
              ),
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
          height: 52,
          color: activo ? context.mani.brand : context.mani.surface,
          padding: const EdgeInsets.symmetric(horizontal: ManiSpace.sm),
          // En móvil (pestaña angosta) el conteo pasa debajo de la etiqueta
          // para que "Aprobados" y "Rechazados" no se recorten.
          child: LayoutBuilder(
            builder: (context, c) {
              final etiqueta = Text(
                _etiqueta,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ManiFontSize.caption,
                  fontWeight: FontWeight.w800,
                  color: activo ? context.mani.ink : context.mani.inkMuted,
                ),
              );
              final conteo = Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: activo ? context.mani.ink : estado.fondo,
                  borderRadius: ManiRadius.brPill,
                ),
                child: Text(
                  '$cantidad',
                  style: TextStyle(
                    fontSize: ManiFontSize.micro,
                    fontWeight: FontWeight.w900,
                    color: activo ? context.mani.brand : estado.acento,
                  ),
                ),
              );
              if (c.maxWidth < 120) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [etiqueta, ManiGap.vXxs, conteo],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: etiqueta),
                  ManiGap.hSm,
                  conteo,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
