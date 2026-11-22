import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_personaje.dart';

/// Vacío de una pantalla o de un módulo: dice qué pasa, qué va a aparecer ahí y, si hay, qué hacer.
///
/// [compacto] es la forma en línea (dentro de un módulo); si no, es el vacío de página, centrado y sin tarjeta.
class ManiEstadoVacio extends StatelessWidget {
  const ManiEstadoVacio({
    super.key,
    required this.titulo,
    this.texto,
    this.pose = PoseMani.buscando,
    this.accion,
    this.accionSecundaria,
    this.compacto = false,
  });

  final String titulo;
  final String? texto;
  final PoseMani pose;
  final Widget? accion;
  final Widget? accionSecundaria;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    if (compacto) return _enLinea();
    return _deAplicacion();
  }

  Widget _enLinea() {
    return Container(
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: ManiColors.brandSoft,
        borderRadius: BorderRadius.circular(ManiRadius.md),
      ),
      child: Row(
        children: [
          ManiPersonaje(pose: pose, alto: 56, animar: false),
          const SizedBox(width: ManiSpace.md),
          Expanded(
            child: Text(
              texto == null ? titulo : texto!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: ManiColors.inkMuted,
              ),
            ),
          ),
          if (accion != null) ...[const SizedBox(width: ManiSpace.sm), accion!],
        ],
      ),
    );
  }

  Widget _deAplicacion() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ManiSpace.giant),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ManiPersonaje(pose: pose, conSol: true),
              const SizedBox(height: ManiSpace.lg),
              Semantics(
                header: true,
                child: Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: AppTheme.titulo(),
                ),
              ),
              if (texto != null) ...[
                const SizedBox(height: 6),
                Text(
                  texto!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: ManiColors.inkMuted,
                  ),
                ),
              ],
              if (accion != null) ...[const SizedBox(height: 20), accion!],
              if (accionSecundaria != null) ...[
                const SizedBox(height: ManiSpace.sm),
                accionSecundaria!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error de carga: pose `ups`, título fijo, el texto del fallo y «Reintentar».
class ManiEstadoError extends StatelessWidget {
  const ManiEstadoError({
    super.key,
    required this.texto,
    required this.alReintentar,
    this.sinConexion = false,
  });

  final String texto;
  final VoidCallback alReintentar;
  final bool sinConexion;

  @override
  Widget build(BuildContext context) {
    return ManiEstadoVacio(
      pose: PoseMani.ups,
      titulo: sinConexion ? 'Sin conexión' : 'Algo no salió bien',
      texto: sinConexion ? 'Revisa tu internet y vuelve a intentar.' : texto,
      accion: ManiButton(etiqueta: 'Reintentar', onPressed: alReintentar),
    );
  }
}
