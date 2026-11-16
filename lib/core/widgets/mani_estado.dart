import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Tono de la píldora de estado.
enum ManiTono {
  /// Publicada, borrador.
  neutro,

  /// Asignada, en ejecución, cotizada.
  enCurso,

  /// Esperando respuesta, pendiente de pago.
  atencion,

  /// Finalizada, pagada, aceptada.
  listo,

  /// Cancelada, rechazada.
  mal,
}

/// Píldora de estado: un punto y el texto, sin borde. Reemplaza los `Chip` de Material y los colores sueltos.
class ManiEstado extends StatelessWidget {
  const ManiEstado({
    super.key,
    required this.texto,
    this.tono = ManiTono.neutro,
  });

  final String texto;
  final ManiTono tono;

  (Color fondo, Color frente) get _colores => switch (tono) {
    ManiTono.neutro => (AppTheme.backgroundDark, AppTheme.dark),
    ManiTono.enCurso => (AppTheme.primaryLight, AppTheme.dark),
    ManiTono.atencion => (AppTheme.avisoFondo, AppTheme.avisoTexto),
    ManiTono.listo => (AppTheme.successLight, AppTheme.successStrong),
    ManiTono.mal => (AppTheme.errorLight, AppTheme.errorStrong),
  };

  @override
  Widget build(BuildContext context) {
    final (fondo, frente) = _colores;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: frente, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: frente,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
