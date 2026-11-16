import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_mano.dart';

/// Marca pequeña de MANI para menús y encabezados: la manita dentro de un círculo con el borde y la sombra dura del
/// sistema de diseño.
///
/// Reemplaza al cuadro amarillo con la letra «M» que se repetía en el menú y en los registros. El aro se dibuja aquí con
/// los tokens de `AppTheme`, no viene en la imagen, así que sigue al tema si este cambia. Para la imagen grande de las
/// pantallas de entrada se usa `ManiMano` directamente.
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
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.backgroundDark,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.dark,
            width: size >= 80 ? AppTheme.borderThick : AppTheme.borderMedium,
          ),
          boxShadow: sombra == null ? null : [sombra!],
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.1),
          child: ManiMano(mini: size < 80),
        ),
      ),
    );
  }
}
