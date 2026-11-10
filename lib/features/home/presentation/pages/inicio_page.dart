import 'package:flutter/material.dart';
import 'package:mani/core/session/contexto_plataforma.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/shell/menu_por_rol.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/features/home/data/resumen_inicio.dart';
import 'package:mani/core/widgets/mani_estado.dart';

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
    final accesos = entradasMenuPara(
      widget.rol,
      actuandoComo: widget._rolDePantallas,
    ).where((e) => e.ruta != '/inicio').toList();

    return Scaffold(
      backgroundColor: ManiColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            key: const Key('inicio-contenido'),
            padding: const EdgeInsets.symmetric(
              horizontal: ManiSpace.xxl,
              vertical: ManiSpace.xxl,
            ),
            children: [
              // ── Banner Hero Neo-Brutalista ──────────────────────────────
              ManiCard(
                padding: const EdgeInsets.all(ManiSpace.xxl),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(ManiSpace.md),
                      decoration: BoxDecoration(
                        color: ManiColors.brand,
                        borderRadius: ManiRadius.brMd,
                        border: Border.all(
                          color: ManiColors.border,
                          width: ManiBorder.regular,
                        ),
                        boxShadow: const [ManiShadow.sm],
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: ManiColors.ink,
                        size: 28,
                      ),
                    ),
                    ManiGap.hLg,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<DatosSesion>(
                            future: _sesion,
                            builder: (context, snap) => Text(
                              snap.hasData
                                  ? 'Hola, ${snap.data!.nombreUsuario}'
                                  : 'Hola',
                              key: const Key('inicio-saludo'),
                              style: const TextStyle(
                                fontSize: ManiFontSize.h2,
                                fontWeight: FontWeight.w900,
                                color: ManiColors.ink,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          ManiGap.vSm,
                          Text(
                            _subtitulo(widget.rol),
                            style: const TextStyle(
                              fontSize: ManiFontSize.body,
                              fontWeight: FontWeight.w600,
                              color: ManiColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.rol == RolUsuario.desconocido) ...[
                ManiGap.vLg,
                const Card(
                  key: Key('inicio-sin-rol'),
                  color: ManiColors.brandSoft,
                  child: ListTile(
                    leading: Icon(Icons.info_outline, color: ManiColors.ink),
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

              ManiGap.vXxl,
              FutureBuilder<List<IndicadorResumen>>(
                future: _resumen,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(ManiSpace.xxl),
                      child: ManiCargando(),
                    );
                  }
                  final indicadores = snap.data ?? const <IndicadorResumen>[];
                  if (indicadores.isEmpty) return const SizedBox.shrink();
                  return Wrap(
                    spacing: ManiSpace.lg,
                    runSpacing: ManiSpace.lg,
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
              ManiGap.vXxl,
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 22,
                    decoration: BoxDecoration(
                      color: ManiColors.brand,
                      borderRadius: ManiRadius.brXs,
                      border: Border.all(
                        color: ManiColors.border,
                        width: ManiBorder.thin,
                      ),
                    ),
                  ),
                  ManiGap.hSm,
                  const Text(
                    'Accesos Rápidos',
                    style: TextStyle(
                      fontSize: ManiFontSize.title,
                      fontWeight: FontWeight.w900,
                      color: ManiColors.ink,
                    ),
                  ),
                ],
              ),
              ManiGap.vMd,
              // Accesos en columnas: tres en escritorio, dos en tableta y una
              // en móvil. Cada tarjeta conserva el borde negro, la caja del
              // ícono y la flecha enmarcada (contraste alto sobre blanco).
              _RejillaAccesos(
                children: [
                  for (final e in accesos)
                    ManiCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ManiSpace.lg,
                        vertical: ManiSpace.sm,
                      ),
                      sombra: ManiShadow.sm,
                      child: ListTile(
                        key: Key('inicio-acceso-${e.ruta}'),
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: ManiColors.brand,
                            borderRadius: ManiRadius.brSm,
                            border: Border.all(
                              color: ManiColors.border,
                              width: ManiBorder.regular,
                            ),
                          ),
                          child: Icon(e.icono, color: ManiColors.ink, size: 20),
                        ),
                        title: Text(
                          e.etiqueta,
                          style: const TextStyle(
                            fontSize: ManiFontSize.body,
                            fontWeight: FontWeight.w800,
                            color: ManiColors.ink,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.all(ManiSpace.sm),
                          decoration: BoxDecoration(
                            color: ManiColors.background,
                            borderRadius: ManiRadius.brSm,
                            border: Border.all(
                              color: ManiColors.border,
                              width: ManiBorder.thin,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: ManiColors.ink,
                            size: 18,
                          ),
                        ),
                        onTap: () => widget.onNavegar(e.ruta),
                      ),
                    ),
                ],
              ),
              if (widget.onCerrarSesion != null) ...[
                ManiGap.vXl,
                ManiCard(
                  key: const Key('inicio-card-sesion'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: ManiSpace.lg,
                    vertical: ManiSpace.sm,
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
        return 'Publica solicitudes y administra tus sedes.';
      case RolUsuario.aliado:
        return 'Revisa las solicitudes y mantén al día tu cobertura.';
      case RolUsuario.adminTenant:
        return 'Verifica aliados y administra el catálogo de tu empresa.';
      case RolUsuario.adminPlataforma:
        return 'Administra los tenants y accede a todas las funciones de la plataforma.';
      case RolUsuario.desconocido:
        return 'Solo puedes consultar tu perfil por ahora.';
    }
  }
}

/// Rojo de "Cerrar sesión": #B91C1C da 6.5:1 sobre blanco (WCAG AA), a
/// diferencia de `Colors.redAccent`, que no llega a 4.5:1 para texto.
const _rojoSesion = ManiColors.dangerText;

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
          borderRadius: ManiRadius.brLg,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(ManiSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ManiSpace.sm,
                    vertical: ManiSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: ManiColors.brand,
                    borderRadius: ManiRadius.brSm,
                    border: Border.all(
                      color: ManiColors.border,
                      width: ManiBorder.thin,
                    ),
                  ),
                  child: Text(
                    indicador.valor ?? '—',
                    style: const TextStyle(
                      fontSize: ManiFontSize.h3,
                      fontWeight: FontWeight.w900,
                      color: ManiColors.ink,
                    ),
                  ),
                ),
                ManiGap.vSm,
                Text(
                  indicador.etiqueta,
                  style: const TextStyle(
                    fontSize: ManiFontSize.bodySm,
                    fontWeight: FontWeight.w800,
                    color: ManiColors.ink,
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
