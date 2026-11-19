import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mani/core/session/contexto_plataforma.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/shell/menu_por_rol.dart';
import 'package:mani/core/shell/selector_contexto_plataforma.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_logo.dart';
import 'package:mani/features/platform/data/tenants_datasource.dart';

/// Ancho a partir del cual las entradas se muestran como barra; por debajo
/// se agrupan en un menú desplegable para que quepan en móvil (RNF-08).
const anchoMenuExpandido = 600.0;

/// Armazón neo-brutalista de las pantallas con sesión (US-11.2.1 / SCRUM-1444).
///
/// Pinta el menú superior con las entradas del [rol], el usuario y el tenant
/// de la sesión, y la acción de cerrar sesión en todas las pantallas. Usa la
/// barra superior de las pantallas de registro (logo, borde negro) y centra el
/// contenido con el mismo ancho máximo. La pantalla de cada ruta llega como
/// [child] y conserva su propio título.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.rol,
    required this.ubicacion,
    required this.fuenteDatos,
    required this.onNavegar,
    required this.onCerrarSesion,
    this.contextoPlataforma,
    this.fuenteTenants,
    this.fuenteUsuarios,
  });

  final Widget child;
  final RolUsuario rol;

  /// Ruta actual (`state.matchedLocation`), para resaltar la entrada activa.
  final String ubicacion;
  final FuenteDatosSesion fuenteDatos;
  final ValueChanged<String> onNavegar;
  final Future<void> Function() onCerrarSesion;

  /// Contexto del administrador de plataforma (SCRUM-901): tenant elegido y
  /// usuario con el que actúa. Solo se usa con [RolUsuario.adminPlataforma].
  final ContextoPlataforma? contextoPlataforma;
  final FuenteTenants? fuenteTenants;
  final FuenteUsuariosTenant? fuenteUsuarios;

  bool get _conContexto =>
      rol == RolUsuario.adminPlataforma &&
      contextoPlataforma != null &&
      fuenteTenants != null &&
      fuenteUsuarios != null;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late Future<DatosSesion> _datos;
  final ScrollController _menuScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _datos = widget.fuenteDatos.cargar();
  }

  @override
  void dispose() {
    _menuScrollController.dispose();
    super.dispose();
  }

  void _scrollBarra(double delta) {
    if (!_menuScrollController.hasClients) return;
    final target = (_menuScrollController.offset + delta).clamp(
      0.0,
      _menuScrollController.position.maxScrollExtent,
    );
    _menuScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  bool _coincide(EntradaMenu e) =>
      widget.ubicacion == e.ruta || widget.ubicacion.startsWith('${e.ruta}/');

  /// Solo la entrada más específica queda activa: en
  /// `/cliente/solicitudes/nueva` se resalta "Nueva solicitud" y no también
  /// "Mis solicitudes", cuya ruta es prefijo de la actual.
  bool _esActiva(EntradaMenu e) {
    if (!_coincide(e)) return false;
    return !_entradas().any(
      (o) => o.ruta.length > e.ruta.length && _coincide(o),
    );
  }

  /// Entradas del rol; el admin de plataforma ve las del rol con el que actúa.
  List<EntradaMenu> _entradas() => widget._conContexto
      ? entradasMenuPara(
          widget.rol,
          actuandoComo: widget.contextoPlataforma!.rolEfectivo,
        )
      : entradasMenuPara(widget.rol);
  Future<void> _cerrarSesion() async {
    await widget.onCerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    final contexto = widget.contextoPlataforma;
    if (!widget._conContexto || contexto == null) return _armazon(context);
    // Con cada cambio de contexto se repinta el menú y se recarga la pantalla.
    return ListenableBuilder(
      listenable: contexto,
      builder: (context, _) => _armazon(context),
    );
  }

  Widget _armazon(BuildContext context) {
    final entradas = _entradas();
    final contexto = widget._conContexto ? widget.contextoPlataforma : null;
    final cuerpo = contexto == null
        ? widget.child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectorContextoPlataforma(
                contexto: contexto,
                fuenteTenants: widget.fuenteTenants!,
                fuenteUsuarios: widget.fuenteUsuarios!,
                alCambiar: () => widget.onNavegar('/inicio'),
              ),
              Expanded(
                // Pantallas nuevas con el contexto nuevo: sus cubits vuelven a
                // consultar con las cabeceras actualizadas.
                child: KeyedSubtree(
                  key: ValueKey('contexto-${contexto.version}'),
                  child: widget.child,
                ),
              ),
            ],
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final expandido = constraints.maxWidth >= anchoMenuExpandido;
        return Scaffold(
          key: const Key('app-shell'),
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            key: const Key('menu-superior'),
            automaticallyImplyLeading: false,
            backgroundColor: AppTheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 68,
            shape: const Border(
              bottom: BorderSide(color: AppTheme.dark, width: 2),
            ),
            leading: expandido ? null : _menuCompacto(entradas),
            titleSpacing: expandido ? 32 : 0,
            title: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  ManiLogo(size: 40, sombra: AppTheme.hardShadowSm),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CabeceraSesion(datos: _datos, rol: widget.rol),
                  ),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: expandido ? 32 : 16),
                child: Center(
                  child: expandido
                      ? OutlinedButton.icon(
                          key: const Key('menu-cerrar-sesion'),
                          onPressed: _cerrarSesion,
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Cerrar sesión'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.dark,
                            backgroundColor: AppTheme.surface,
                            side: const BorderSide(
                              color: AppTheme.dark,
                              width: 2,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusXl,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            border: Border.all(color: AppTheme.dark, width: 2),
                            boxShadow: const [AppTheme.hardShadowSm],
                          ),
                          child: IconButton(
                            key: const Key('menu-cerrar-sesion'),
                            tooltip: 'Cerrar sesión',
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: AppTheme.dark,
                              size: 20,
                            ),
                            onPressed: _cerrarSesion,
                          ),
                        ),
                ),
              ),
            ],
            bottom: expandido ? _barraEntradas(context, entradas) : null,
          ),
          body: cuerpo,
        );
      },
    );
  }

  Widget _menuCompacto(List<EntradaMenu> entradas) {
    return PopupMenuButton<String>(
      key: const Key('menu-compacto'),
      tooltip: 'Menú',
      icon: const Icon(Icons.menu_rounded, color: AppTheme.dark),
      onSelected: (val) {
        if (val == '__logout__') {
          _cerrarSesion();
        } else {
          widget.onNavegar(val);
        }
      },
      itemBuilder: (context) => [
        for (final e in entradas)
          PopupMenuItem<String>(
            key: Key('menu-entrada-${e.ruta}'),
            value: e.ruta,
            child: ListTile(
              leading: Icon(e.icono, color: AppTheme.dark),
              title: Text(
                e.etiqueta,
                style: TextStyle(
                  fontWeight: _esActiva(e) ? FontWeight.w900 : FontWeight.w600,
                  color: AppTheme.dark,
                ),
              ),
              selected: _esActiva(e),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          key: Key('menu-compacto-cerrar-sesion'),
          value: '__logout__',
          child: ListTile(
            leading: Icon(Icons.logout, color: AppTheme.error),
            title: Text(
              'Cerrar sesión',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _barraEntradas(
    BuildContext context,
    List<EntradaMenu> entradas,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(62),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppTheme.background,
          border: Border(top: BorderSide(color: AppTheme.dark, width: 1.5)),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: IconButton(
                key: const Key('menu-scroll-izq'),
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppTheme.dark,
                ),
                tooltip: 'Desplazar a la izquierda',
                onPressed: () => _scrollBarra(-280),
              ),
            ),
            Expanded(
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent &&
                      _menuScrollController.hasClients) {
                    final delta = pointerSignal.scrollDelta.dy != 0
                        ? pointerSignal.scrollDelta.dy
                        : pointerSignal.scrollDelta.dx;
                    final target = (_menuScrollController.offset + delta).clamp(
                      0.0,
                      _menuScrollController.position.maxScrollExtent,
                    );
                    _menuScrollController.jumpTo(target);
                  }
                },
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: RawScrollbar(
                    controller: _menuScrollController,
                    thumbVisibility: true,
                    thickness: 4,
                    radius: const Radius.circular(2),
                    thumbColor: AppTheme.dark.withValues(alpha: 0.35),
                    padding: const EdgeInsets.only(bottom: 2),
                    child: SingleChildScrollView(
                      controller: _menuScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          for (final e in entradas)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _esActiva(e)
                                      ? AppTheme.primary
                                      : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusXl,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.dark,
                                    width: 2,
                                  ),
                                  boxShadow: _esActiva(e)
                                      ? const [AppTheme.hardShadowSm]
                                      : const [],
                                ),
                                child: TextButton.icon(
                                  key: Key('menu-entrada-${e.ruta}'),
                                  onPressed: () => widget.onNavegar(e.ruta),
                                  icon: Icon(
                                    e.icono,
                                    size: 18,
                                    color: AppTheme.dark,
                                  ),
                                  label: Text(
                                    e.etiqueta,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _esActiva(e)
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: AppTheme.dark,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.dark,
                                    backgroundColor: _esActiva(e)
                                        ? AppTheme.primary
                                        : null,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusXl,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton(
                key: const Key('menu-scroll-der'),
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.dark,
                ),
                tooltip: 'Desplazar a la derecha',
                onPressed: () => _scrollBarra(280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo, usuario, rol y tenant de la sesión. Mientras carga muestra solo el
/// rol, y si Core no responde muestra el rol sin nombre: el menú sigue usable.
class _CabeceraSesion extends StatelessWidget {
  const _CabeceraSesion({required this.datos, required this.rol});

  final Future<DatosSesion> datos;
  final RolUsuario rol;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DatosSesion>(
      future: datos,
      builder: (context, snap) {
        final d = snap.data;
        final usuario = d?.nombreUsuario;
        final linea2 = [
          etiquetaRol(rol),
          if (d?.nombreTenant != null) d!.nombreTenant!,
        ].join(' · ');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              usuario ?? 'MANI',
              key: const Key('menu-usuario'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.dark,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              linea2,
              key: const Key('menu-tenant'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}
