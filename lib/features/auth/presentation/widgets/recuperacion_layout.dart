import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_personaje.dart';
import 'package:mani/core/widgets/mani_trama.dart';

/// Marco común de las pantallas de recuperación de contraseña (HU-M02-10):
/// tarjeta centrada con título, explicación y vuelta al inicio de sesión.
class RecuperacionLayout extends StatelessWidget {
  const RecuperacionLayout({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.child,
  });

  final String titulo;
  final String descripcion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ManiColors.background,
      appBar: AppBar(
        backgroundColor: ManiColors.background,
        foregroundColor: ManiColors.ink,
        toolbarHeight: 60,
        leading: IconButton(
          key: const Key('volverAlLogin'),
          tooltip: 'Iniciar sesión',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Recuperar contraseña'),
      ),
      body: ManiTrama(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ManiPersonaje(),
                    const SizedBox(height: 16),
                    ManiCard(
                      enfasis: ManiEnfasis.protagonista,
                      sombra: ManiShadow.md,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(titulo, style: AppTheme.titulo(size: 20)),
                          const SizedBox(height: 8),
                          Text(
                            descripcion,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: ManiColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 20),
                          child,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de texto con el estilo de los formularios de acceso (el borde y el foco los pone el tema).
InputDecoration decoracionRecuperacion(String etiqueta, IconData icono) {
  return InputDecoration(
    labelText: etiqueta,
    prefixIcon: Icon(icono, color: ManiColors.ink, size: 18),
  );
}

/// Botón principal con indicador de carga.
class BotonRecuperacion extends StatelessWidget {
  const BotonRecuperacion({
    super.key,
    required this.texto,
    required this.cargando,
    required this.onPressed,
  });

  final String texto;
  final bool cargando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ManiButton(
      etiqueta: texto,
      onPressed: onPressed,
      cargando: cargando,
      expandir: true,
    );
  }
}
