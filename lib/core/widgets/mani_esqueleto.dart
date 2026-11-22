import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Carga con la forma del contenido: bloques en crema oscuro con un pulso suave de opacidad. Reemplaza al indicador
/// circular centrado en las pantallas. Sin pulso con «reducir movimiento».
class ManiEsqueleto extends StatefulWidget {
  const ManiEsqueleto({super.key, required this.hijos});

  /// Lista de filas: bloques de alto 72 separados por 12.
  ManiEsqueleto.lista({Key? key, int filas = 4})
    : this(
        key: key,
        hijos: [for (var i = 0; i < filas; i++) const _Bloque(72)],
      );

  /// Tarjetas altas, como las de un servicio.
  ManiEsqueleto.tarjetas({Key? key, int cantidad = 2})
    : this(
        key: key,
        hijos: [for (var i = 0; i < cantidad; i++) const _Bloque(140)],
      );

  /// Un título, un bloque grande y dos líneas de texto.
  const ManiEsqueleto.detalle({Key? key})
    : this(
        key: key,
        hijos: const [
          _Bloque(28, ancho: 200),
          _Bloque(160),
          _Bloque(16),
          _Bloque(16, ancho: 240),
        ],
      );

  final List<Widget> hijos;

  @override
  State<ManiEsqueleto> createState() => _ManiEsqueletoState();
}

class _ManiEsqueletoState extends State<ManiEsqueleto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducir = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reducir) {
      _pulso.stop();
    } else if (!_pulso.isAnimating) {
      _pulso.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _pulso,
          builder: (context, hijo) =>
              Opacity(opacity: 0.55 + 0.45 * _pulso.value, child: hijo),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.hijos.length; i++) ...[
                if (i > 0) const SizedBox(height: ManiSpace.md),
                widget.hijos[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque(this.alto, {this.ancho});

  final double alto;
  final double? ancho;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho ?? double.infinity,
      height: alto,
      decoration: BoxDecoration(
        color: ManiColors.surfaceMuted,
        borderRadius: BorderRadius.circular(ManiRadius.sm),
      ),
    );
  }
}
