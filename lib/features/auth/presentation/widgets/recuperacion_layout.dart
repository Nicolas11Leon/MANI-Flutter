import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mani/core/theme/app_theme.dart';

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
        backgroundColor: Colors.white,
        foregroundColor: ManiColors.ink,
        leading: IconButton(
          key: const Key('volverAlLogin'),
          tooltip: 'Iniciar sesión',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        title: Text(
          'Recuperar contraseña',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ManiSpace.xxl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(ManiSpace.xxl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: ManiRadius.brLg,
                  border: Border.all(
                    color: ManiColors.border,
                    width: ManiBorder.regular,
                  ),
                  boxShadow: const [ManiShadow.md],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      titulo,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: ManiFontSize.h3,
                        fontWeight: FontWeight.w900,
                        color: ManiColors.ink,
                      ),
                    ),
                    ManiGap.vSm,
                    Text(
                      descripcion,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: ManiFontSize.bodySm,
                        color: ManiColors.inkMuted,
                      ),
                    ),
                    ManiGap.vXl,
                    child,
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

/// Campo de texto con el estilo de los formularios de acceso.
InputDecoration decoracionRecuperacion(String etiqueta, IconData icono) {
  return InputDecoration(
    labelText: etiqueta,
    prefixIcon: Icon(icono, color: ManiColors.ink, size: 18),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: ManiRadius.brMd,
      borderSide: ManiBorder.side,
    ),
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
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: ManiColors.brand,
          foregroundColor: ManiColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: ManiRadius.brMd,
            side: ManiBorder.side,
          ),
        ),
        onPressed: cargando ? null : onPressed,
        child: cargando
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: ManiColors.ink,
                ),
              )
            : Text(
                texto,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
      ),
    );
  }
}
