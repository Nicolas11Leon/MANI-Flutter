import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// El muñequito de MANI (la mano con gorra y herramientas), sin círculo ni letras y con fondo transparente.
///
/// Es la imagen grande de las pantallas de entrada. El sello circular con la leyenda «Mani · Al servicio» es
/// `ManiLogo`, para los sitios pequeños.
class ManiMano extends StatelessWidget {
  const ManiMano({super.key, this.alto = 140});

  /// Alto en píxeles lógicos; el ancho sale de la proporción de la imagen.
  final double alto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MANI',
      image: true,
      child: Image.asset(
        'assets/images/mani_mano.webp',
        height: alto,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
        // Si la imagen no carga queda un círculo amarillo con la «M», nunca un hueco vacío.
        errorBuilder: (context, error, stack) => SizedBox.square(
          dimension: alto * 0.6,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'M',
                style: TextStyle(
                  fontSize: alto * 0.28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.dark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
