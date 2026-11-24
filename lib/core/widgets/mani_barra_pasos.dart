import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Barra de pasos segmentada: un segmento de 6 px por paso, los hechos y el actual en amarillo y los pendientes en crema
/// oscuro, y debajo «Paso 2 de 4 · Problema».
class ManiBarraPasos extends StatelessWidget {
  const ManiBarraPasos({
    super.key,
    required this.etiquetas,
    required this.actual,
  });

  /// Nombre de cada paso, en orden.
  final List<String> etiquetas;

  /// Índice (desde 0) del paso en que está el usuario.
  final int actual;

  @override
  Widget build(BuildContext context) {
    final total = etiquetas.length;
    return Semantics(
      label: 'Paso ${actual + 1} de $total: ${etiquetas[actual]}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: ManiMotion.base,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= actual
                          ? context.mani.brand
                          : context.mani.surfaceMuted,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Paso ${actual + 1} de $total · ${etiquetas[actual]}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.mani.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
