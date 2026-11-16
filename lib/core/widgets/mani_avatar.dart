import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Círculo con la foto de una persona o, si no hay foto, sus iniciales sobre un color que sale del nombre (siempre el
/// mismo para el mismo nombre). Tamaños de uso: 32 (fila), 44 (tarjeta), 72 (detalle), 104 (perfil).
class ManiAvatar extends StatelessWidget {
  const ManiAvatar({
    super.key,
    required this.nombre,
    this.foto,
    this.tamano = 44,
  });

  final String nombre;

  /// Dirección de la foto; `null` o vacía muestra las iniciales.
  final String? foto;
  final double tamano;

  static const _fondos = [
    AppTheme.primaryLight,
    AppTheme.successLight,
    AppTheme.errorLight,
    AppTheme.backgroundDark,
  ];

  /// Hasta dos letras: la inicial de las dos primeras palabras.
  static String iniciales(String nombre) {
    final partes = nombre
        .trim()
        .split(RegExp(r"\s+"))
        .where((p) => p.isNotEmpty);
    return partes.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }

  /// Color estable para un nombre: no cambia entre ejecuciones (no usa `hashCode`).
  static Color fondoPara(String nombre) {
    var suma = 0;
    for (final u in nombre.trim().toLowerCase().runes) {
      suma = (suma + u) % 4096;
    }
    return _fondos[suma % _fondos.length];
  }

  @override
  Widget build(BuildContext context) {
    final texto = iniciales(nombre);
    final inicialesWidget = Center(
      child: Text(
        texto.isEmpty ? '?' : texto,
        style: AppTheme.titulo(
          size: tamano * 0.4,
          height: 1,
          color: AppTheme.dark,
        ),
      ),
    );
    final tieneFoto = foto != null && foto!.isNotEmpty;
    return Semantics(
      label: tieneFoto ? 'Foto de $nombre' : nombre,
      image: true,
      excludeSemantics: true,
      child: Container(
        width: tamano,
        height: tamano,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: fondoPara(nombre),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.dark, width: AppTheme.borderThin),
        ),
        child: tieneFoto
            ? Image.network(
                foto!,
                fit: BoxFit.cover,
                cacheWidth: (tamano * 2).round(),
                loadingBuilder: (context, hijo, progreso) => progreso == null
                    ? hijo
                    : const ColoredBox(color: AppTheme.backgroundDark),
                errorBuilder: (context, error, stack) => inicialesWidget,
              )
            : inicialesWidget,
      ),
    );
  }
}
