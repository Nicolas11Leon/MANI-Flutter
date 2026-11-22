import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';

/// Pide confirmación antes de una acción crítica (SCRUM-1650).
///
/// Devuelve `true` solo si el usuario pulsa [etiquetaConfirmar]. Cancelar,
/// tocar fuera del diálogo o pulsar atrás devuelven `false`, y quien llama no
/// debe hacer nada en ese caso.
Future<bool> confirmarAccion(
  BuildContext context, {
  required String titulo,
  String? mensaje,
  required String etiquetaConfirmar,
  String etiquetaCancelar = 'Cancelar',
  bool peligro = true,
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (_) => ManiConfirmacion(
      titulo: titulo,
      mensaje: mensaje,
      etiquetaConfirmar: etiquetaConfirmar,
      etiquetaCancelar: etiquetaCancelar,
      peligro: peligro,
    ),
  );
  return confirmado ?? false;
}

/// Diálogo de confirmación con el sistema de diseño MANI. Cierra su ruta con
/// `true` al confirmar y con `false` al cancelar.
class ManiConfirmacion extends StatelessWidget {
  const ManiConfirmacion({
    super.key,
    required this.titulo,
    this.mensaje,
    required this.etiquetaConfirmar,
    this.etiquetaCancelar = 'Cancelar',
    this.peligro = true,
  });

  final String titulo;
  final String? mensaje;
  final String etiquetaConfirmar;
  final String etiquetaCancelar;

  /// Pinta el botón de confirmar en rojo, para acciones que quitan algo.
  final bool peligro;

  @override
  Widget build(BuildContext context) {
    final navegador = Navigator.of(context);
    final t = context.mani;
    return Dialog(
      key: const ValueKey('mani-confirmacion'),
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: ManiRadius.brLg,
        side: BorderSide(color: t.border, width: ManiBorder.regular),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(ManiSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: t.ink,
                ),
              ),
              if (mensaje != null) ...[
                ManiGap.vSm,
                Text(mensaje!, style: TextStyle(color: t.inkMuted)),
              ],
              ManiGap.vXxl,
              Wrap(
                alignment: WrapAlignment.end,
                spacing: ManiSpace.md,
                runSpacing: ManiSpace.md,
                children: [
                  ManiButton(
                    key: const ValueKey('confirmacion-cancelar'),
                    etiqueta: etiquetaCancelar,
                    variante: ManiButtonVariante.secundario,
                    onPressed: () => navegador.pop(false),
                  ),
                  ManiButton(
                    key: const ValueKey('confirmacion-confirmar'),
                    etiqueta: etiquetaConfirmar,
                    variante: peligro
                        ? ManiButtonVariante.peligro
                        : ManiButtonVariante.primario,
                    onPressed: () => navegador.pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
