import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mani/core/session/contexto_plataforma.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/shell/menu_por_rol.dart';
import 'package:mani/core/shell/selector_contexto_plataforma.dart';
import 'package:mani/core/theme/app_theme.dart';
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
      duration: ManiMotion.base,
      curve: ManiMotion.entrada,
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
          backgroundColor: ManiColors.background,
          appBar: AppBar(
            key: const Key('menu-superior'),
            automaticallyImplyLeading: false,
            backgroundColor: ManiColors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 68,
            shape: const Border(bottom: ManiBorder.side),
            leading: expandido ? null : _menuCompacto(entradas),
            titleSpacing: expandido ? ManiSpace.xxxl : 0,
            title: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ManiColors.brand,
                      borderRadius: ManiRadius.brSm,
                      border: Border.all(
                        color: ManiColors.border,
                        width: ManiBorder.regular,
                      ),
                      boxShadow: const [ManiShadow.sm],
                    ),
                    child: const Text(
                      'M',
                      style: TextStyle(
                        fontSize: ManiFontSize.h3,
                        fontWeight: FontWeight.w900,
                        color: ManiColors.ink,
                      ),
                    ),
                  ),
                  ManiGap.hMd,
                  Expanded(
                    child: _CabeceraSesion(datos: _datos, rol: widget.rol),
                  ),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(
                  right: expandido ? ManiSpace.xxxl : ManiSpace.lg,
                ),
                child: Center(
                  child: expandido
                      ? OutlinedButton.icon(
                          key: const Key('menu-cerrar-sesion'),
                          onPressed: _cerrarSesion,
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Cerrar sesión'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ManiColors.ink,
                            backgroundColor: ManiColors.surface,
                            side: ManiBorder.side,
                            textStyle: const TextStyle(
                              fontSize: ManiFontSize.bodySm,
                              fontWeight: FontWeight.w800,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: ManiRadius.brMd,
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: ManiColors.surface,
                            borderRadius: ManiRadius.brSm,
                            border: Border.all(
                              color: ManiColors.border,
                              width: ManiBorder.regular,
                            ),
                            boxShadow: const [ManiShadow.sm],
                          ),
                          child: IconButton(
                            key: const Key('menu-cerrar-sesion'),
                            tooltip: 'Cerrar sesión',
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: ManiColors.ink,
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
      icon: const Icon(Icons.menu_rounded, color: ManiColors.ink),
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
              leading: Icon(e.icono, color: ManiColors.ink),
              title: Text(
                e.etiqueta,
                style: TextStyle(
                  fontWeight: _esActiva(e) ? FontWeight.w900 : FontWeight.w600,
                  color: ManiColors.ink,
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
            leading: Icon(Icons.logout, color: ManiColors.danger),
            title: Text(
              'Cerrar sesión',
              style: TextStyle(
                color: ManiColors.danger,
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
          color: ManiColors.background,
          border: Border(top: ManiBorder.sideThin),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: ManiSpace.sm),
              child: IconButton(
                key: const Key('menu-scroll-izq'),
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: ManiColors.ink,
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
                    thumbColor: ManiColors.ink.withValues(alpha: 0.35),
                    padding: const EdgeInsets.only(bottom: ManiSpace.xxs),
                    child: SingleChildScrollView(
                      controller: _menuScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: ManiSpace.sm,
                        vertical: ManiSpace.sm,
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
                                      ? ManiColors.brand
                                      : ManiColors.surface,
                                  borderRadius: ManiRadius.brMd,
                                  border: Border.all(
                                    color: ManiColors.border,
                                    width: ManiBorder.regular,
                                  ),
                                  boxShadow: _esActiva(e)
                                      ? const [ManiShadow.sm]
                                      : const [],
                                ),
                                child: TextButton.icon(
                                  key: Key('menu-entrada-${e.ruta}'),
                                  onPressed: () => widget.onNavegar(e.ruta),
                                  icon: Icon(
                                    e.icono,
                                    size: 18,
                                    color: ManiColors.ink,
                                  ),
                                  label: Text(
                                    e.etiqueta,
                                    style: TextStyle(
                                      fontSize: ManiFontSize.bodySm,
                                      fontWeight: _esActiva(e)
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: ManiColors.ink,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: ManiColors.ink,
                                    backgroundColor: _esActiva(e)
                                        ? ManiColors.brand
                                        : null,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: ManiSpace.lg,
                                      vertical: ManiSpace.sm,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: ManiRadius.brMd,
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
              padding: const EdgeInsets.only(right: ManiSpace.sm),
              child: IconButton(
                key: const Key('menu-scroll-der'),
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: ManiColors.ink,
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
                fontSize: ManiFontSize.bodyLg,
                fontWeight: FontWeight.w900,
                color: ManiColors.ink,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            ManiGap.vXxs,
            Text(
              linea2,
              key: const Key('menu-tenant'),
              style: const TextStyle(
                fontSize: ManiFontSize.caption,
                fontWeight: FontWeight.w700,
                color: ManiColors.inkMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}
