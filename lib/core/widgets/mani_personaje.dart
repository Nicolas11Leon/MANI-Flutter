import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_mano.dart';

/// Poses del muñequito. Cada una cuenta un estado de la pantalla.
enum PoseMani { saludo, buscando, trabajando, celebrando, descansando, ups }

/// Poses que ya tienen su propio archivo `assets/images/mani_<pose>.webp`. Al llegar un archivo nuevo se añade aquí y
/// desaparece la insignia de esa pose.
const Set<PoseMani> posesDisponibles = {PoseMani.saludo};

/// El muñequito en una pose. Si la pose aún no tiene archivo, se pinta la base con una insignia que cuenta el estado.
class ManiPersonaje extends StatelessWidget {
  const ManiPersonaje({
    super.key,
    this.pose = PoseMani.saludo,
    this.alto = 96,
    this.conSol = false,
    this.animar = true,
  });

  final PoseMani pose;
  final double alto;

  /// Pinta detrás un círculo suave de `primaryLight`.
  final bool conSol;

  /// Entra con un pequeño rebote, una sola vez. Se ignora con «reducir movimiento».
  final bool animar;

  ({IconData icono, Color fondo})? get _insignia {
    if (posesDisponibles.contains(pose)) return null;
    return switch (pose) {
      PoseMani.saludo => null,
      PoseMani.buscando => (
        icono: Icons.search_rounded,
        fondo: AppTheme.surface,
      ),
      PoseMani.trabajando => (
        icono: Icons.build_rounded,
        fondo: AppTheme.surface,
      ),
      PoseMani.celebrando => (
        icono: Icons.check_rounded,
        fondo: AppTheme.successLight,
      ),
      PoseMani.descansando => (
        icono: Icons.bedtime_rounded,
        fondo: AppTheme.surface,
      ),
      PoseMani.ups => (
        icono: Icons.priority_high_rounded,
        fondo: AppTheme.errorLight,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final insignia = _insignia;
    final lado = alto * 0.34;
    final ancho = conSol ? alto * 1.25 : alto;
    final figura = SizedBox(
      width: ancho,
      height: conSol ? alto * 1.25 : alto,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (conSol)
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: alto * 1.25),
            ),
          ManiMano(alto: alto, mini: alto < 40),
          if (insignia != null)
            Positioned(
              right: conSol ? alto * 0.05 : 0,
              bottom: conSol ? alto * 0.05 : 0,
              child: Container(
                width: lado,
                height: lado,
                decoration: BoxDecoration(
                  color: insignia.fondo,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.dark,
                    width: AppTheme.borderThin,
                  ),
                ),
                child: Icon(
                  insignia.icono,
                  size: lado * 0.6,
                  color: AppTheme.dark,
                ),
              ),
            ),
        ],
      ),
    );
    final reducir = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!animar || reducir) return figura;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppTheme.motionBase,
      curve: AppTheme.motionBounce,
      builder: (context, t, hijo) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: hijo),
      ),
      child: figura,
    );
  }
}
