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
      padding: const EdgeInsets.all(AppTheme.esp3),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusIcon),
      ),
      child: Row(
        children: [
          ManiPersonaje(pose: pose, alto: 56, animar: false),
          const SizedBox(width: AppTheme.esp3),
          Expanded(
            child: Text(
              texto == null ? titulo : texto!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          if (accion != null) ...[
            const SizedBox(width: AppTheme.esp2),
            accion!,
          ],
        ],
      ),
    );
  }

  Widget _deAplicacion() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.esp7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ManiPersonaje(pose: pose, conSol: true),
              const SizedBox(height: AppTheme.esp4),
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
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              if (accion != null) ...[const SizedBox(height: 20), accion!],
              if (accionSecundaria != null) ...[
                const SizedBox(height: AppTheme.esp2),
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
