import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Título grande y subtítulo de cada paso del asistente.
class EncabezadoPaso extends StatelessWidget {
  const EncabezadoPaso({
    super.key,
    required this.titulo,
    required this.subtitulo,
  });

  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: ManiFontSize.h3,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: ManiColors.ink,
          ),
        ),
        ManiGap.vXs,
        Text(
          subtitulo,
          style: const TextStyle(
            color: ManiColors.inkMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
