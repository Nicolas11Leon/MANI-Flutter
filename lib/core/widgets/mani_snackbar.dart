import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// SnackBar flotante con el estilo MANI (rojo para errores, amarillo para
/// éxito), con ícono para que el estado no dependa solo del color.
/// [margin] permite elevarla sobre barras de acción fijas para no taparlas.
void showManiSnackBar(
  BuildContext context,
  String mensaje, {
  bool esError = false,
  EdgeInsetsGeometry margin = const EdgeInsets.all(ManiSpace.lg),
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // Ícono además del color: el estado no depende solo del rojo/amarillo.
        content: Row(
          children: [
            Icon(
              esError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline,
              size: 20,
              color: esError ? ManiColors.onInk : ManiColors.ink,
            ),
            ManiGap.hMd,
            Expanded(
              child: Text(
                mensaje,
                style: ManiText.label.copyWith(
                  color: esError ? ManiColors.onInk : ManiColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: esError ? ManiColors.danger : ManiColors.brand,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: ManiRadius.brMd,
          side: ManiBorder.side,
        ),
        margin: margin,
      ),
    );
}
