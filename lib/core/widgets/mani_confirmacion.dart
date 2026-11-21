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
    return Dialog(
      key: const ValueKey('mani-confirmacion'),
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        side: const BorderSide(color: AppTheme.dark, width: 2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.dark,
                ),
              ),
              if (mensaje != null) ...[
                const SizedBox(height: 10),
                Text(
                  mensaje!,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
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
