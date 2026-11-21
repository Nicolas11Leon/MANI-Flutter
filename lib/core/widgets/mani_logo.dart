import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Logo de MANI (el mismo sello circular de la landing), en círculo y con la sombra dura del sistema de diseño.
///
/// Reemplaza al cuadro amarillo con la letra «M» que se repetía en el login, el menú y los registros.
class ManiLogo extends StatelessWidget {
  const ManiLogo({
    super.key,
    this.size = 40,
    this.sombra = AppTheme.hardShadowSm,
  });

  /// Diámetro en píxeles lógicos.
  final double size;

  /// Sombra dura bajo el logo; `null` para dejarlo plano.
  final BoxShadow? sombra;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MANI',
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: sombra == null ? null : [sombra!],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/mani_logo.webp',
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            excludeFromSemantics: true,
            // Si la imagen no carga queda un círculo amarillo con la «M», nunca un hueco vacío.
            errorBuilder: (context, error, stack) => ColoredBox(
              color: AppTheme.primary,
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  child: Text(
                    'M',
                    style: TextStyle(
                      fontSize: size * 0.45,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.dark,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
