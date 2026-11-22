import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Fondo crema con una trama de puntos muy tenue, como la de la landing. Va detrás de las pantallas de entrada.
class ManiTrama extends StatelessWidget {
  const ManiTrama({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ManiColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: CustomPaint(painter: _PintorTrama(), size: Size.infinite),
          ),
          child,
        ],
      ),
    );
  }
}

class _PintorTrama extends CustomPainter {
  const _PintorTrama();

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()..color = ManiColors.ink.withValues(alpha: 0.05);
    const paso = 24.0;
    for (var y = paso / 2; y < size.height; y += paso) {
      for (var x = paso / 2; x < size.width; x += paso) {
        canvas.drawCircle(Offset(x, y), 1.5, pincel);
      }
    }
  }

  @override
  bool shouldRepaint(_PintorTrama anterior) => false;
}
