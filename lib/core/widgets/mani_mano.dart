import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// El muñequito de MANI (la mano con gorra y herramientas), sin círculo ni letras y con fondo transparente.
///
/// Es la imagen grande de las pantallas de entrada. Con [alto] se muestra a ese alto; sin él se ajusta al espacio que
/// le da quien lo contiene (así lo usa `ManiLogo`, dentro de su círculo).
class ManiMano extends StatelessWidget {
  const ManiMano({super.key, this.alto, this.mini = false});

  /// Alto en píxeles lógicos; el ancho sale de la proporción de la imagen. `null` ajusta al espacio disponible.
  final double? alto;

  /// Usa la versión preparada para tamaños de unos 30 px (menús y encabezados). Reducir la grande de golpe en el
  /// navegador funde los dedos y las herramientas.
  final bool mini;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MANI',
      image: true,
      child: Image.asset(
        mini
            ? 'assets/images/mani_mano_mini.webp'
            : 'assets/images/mani_mano.webp',
        height: alto,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
        // Si la imagen no carga queda un círculo amarillo con la «M», nunca un hueco vacío.
        errorBuilder: (context, error, stack) => LayoutBuilder(
          builder: (context, caja) {
            final lado =
                alto ??
                (caja.biggest.shortestSide.isFinite
                    ? caja.biggest.shortestSide
                    : 40.0);
            return SizedBox.square(
              dimension: lado * 0.6,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'M',
                    style: TextStyle(
                      fontSize: lado * 0.28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.dark,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
