import 'package:flutter/material.dart';
import 'package:mani/core/widgets/mani_estado.dart';

import '../../domain/entities/solicitud_aliado.dart';

/// Tono e ícono de cada estado, compartidos por badges, pestañas y panel.
/// Los colores salen de [ManiTono], la fuente única de colores de estado.
extension EstiloEstadoVerificacion on EstadoVerificacion {
  ManiTono get tono => switch (this) {
    EstadoVerificacion.pendiente => ManiTono.aviso,
    EstadoVerificacion.aprobado => ManiTono.exito,
    EstadoVerificacion.rechazado => ManiTono.peligro,
  };

  Color get fondo => tono.fondo;

  Color get acento => tono.texto;

  IconData get icono => switch (this) {
    EstadoVerificacion.pendiente => Icons.hourglass_top_rounded,
    EstadoVerificacion.aprobado => Icons.verified_rounded,
    EstadoVerificacion.rechazado => Icons.block_rounded,
  };
}

class EstadoVerificacionBadge extends StatelessWidget {
  const EstadoVerificacionBadge({
    super.key,
    required this.estado,
    this.compacto = false,
  });

  final EstadoVerificacion estado;
  final bool compacto;

  @override
  Widget build(BuildContext context) => ManiStatusBadge(
    etiqueta: estado.etiqueta,
    tono: estado.tono,
    icono: estado.icono,
    compacto: compacto,
  );
}
