import 'package:flutter/material.dart';
import 'package:mani/core/session/contexto_plataforma.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/shell/menu_por_rol.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';
import 'package:mani/features/home/data/resumen_inicio.dart';

// Rutas que el inicio usa en varios sitios (acción primaria, accesos
// principales, descripciones y grupos).
const _rutaNuevaSolicitud = '/cliente/solicitudes/nueva';
const _rutaMisSolicitudes = '/cliente/solicitudes';
const _rutaBandejaAliado = '/aliado/solicitudes';
const _rutaCobrosAliado = '/aliado/cobros';
const _rutaVerificacion = '/admin/verificacion-aliados';
const _rutaTenants = '/plataforma/tenants';

/// Pantalla de inicio neo-brutalista por tipo de usuario (US-11.2.3 / SCRUM-1446).
///
/// Organiza el tablero con jerarquía visual clara:
/// 1. Encabezado operativo con contexto de rol/empresa y acción prioritaria.
/// 2. Franja de indicadores clave (KPIs) alineada a la retícula.
/// 3. Módulos de acceso agrupados por propósito operativo, diferenciando las
///    acciones principales de las herramientas de soporte y cuenta.
class InicioPage extends StatefulWidget {
  const InicioPage({
    super.key,
    required this.rol,
    required this.fuenteSesion,
    required this.fuenteResumen,
    required this.onNavegar,
    this.contextoPlataforma,
  });

  final RolUsuario rol;
  final FuenteDatosSesion fuenteSesion;
  final FuenteResumenInicio fuenteResumen;
  final ValueChanged<String> onNavegar;

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
    final t = context.mani;
    final rolActivo = widget._rolDePantallas;
    final accesos = entradasMenuPara(
      widget.rol,
      actuandoComo: rolActivo,
    ).where((e) => e.ruta != '/inicio').toList();

    final accionPrimaria = _accionPrimaria(rolActivo);
    final grupos = _agruparAccesos(accesos);

    return Scaffold(
      backgroundColor: t.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ManiAncho.panel),
          child: ListView(
            key: const Key('inicio-contenido'),
            padding: const EdgeInsets.symmetric(
              horizontal: ManiSpace.xxl,
              vertical: ManiSpace.lg,
            ),
            children: [
              // ── 1. Encabezado Operativo (Hero) ──────────────────────────
              _BannerHeroInicio(
                sesion: _sesion,
                rol: widget.rol,
                rolActivo: rolActivo,
                subtitulo: _subtitulo(widget.rol),
                accionPrimaria: accionPrimaria,
                onNavegar: widget.onNavegar,
              ),

              if (widget.rol == RolUsuario.desconocido) ...[
                ManiGap.vLg,
                Card(
                  key: const Key('inicio-sin-rol'),
                  color: t.brandSoft,
                  child: ListTile(
                    leading: Icon(Icons.info_outline, color: t.ink),
                    title: Text(
                      'Tu cuenta no tiene un rol asignado',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: t.ink,
                      ),
                    ),
                    subtitle: Text(
                      'Pide al administrador de tu empresa que revise tu cuenta.',
                      style: TextStyle(color: t.inkMuted),
                    ),
                  ),
                ),
              ],

              // ── 2. Resumen Operativo (KPIs) ─────────────────────────────
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
                  return Padding(
                    padding: const EdgeInsets.only(top: ManiSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ManiTituloSeccion(
                          icono: Icons.analytics_outlined,
                          titulo: 'Resumen operativo',
                        ),
                        ManiGap.vSm,
                        ManiRejilla(
                          anchoMinimo: 240,
                          maxColumnas: 3,
                          espacio: ManiSpace.md,
                          children: [
                            for (var idx = 0; idx < indicadores.length; idx++)
                              _TarjetaIndicador(
                                indicador: indicadores[idx],
                                destacado: idx == 0,
                                onTap: () =>
                                    widget.onNavegar(indicadores[idx].ruta),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              // ── 3. Accesos Rápidos Jerarquizados ────────────────────────
              ManiGap.vLg,
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 22,
                    decoration: BoxDecoration(
                      color: t.brand,
                      borderRadius: ManiRadius.brXs,
                      border: Border.all(
                        color: t.border,
                        width: ManiBorder.thin,
                      ),
                    ),
                  ),
                  ManiGap.hSm,
                  Text(
                    'Accesos Rápidos',
                    style: TextStyle(
                      fontSize: ManiFontSize.title,
                      fontWeight: FontWeight.w900,
                      color: t.ink,
                    ),
                  ),
                ],
              ),
              ManiGap.vSm,
              for (var g = 0; g < grupos.length; g++) ...[
                if (grupos.length > 1) ...[
                  if (g > 0) ManiGap.vXl,
                  _EncabezadoGrupo(
                    titulo: grupos[g].titulo,
                    icono: grupos[g].icono,
                  ),
                  ManiGap.vSm,
                ],
                _RejillaAccesos(
                  children: [
                    for (final e in grupos[g].entradas)
                      _TarjetaAcceso(
                        entrada: e,
                        esPrincipal: _esRutaPrincipal(e.ruta),
                        descripcion: _descripcionAcceso(e.ruta),
                        onTap: () => widget.onNavegar(e.ruta),
                      ),
                  ],
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
        return 'Publica solicitudes, consulta cotizaciones y administra tus sedes.';
      case RolUsuario.aliado:
        return 'Revisa solicitudes disponibles, cotiza trabajos y gestiona tu cobertura.';
      case RolUsuario.adminTenant:
        return 'Verifica aliados, configura tarifas y supervisa la operación de tu empresa.';
      case RolUsuario.adminPlataforma:
        return 'Administra los tenants y supervisa todas las funciones de la plataforma.';
      case RolUsuario.desconocido:
        return 'Solo puedes consultar tu perfil por ahora.';
    }
  }

  static ({String etiqueta, String ruta, IconData icono})? _accionPrimaria(
    RolUsuario rol,
  ) => switch (rol) {
    RolUsuario.cliente => (
      etiqueta: 'Publicar solicitud',
      ruta: _rutaNuevaSolicitud,
      icono: Icons.add_circle_outline_rounded,
    ),
    RolUsuario.aliado => (
      etiqueta: 'Revisar bandeja',
      ruta: _rutaBandejaAliado,
      icono: Icons.inbox_rounded,
    ),
    RolUsuario.adminTenant => (
      etiqueta: 'Revisar verificaciones',
      ruta: _rutaVerificacion,
      icono: Icons.verified_user_outlined,
    ),
    RolUsuario.adminPlataforma => (
      etiqueta: 'Administrar tenants',
      ruta: _rutaTenants,
      icono: Icons.domain_outlined,
    ),
    RolUsuario.desconocido => null,
  };

  static bool _esRutaPrincipal(String ruta) => const {
    _rutaNuevaSolicitud,
    _rutaMisSolicitudes,
    _rutaBandejaAliado,
    _rutaCobrosAliado,
    _rutaVerificacion,
    '/admin/metricas',
    _rutaTenants,
  }.contains(ruta);

  static String _descripcionAcceso(String ruta) => switch (ruta) {
    _rutaNuevaSolicitud =>
      'Describe tu requerimiento y adjunta evidencia fotográfica.',
    _rutaMisSolicitudes =>
      'Sigue el estado, cotizaciones y pagos de tus servicios activos.',
    '/cliente/historial' =>
      'Consulta trabajos finalizados y califica la atención recibida.',
    '/cliente/sedes' =>
      'Administra direcciones, contactos y reglas de acceso por sede.',
    '/cliente/quejas' =>
      'Revisa el estado y las respuestas a tus reclamaciones.',
    _rutaBandejaAliado =>
      'Acepta solicitudes disponibles en tu zona y gestiona tus trabajos.',
    '/aliado/historial' =>
      'Revisa servicios concluidos y calificaciones de clientes.',
    '/aliado/cobertura' =>
      'Declara los municipios, localidades y barrios donde trabajas.',
    '/categories' => 'Elige las especialidades técnicas que ofreces en la red.',
    _rutaCobrosAliado =>
      'Consulta pagos retenidos, comisiones y liquidaciones netas.',
    '/aliado/disponibilidad' =>
      'Activa o pausa tu disponibilidad y programa ausencias.',
    _rutaVerificacion =>
      'Valida documentos y aprueba o rechaza candidatos de tu red.',
    '/admin/categorias' =>
      'Define el catálogo de especialidades activas de tu empresa.',
    '/admin/empleados/nuevo' =>
      'Vincula técnicos de nómina directa a las categorías del tenant.',
    '/admin/tarifas' =>
      'Configura rangos de precios de referencia por categoría.',
    '/admin/reportes/cotizaciones-fuera-de-rango' =>
      'Audita cotizaciones que se desvían del tarifario vigente.',
    '/admin/reglas' =>
      'Ajusta topes de adiciones, comisiones y parámetros operativos.',
    '/admin/politica-cancelacion' =>
      'Configura cargos y ventanas de cancelación tardía.',
    '/admin/metricas' =>
      'Analiza volumen, conversión, ingresos y calidad del periodo.',
    '/admin/quejas' =>
      'Atiende y resuelve reclamaciones abiertas por los clientes.',
    '/admin/auditoria-transacciones' =>
      'Inspecciona la bitácora inmutable de eventos de pago.',
    '/admin/conversaciones' =>
      'Revisa el historial de mensajes asociado a una queja.',
    _rutaTenants =>
      'Habilita, suspende o inactiva empresas registradas en MANI.',
    '/catalogo/mapa' =>
      'Explora los límites geográficos de zonas y barrios del catálogo.',
    '/perfil/avisos' =>
      'Notificaciones recientes sobre mensajes y cambios de estado.',
    '/perfil/editar' =>
      'Actualiza tus datos de contacto, foto y preferencias de cuenta.',
    _ => 'Abre este módulo para gestionar su información.',
  };

  static List<_GrupoModulo> _agruparAccesos(List<EntradaMenu> entradas) {
    if (entradas.length <= 8) {
      return [
        _GrupoModulo(
          titulo: 'Módulos del rol',
          icono: Icons.grid_view_rounded,
          entradas: entradas,
        ),
      ];
    }

    const rutasOperacion = {
      _rutaTenants,
      _rutaVerificacion,
      '/admin/categorias',
      '/admin/empleados/nuevo',
      '/catalogo/mapa',
      _rutaNuevaSolicitud,
      _rutaMisSolicitudes,
      '/cliente/sedes',
      _rutaBandejaAliado,
      '/aliado/cobertura',
      '/categories',
      '/aliado/disponibilidad',
    };
    const rutasReglasYFinanzas = {
      '/admin/tarifas',
      '/admin/reportes/cotizaciones-fuera-de-rango',
      '/admin/reglas',
      '/admin/politica-cancelacion',
      _rutaCobrosAliado,
    };

    final operacion = <EntradaMenu>[];
    final reglas = <EntradaMenu>[];
    final supervision = <EntradaMenu>[];

    for (final e in entradas) {
      if (rutasOperacion.contains(e.ruta)) {
        operacion.add(e);
      } else if (rutasReglasYFinanzas.contains(e.ruta)) {
        reglas.add(e);
      } else {
        supervision.add(e);
      }
    }

    return [
      if (operacion.isNotEmpty)
        _GrupoModulo(
          titulo: 'Operación y red de servicio',
          icono: Icons.handyman_outlined,
          entradas: operacion,
        ),
      if (reglas.isNotEmpty)
        _GrupoModulo(
          titulo: 'Tarifas, reglas y políticas',
          icono: Icons.tune_rounded,
          entradas: reglas,
        ),
      if (supervision.isNotEmpty)
        _GrupoModulo(
          titulo: 'Supervisión, analítica y cuenta',
          icono: Icons.insights_outlined,
          entradas: supervision,
        ),
    ];
  }
}

class _GrupoModulo {
  const _GrupoModulo({
    required this.titulo,
    required this.icono,
    required this.entradas,
  });

  final String titulo;
  final IconData icono;
  final List<EntradaMenu> entradas;
}

class _BannerHeroInicio extends StatelessWidget {
  const _BannerHeroInicio({
    required this.sesion,
    required this.rol,
    required this.rolActivo,
    required this.subtitulo,
    required this.accionPrimaria,
    required this.onNavegar,
  });

  final Future<DatosSesion> sesion;
  final RolUsuario rol;
  final RolUsuario rolActivo;
  final String subtitulo;
  final ({String etiqueta, String ruta, IconData icono})? accionPrimaria;
  final ValueChanged<String> onNavegar;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return ManiCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Franja superior de contexto (ficha sellada)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ManiSpace.lg,
              vertical: ManiSpace.xs,
            ),
            decoration: BoxDecoration(
              color: t.surfaceWarm,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ManiRadius.lg - 2),
              ),
              border: Border(
                bottom: BorderSide(color: t.border, width: ManiBorder.thin),
              ),
            ),
            child: FutureBuilder<DatosSesion>(
              future: sesion,
              builder: (context, snap) {
                final tenant = snap.data?.nombreTenant;
                return Wrap(
                  spacing: ManiSpace.sm,
                  runSpacing: ManiSpace.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ManiStatusBadge(
                      etiqueta: etiquetaRol(rolActivo),
                      tono: ManiTono.marca,
                      icono: Icons.verified_outlined,
                      compacto: true,
                    ),
                    if (tenant != null && tenant.isNotEmpty)
                      ManiStatusBadge(
                        etiqueta: tenant,
                        tono: ManiTono.acento,
                        icono: Icons.domain_outlined,
                        compacto: true,
                        mayusculas: false,
                      ),
                  ],
                );
              },
            ),
          ),
          // Cuerpo principal del Hero
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ManiSpace.xl,
              vertical: ManiSpace.lg,
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final amplio = c.maxWidth >= 560;
                final saludoColumna = Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(ManiSpace.sm),
                      decoration: BoxDecoration(
                        color: t.brand,
                        borderRadius: ManiRadius.brMd,
                        border: Border.all(
                          color: t.border,
                          width: ManiBorder.regular,
                        ),
                        boxShadow: [t.shadowSm],
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        color: t.onBrand,
                        size: 24,
                      ),
                    ),
                    ManiGap.hMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<DatosSesion>(
                            future: sesion,
                            builder: (context, snap) => Text(
                              snap.hasData
                                  ? 'Hola, ${snap.data!.nombreUsuario}'
                                  : 'Hola',
                              key: const Key('inicio-saludo'),
                              style: TextStyle(
                                fontSize: ManiFontSize.h2,
                                fontWeight: FontWeight.w900,
                                color: t.ink,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          ManiGap.vXxs,
                          Text(
                            subtitulo,
                            style: TextStyle(
                              fontSize: ManiFontSize.bodySm,
                              fontWeight: FontWeight.w600,
                              color: t.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                if (accionPrimaria == null) return saludoColumna;

                final boton = ManiButton(
                  etiqueta: accionPrimaria!.etiqueta,
                  icono: accionPrimaria!.icono,
                  onPressed: () => onNavegar(accionPrimaria!.ruta),
                );

                if (!amplio) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [saludoColumna, ManiGap.vMd, boton],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: saludoColumna),
                    ManiGap.hLg,
                    boton,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EncabezadoGrupo extends StatelessWidget {
  const _EncabezadoGrupo({required this.titulo, required this.icono});

  final String titulo;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return Row(
      children: [
        Icon(icono, size: 16, color: t.inkMuted),
        ManiGap.hXs,
        Text(
          titulo.toUpperCase(),
          style: TextStyle(
            fontSize: ManiFontSize.caption,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            color: t.inkMuted,
          ),
        ),
        ManiGap.hMd,
        Expanded(child: Container(height: 1.5, color: t.borderSubtle)),
      ],
    );
  }
}

class _TarjetaAcceso extends StatelessWidget {
  const _TarjetaAcceso({
    required this.entrada,
    required this.esPrincipal,
    required this.descripcion,
    required this.onTap,
  });

  final EntradaMenu entrada;
  final bool esPrincipal;
  final String descripcion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return ManiCard(
      padding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.md,
        vertical: ManiSpace.xxs,
      ),
      sombra: t.shadowSm,
      child: ListTile(
        key: Key('inicio-acceso-${entrada.ruta}'),
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: esPrincipal ? t.brand : t.surfaceMuted,
            borderRadius: ManiRadius.brSm,
            border: Border.all(
              color: t.border,
              width: esPrincipal ? ManiBorder.regular : ManiBorder.thin,
            ),
            boxShadow: esPrincipal ? [t.shadowSm] : const [],
          ),
          child: Icon(
            entrada.icono,
            color: esPrincipal ? t.onBrand : t.ink,
            size: 18,
          ),
        ),
        title: Text(
          entrada.etiqueta,
          style: TextStyle(
            fontSize: ManiFontSize.body,
            fontWeight: FontWeight.w800,
            color: t.ink,
          ),
        ),
        subtitle: Text(
          descripcion,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ManiFontSize.caption,
            fontWeight: FontWeight.w500,
            color: t.inkMuted,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(ManiSpace.xs),
          decoration: BoxDecoration(
            color: esPrincipal ? t.brandSoft : t.background,
            borderRadius: ManiRadius.brSm,
            border: Border.all(color: t.border, width: ManiBorder.thin),
          ),
          child: Icon(Icons.arrow_forward_rounded, color: t.ink, size: 15),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Reparte las tarjetas de acceso en columnas de igual ancho según el espacio:
/// tres desde 900 px, dos desde 560 px y una en móvil.
class _RejillaAccesos extends StatelessWidget {
  const _RejillaAccesos({required this.children});

  final List<Widget> children;

  static const _espacio = 12.0;

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
  const _TarjetaIndicador({
    required this.indicador,
    required this.onTap,
    this.destacado = false,
  });

  final IndicadorResumen indicador;
  final VoidCallback onTap;
  final bool destacado;

  static IconData _iconoPara(String etiqueta) {
    final l = etiqueta.toLowerCase();
    if (l.contains('sede')) return Icons.apartment_rounded;
    if (l.contains('categor')) return Icons.category_rounded;
    if (l.contains('estado')) return Icons.bolt_rounded;
    if (l.contains('ausencia')) return Icons.event_busy_rounded;
    if (l.contains('verificar') || l.contains('aliado')) {
      return Icons.verified_user_rounded;
    }
    return Icons.insights_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return ManiCard(
      padding: EdgeInsets.zero,
      sombra: t.shadowSm,
      child: InkWell(
        key: Key('inicio-indicador-${indicador.etiqueta}'),
        borderRadius: ManiRadius.brLg,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ManiSpace.lg,
            vertical: ManiSpace.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(ManiSpace.xs),
                    decoration: BoxDecoration(
                      color: destacado ? t.brand : t.brandSoft,
                      borderRadius: ManiRadius.brSm,
                      border: Border.all(
                        color: t.border,
                        width: ManiBorder.thin,
                      ),
                    ),
                    child: Icon(
                      _iconoPara(indicador.etiqueta),
                      size: 16,
                      color: destacado ? t.onBrand : t.ink,
                    ),
                  ),
                  Icon(Icons.north_east_rounded, size: 16, color: t.inkMuted),
                ],
              ),
              ManiGap.vSm,
              Text(
                indicador.valor ?? '—',
                style: TextStyle(
                  fontSize: ManiFontSize.h2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.05,
                  color: t.ink,
                ),
              ),
              ManiGap.vXxs,
              Text(
                indicador.etiqueta,
                style: TextStyle(
                  fontSize: ManiFontSize.bodySm,
                  fontWeight: FontWeight.w800,
                  color: t.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
