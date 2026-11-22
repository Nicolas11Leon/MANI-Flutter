import 'package:flutter/material.dart';
import 'package:mani/core/widgets/mani_barra_pasos.dart';

import '../bloc/crear_solicitud_cubit.dart';

/// Progreso del asistente: la barra de pasos segmentada de la app.
class IndicadorPasos extends StatelessWidget {
  const IndicadorPasos({super.key, required this.actual});

  final PasoSolicitud actual;

  @override
  Widget build(BuildContext context) {
    return ManiBarraPasos(
      etiquetas: [for (final p in PasoSolicitud.values) p.etiqueta],
      actual: actual.index,
    );
  }
}
