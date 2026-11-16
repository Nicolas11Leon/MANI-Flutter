import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Aviso de que lo que se ve es una simulación. Va una sola vez, arriba de la pantalla.
class ManiFranjaSimulado extends StatelessWidget {
  const ManiFranjaSimulado({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.avisoFondo,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.science_outlined,
              size: 16,
              color: AppTheme.avisoTexto,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                texto,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.avisoTexto,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
