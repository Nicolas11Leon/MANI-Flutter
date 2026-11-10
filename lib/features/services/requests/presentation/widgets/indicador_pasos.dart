import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

import '../bloc/crear_solicitud_cubit.dart';

/// Progreso del asistente: pasos completados, actual y pendientes.
class IndicadorPasos extends StatelessWidget {
  const IndicadorPasos({super.key, required this.actual});

  final PasoSolicitud actual;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Paso ${actual.index + 1} de ${PasoSolicitud.values.length}: '
          '${actual.etiqueta}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (final p in PasoSolicitud.values) ...[
            if (p.index > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: ManiSpace.xl),
                  color: p.index <= actual.index
                      ? ManiColors.ink
                      : ManiColors.borderSubtle,
                ),
              ),
            _Punto(paso: p, actual: actual),
          ],
        ],
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.paso, required this.actual});

  final PasoSolicitud paso;
  final PasoSolicitud actual;

  @override
  Widget build(BuildContext context) {
    final hecho = paso.index < actual.index;
    final activo = paso == actual;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: ManiMotion.base,
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activo
                ? ManiColors.brand
                : (hecho ? ManiColors.ink : ManiColors.surface),
            shape: BoxShape.circle,
            border: Border.all(
              color: hecho || activo ? ManiColors.ink : ManiColors.borderSubtle,
              width: ManiBorder.regular,
            ),
          ),
          child: hecho
              ? const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: ManiColors.brand,
                )
              : Text(
                  '${paso.index + 1}',
                  style: TextStyle(
                    fontSize: ManiFontSize.bodySm,
                    fontWeight: FontWeight.w900,
                    color: activo ? ManiColors.ink : ManiColors.inkSubtle,
                  ),
                ),
        ),
        ManiGap.vXs,
        Text(
          paso.etiqueta,
          style: TextStyle(
            fontSize: ManiFontSize.micro,
            fontWeight: activo ? FontWeight.w900 : FontWeight.w600,
            color: activo || hecho ? ManiColors.ink : ManiColors.inkSubtle,
          ),
        ),
      ],
    );
  }
}
