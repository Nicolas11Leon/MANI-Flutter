import 'package:flutter/material.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_personaje.dart';

/// La acción más probable de cada rol, que va en el botón del saludo.
typedef AccionSaludo = ({String etiqueta, String ruta});

/// Acción del saludo según el rol; `null` si el rol no tiene una (sin rol).
AccionSaludo? accionSaludoPara(RolUsuario rol) => switch (rol) {
  RolUsuario.cliente => (
    etiqueta: 'Pedir un servicio',
    ruta: '/cliente/solicitudes/nueva',
  ),
  RolUsuario.aliado => (
    etiqueta: 'Ver solicitudes',
    ruta: '/aliado/solicitudes',
  ),
  RolUsuario.adminTenant => (
    etiqueta: 'Verificar aliados',
    ruta: '/admin/verificacion-aliados',
  ),
  RolUsuario.adminPlataforma => (
    etiqueta: 'Ver tenants',
    ruta: '/plataforma/tenants',
  ),
  RolUsuario.desconocido => null,
};

/// «BUENOS DÍAS», «BUENAS TARDES» o «BUENAS NOCHES» según la hora.
String antetituloPorHora(DateTime ahora) {
  if (ahora.hour < 12) return 'BUENOS DÍAS';
  if (ahora.hour < 19) return 'BUENAS TARDES';
  return 'BUENAS NOCHES';
}

/// La pieza amarilla del inicio, igual en celular y web: antetítulo por hora, nombre, subtítulo del rol, una acción y
/// el muñequito que sobresale por arriba de la tarjeta.
class SaludoInicio extends StatelessWidget {
  const SaludoInicio({
    super.key,
    required this.sesion,
    required this.subtitulo,
    required this.accion,
    required this.onNavegar,
    this.reloj = DateTime.now,
  });

  final Future<DatosSesion> sesion;
  final String subtitulo;
  final AccionSaludo? accion;
  final ValueChanged<String> onNavegar;
  final DateTime Function() reloj;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = c.maxWidth >= 600;
        final muneco = ancho ? 120.0 : 84.0;
        final boton = accion == null
            ? null
            : ManiButton(
                key: const Key('inicio-saludo-accion'),
                etiqueta: accion!.etiqueta,
                variante: ManiButtonVariante.oscuro,
                onPressed: () => onNavegar(accion!.ruta),
              );
        final textos = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              antetituloPorHora(reloj()),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppTheme.dark,
              ),
            ),
            const SizedBox(height: 2),
            FutureBuilder<DatosSesion>(
              future: sesion,
              builder: (context, snap) => Text(
                snap.hasData ? snap.data!.nombreUsuario : 'Hola',
                key: const Key('inicio-saludo'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.titulo(
                  size: 26,
                  height: 1.2,
                  color: AppTheme.dark,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitulo,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.dark,
              ),
            ),
          ],
        );
        return ManiCard(
          enfasis: ManiEnfasis.protagonista,
          sombra: AppTheme.hardShadowMd,
          color: AppTheme.primary,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textos,
                    if (boton != null && !ancho) ...[
                      const SizedBox(height: 12),
                      boton,
                    ],
                  ],
                ),
              ),
              if (boton != null && ancho) ...[const SizedBox(width: 16), boton],
              const SizedBox(width: 8),
              // El muñequito va dentro de la tarjeta, no flotando fuera de ella.
              ManiPersonaje(alto: muneco),
            ],
          ),
        );
      },
    );
  }
}
