import 'package:mani/core/widgets/mani_button.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mani/core/widgets/mani_avatar.dart';
import 'package:mani/features/profiles/own_profile/data/datasources/perfil_propio_remote_datasource.dart';

typedef SelectorArchivoImagen =
    Future<({String nombre, Uint8List bytes})?> Function();

/// SCRUM-1030: Componente para cambiar y subir una nueva foto de perfil.
///
/// La foto se ve en el avatar; su dirección no se muestra como texto (SCRUM-1634): es una URL firmada que vence y,
/// antes, era la ruta interna del bucket.
class FotoPerfilSelectorWidget extends StatelessWidget {
  const FotoPerfilSelectorWidget({
    super.key,
    required this.fullName,
    this.photoUrl,
    this.subiendo = false,
    required this.onFotoSeleccionada,
    this.selectorImagen,
  });

  final String fullName;
  final String? photoUrl;
  final bool subiendo;
  final Future<void> Function(String nombreArchivo, Uint8List bytes)
  onFotoSeleccionada;
  final SelectorArchivoImagen? selectorImagen;

  Future<void> _seleccionar(BuildContext context) async {
    if (selectorImagen == null) return;
    final archivo = await selectorImagen!();
    if (archivo == null) return;
    if (!GatewayPerfilPropioDataSource.esFotoValida(
      archivo.nombre,
      archivo.bytes,
    )) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: Key('snackbar-error-formato-foto'),
            content: Text(FotoPerfilInvalidaException.mensaje),
          ),
        );
      }
      return;
    }
    await onFotoSeleccionada(archivo.nombre, archivo.bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ManiAvatar(
          key: const Key('avatar-perfil-propio'),
          nombre: fullName,
          foto: photoUrl,
          tamano: 104,
        ),
        const SizedBox(height: 8),
        ManiButton(
          key: const Key('btn-cambiar-foto-perfil'),
          variante: ManiButtonVariante.secundario,
          icono: Icons.photo_camera_outlined,
          etiqueta: subiendo ? 'Subiendo foto...' : 'Cambiar foto de perfil',
          onPressed: subiendo ? null : () => _seleccionar(context),
        ),
      ],
    );
  }
}
