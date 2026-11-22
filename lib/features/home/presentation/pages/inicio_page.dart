import 'package:flutter/material.dart';
import 'package:mani/core/session/contexto_plataforma.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/app_shell.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/shell/menu_por_rol.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/features/home/data/resumen_inicio.dart';
import 'package:mani/features/home/presentation/widgets/inicio_movil.dart';
import 'package:mani/features/home/presentation/widgets/saludo_inicio.dart';

/// Pantalla de inicio neo-brutalista por tipo de usuario (US-11.2.3 / SCRUM-1446).
///
/// Saluda con la sesión, muestra el resumen que cada rol necesita y repite
/// sus accesos como tarjetas centradas y estructuradas en escritorio.
class InicioPage extends StatefulWidget {
  const InicioPage({
    super.key,
    required this.rol,
    required this.fuenteSesion,
    required this.fuenteResumen,
    required this.onNavegar,
    this.onCerrarSesion,
    this.contextoPlataforma,
  });

  final RolUsuario rol;
  final FuenteDatosSesion fuenteSesion;
  final FuenteResumenInicio fuenteResumen;
  final ValueChanged<String> onNavegar;
  final Future<void> Function()? onCerrarSesion;

  /// Contexto del administrador de plataforma (SCRUM-901): sus accesos y su
  /// resumen son los del rol con el que actúa.
  final ContextoPlataforma? contextoPlataforma;

  /// Rol cuyas pantallas se muestran: el propio, o el del contexto para el
  /// administrador de plataforma.
  RolUsuario get _rolDePantallas =>
      rol == RolUsuario.adminPlataforma && contextoPlataforma != null
      ? contextoPlataforma!.rolEfectivo
      : rol;

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  late Future<DatosSesion> _sesion;
  late Future<List<IndicadorResumen>> _resumen;

  @override
  void initState() {
    super.initState();
    _sesion = widget.fuenteSesion.cargar();
    _resumen = widget.fuenteResumen.cargar(widget._rolDePantallas);
  }

  @override
  Widget build(BuildContext context) {
    // En celular el inicio muestra solo los atajos a lo más usado; el resto vive en Servicios y Perfil (SCRUM-1647).
    final compacto = MediaQuery.sizeOf(context).width < anchoMenuExpandido;
    final accesos = compacto
        ? atajosPara(widget.rol, actuandoComo: widget._rolDePantallas)
        : entradasMenuPara(
            widget.rol,
            actuandoComo: widget._rolDePantallas,
          ).where((e) => e.ruta != '/inicio').toList();

    if (compacto) {
      return Scaffold(
        backgroundColor: context.mani.background,
        body: InicioMovil(
          sesion: _sesion,
          resumen: _resumen,
          atajos: accesos,
          subtitulo: _subtitulo(widget.rol),
          accionSaludo: accionSaludoPara(widget.rol),
          onNavegar: widget.onNavegar,
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.mani.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView(
            key: const Key('inicio-contenido'),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            children: [
              SaludoInicio(
                sesion: _sesion,
                subtitulo: _subtitulo(widget.rol),
                accion: accionSaludoPara(widget.rol),
                onNavegar: widget.onNavegar,
              ),

              if (widget.rol == RolUsuario.desconocido) ...[
                const SizedBox(height: 18),
                Card(
                  key: Key('inicio-sin-rol'),
                  color: Color(0xFFFEF9C3),
                  child: ListTile(
                    leading: Icon(Icons.info_outline, color: context.mani.ink),
                    title: Text(
                      'Tu cuenta no tiene un rol asignado',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'Pide al administrador de tu empresa que revise tu cuenta.',
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              FutureBuilder<List<IndicadorResumen>>(
                future: _resumen,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: context.mani.ink,
                        ),
                      ),
                    );
                  }
                  final indicadores = snap.data ?? const <IndicadorResumen>[];
                  if (indicadores.isEmpty) return const SizedBox.shrink();
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final i in indicadores)
                        _TarjetaIndicador(
                          indicador: i,
                          onTap: () => widget.onNavegar(i.ruta),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 22,
                    decoration: BoxDecoration(
                      color: context.mani.brand,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: context.mani.ink, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    compacto ? 'Atajos' : 'Accesos Rápidos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: context.mani.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Accesos en columnas: tres en escritorio, dos en tableta y una
              // en móvil. Cada tarjeta conserva el borde negro, la caja del
              // ícono y la flecha enmarcada (contraste alto sobre blanco).
              _RejillaAccesos(
                children: [
                  for (final e in accesos)
                    ManiCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      sombra: ManiShadow.sm,
                      child: ListTile(
                        key: Key('inicio-acceso-${e.ruta}'),
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.mani.brand,
                            borderRadius: BorderRadius.circular(ManiRadius.lg),
                            border: Border.all(
                              color: context.mani.ink,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            e.icono,
                            color: context.mani.onBrand,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          e.etiqueta,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.mani.ink,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: context.mani.background,
                            borderRadius: BorderRadius.circular(ManiRadius.lg),
                            border: Border.all(
                              color: context.mani.ink,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: context.mani.ink,
                            size: 18,
                          ),
                        ),
                        onTap: () => widget.onNavegar(e.ruta),
                      ),
                    ),
                ],
              ),
              if (widget.onCerrarSesion != null && !compacto) ...[
                const SizedBox(height: 20),
                ManiCard(
                  key: const Key('inicio-card-sesion'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  sombra: ManiShadow.sm,
                  child: ListTile(
                    key: const Key('inicio-cerrar-sesion'),
                    leading: const Icon(Icons.logout, color: _rojoSesion),
                    title: const Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _rojoSesion,
                      ),
                    ),
                    subtitle: const Text(
                      'Finaliza la sesión actual en este dispositivo',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: _rojoSesion,
                    ),
                    onTap: () async {
                      await widget.onCerrarSesion!();
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitulo(RolUsuario rol) {
    switch (rol) {
      case RolUsuario.cliente:
        return '¿Qué arreglamos hoy?';
      case RolUsuario.aliado:
        return 'Revisa tus solicitudes y mantén al día tu cobertura.';
      case RolUsuario.adminTenant:
        return 'Así va tu operación hoy.';
      case RolUsuario.adminPlataforma:
        return 'Así va la plataforma hoy.';
      case RolUsuario.desconocido:
        return 'Solo puedes consultar tu perfil por ahora.';
    }
  }
}

/// Rojo de "Cerrar sesión": #B91C1C da 6.5:1 sobre blanco (WCAG AA), a
/// diferencia de `Colors.redAccent`, que no llega a 4.5:1 para texto.
const _rojoSesion = Color(0xFFB91C1C);

/// Reparte las tarjetas de acceso en columnas de igual ancho según el espacio:
/// tres desde 900 px, dos desde 560 px y una en móvil.
class _RejillaAccesos extends StatelessWidget {
  const _RejillaAccesos({required this.children});

  final List<Widget> children;

  static const _espacio = 16.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth >= 900
            ? 3
            : c.maxWidth >= 560
            ? 2
            : 1;
        final ancho = (c.maxWidth - _espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: _espacio,
          runSpacing: _espacio,
          children: [
            for (final h in children) SizedBox(width: ancho, child: h),
          ],
        );
      },
    );
  }
}

class _TarjetaIndicador extends StatelessWidget {
  const _TarjetaIndicador({required this.indicador, required this.onTap});

  final IndicadorResumen indicador;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: ManiCard(
        padding: EdgeInsets.zero,
        sombra: ManiShadow.sm,
        child: InkWell(
          key: Key('inicio-indicador-${indicador.etiqueta}'),
          borderRadius: BorderRadius.circular(24.0),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.mani.brand,
                    borderRadius: BorderRadius.circular(ManiRadius.lg),
                    border: Border.all(color: context.mani.ink, width: 1.5),
                  ),
                  child: Text(
                    indicador.valor ?? '—',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: context.mani.onBrand,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  indicador.etiqueta,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.mani.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
