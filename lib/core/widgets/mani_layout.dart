import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Ancho máximo del contenido en escritorio, el mismo de las pantallas de
/// registro: así todas las pantallas comparten columna y márgenes.
const anchoMaximoContenido = 1200.0;

/// Ancho a partir del cual las pantallas usan dos columnas, como el registro.
const anchoEscritorio = 850.0;

/// Centra el contenido con el ancho máximo y los márgenes del registro.
class ManiContenido extends StatelessWidget {
  const ManiContenido({super.key, required this.child, this.ancho});

  final Widget child;

  /// Ancho máximo propio, para formularios más angostos que la página.
  final double? ancho;

  static EdgeInsets margenes(double anchoPantalla) => anchoPantalla >= 600
      ? const EdgeInsets.symmetric(horizontal: 36, vertical: 24)
      : const EdgeInsets.all(16);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: ancho ?? anchoMaximoContenido),
        child: child,
      ),
    );
  }
}

/// Banner de cabecera de una pantalla: ícono en caja amarilla, título y
/// descripción en tarjeta blanca con borde y sombra dura (registro).
class ManiEncabezado extends StatelessWidget {
  const ManiEncabezado({
    super.key,
    required this.icono,
    required this.titulo,
    this.descripcion,
    this.tituloKey,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? descripcion;
  final Key? tituloKey;

  /// Botón opcional a la derecha (en móvil pasa debajo del texto).
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          key: tituloKey,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppTheme.dark,
            letterSpacing: -0.4,
          ),
        ),
        if (descripcion != null) ...[
          const SizedBox(height: 4),
          Text(
            descripcion!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: maniCaja(),
      child: LayoutBuilder(
        builder: (context, c) {
          final cabecera = Row(
            children: [
              ManiIconoCaja(icono: icono),
              const SizedBox(width: 16),
              Expanded(child: texto),
            ],
          );
          if (accion == null) return cabecera;
          if (c.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [cabecera, const SizedBox(height: 16), accion!],
            );
          }
          return Row(
            children: [
              Expanded(child: cabecera),
              const SizedBox(width: 16),
              accion!,
            ],
          );
        },
      ),
    );
  }
}

/// Forma de la caja de icono: `suave` es la de uso general; `fuerte`, la del encabezado de una página en web.
enum ManiIconoForma { suave, fuerte }

/// Ícono dentro de una caja. Es la única caja de icono de la app.
class ManiIconoCaja extends StatelessWidget {
  const ManiIconoCaja({
    super.key,
    required this.icono,
    this.forma = ManiIconoForma.suave,
  });

  final IconData icono;
  final ManiIconoForma forma;

  @override
  Widget build(BuildContext context) {
    final fuerte = forma == ManiIconoForma.fuerte;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: fuerte ? AppTheme.primary : AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusIcon),
        border: fuerte ? Border.all(color: AppTheme.dark, width: 2) : null,
        boxShadow: [if (fuerte) AppTheme.hardShadowSm],
      ),
      child: Icon(icono, color: AppTheme.dark, size: 22),
    );
  }
}

/// Etiqueta en mayúsculas sobre cada campo ("CORREO ELECTRÓNICO").
class ManiEtiquetaCampo extends StatelessWidget {
  const ManiEtiquetaCampo(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.dark,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Decoración de tarjeta del registro: blanco, borde de 2 px y sombra dura.
BoxDecoration maniCaja({
  Color color = AppTheme.surface,
  BoxShadow sombra = AppTheme.hardShadowMd,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(AppTheme.radius2xl),
  border: Border.all(color: AppTheme.dark, width: 2),
  boxShadow: [sombra],
);
