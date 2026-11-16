import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mani/core/session/contexto_plataforma.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/shell/menu_por_rol.dart';
import 'package:mani/core/shell/navegacion_movil.dart';
import 'package:mani/core/shell/recargar_al_activar.dart';
import 'package:mani/core/shell/sin_deslizar_menus.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';
import 'package:mani/core/shell/selector_contexto_plataforma.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_logo.dart';
import 'package:mani/features/notifications/data/avisos_datasource.dart';
import 'package:mani/features/platform/data/tenants_datasource.dart';

/// Ancho a partir del cual las entradas se muestran como barra; por debajo
/// se agrupan en un menú desplegable para que quepan en móvil (RNF-08).
const anchoMenuExpandido = 600.0;

/// Pantallas principales que son un flujo con su propia barra de acciones abajo («Atrás / Continuar», el resumen de la
/// cobertura…) y adónde sale la flecha de arriba. En celular no llevan la barra de menú, que se apilaría con la suya y
/// dejaría poco espacio. Las que se abren apiladas sobre el armazón (como el pago) se declaran en el enrutador, por
/// encima de él (SCRUM-1647).
const salidaDeFlujo = {
  '/cliente/solicitudes/nueva': '/inicio',
  '/aliado/cobertura': rutaCuenta,
};

/// Las rutas de [salidaDeFlujo].
final rutasDeFlujo = salidaDeFlujo.keys.toSet();

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
    this.puedeVolver,
    this.onVolver,
    this.fuenteAvisos,
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

  /// Pila de navegación del enrutador: si hay una pantalla anterior, «volver» regresa a ella en lugar de ir a una ruta
  /// fija. Sin ella, «volver» usa [onNavegar] hacia la pantalla principal de la sección.
  final bool Function()? puedeVolver;
  final VoidCallback? onVolver;

  /// Bandeja de avisos, para el número de la campana del cliente en celular; sin ella la campana no muestra número.
  final FuenteAvisos? fuenteAvisos;

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

  /// Avisos sin leer, para la campana del cliente en celular.
  Future<int>? _sinLeer;

  @override
  void initState() {
    super.initState();
    _datos = widget.fuenteDatos.cargar();
    _recargarAvisos();
    _avisarPestana();
    titulosDePantalla.addListener(_alCambiarTitulo);
  }

  void _alCambiarTitulo() {
    if (mounted) setState(() {});
  }

  /// Avisa qué pestaña principal se abrió, para que las que llevan tiempo fuera se recarguen al volver. Se hace después
  /// del cuadro actual: quien escucha reconstruye su pantalla y no se puede hacer en pleno armado.
  void _avisarPestana() {
    final ruta = widget.ubicacion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _raicesMovil.contains(ruta)) {
        activacionDePestanas.activar(ruta);
      }
    });
  }

  @override
  void didUpdateWidget(AppShell anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.ubicacion != widget.ubicacion) _avisarPestana();
    // Al volver de la bandeja o llegar al inicio el número se actualiza: ahí es donde cambia o donde se mira.
    if (anterior.ubicacion != widget.ubicacion &&
        (anterior.ubicacion == '/perfil/avisos' ||
            widget.ubicacion == '/inicio')) {
      _recargarAvisos();
    }
  }

  void _recargarAvisos() {
    final fuente = widget.fuenteAvisos;
    if (_navMovil == null || fuente == null) {
      _sinLeer = null;
      return;
    }
    _sinLeer = fuente
        .listar(limite: 50)
        .then((b) => b.items.where((a) => !a.leido).length)
        .catchError((Object _) => 0);
  }

  @override
  void dispose() {
    titulosDePantalla.removeListener(_alCambiarTitulo);
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
        // En celular, dentro de una sección (no en su pantalla principal) la barra superior muestra «volver» y el
        // título de la sección (SCRUM-1647). El escritorio no cambia.
        final enFlujo = !expandido && rutasDeFlujo.contains(widget.ubicacion);
        // La pantalla a la vista puede declarar su propio título: va en esta barra, no en una segunda.
        final tituloDePantalla = expandido ? null : titulosDePantalla.actual;
        final enSeccion =
            !expandido &&
            (enFlujo || !_esRaiz(entradas) || tituloDePantalla != null);
        // Una pantalla principal no tiene a dónde volver, salvo que tenga otra abierta encima.
        final conVolver =
            enSeccion &&
            (enFlujo ||
                !_esRaiz(entradas) ||
                (widget.puedeVolver?.call() ?? false));
        return PopScope(
          // En celular, el «atrás» del sistema sube un nivel en lugar de salir de la app; solo en el inicio sale.
          canPop: expandido || widget.ubicacion == '/inicio',
          onPopInvokedWithResult: (salio, _) {
            if (!salio) _volver(entradas);
          },
          child: Scaffold(
            key: const Key('app-shell'),
            backgroundColor: AppTheme.background,
            appBar: AppBar(
              key: const Key('menu-superior'),
              automaticallyImplyLeading: false,
              backgroundColor: expandido
                  ? AppTheme.surface
                  : AppTheme.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: expandido ? 68 : 60,
              shape: Border(
                bottom: BorderSide(
                  color: AppTheme.dark,
                  width: expandido ? 2 : AppTheme.borderThin,
                ),
              ),
              leading: conVolver ? _botonAtras(entradas) : null,
              titleSpacing: expandido ? 32 : (conVolver ? 0 : 16),
              title: enSeccion
                  ? Text(
                      tituloDePantalla ?? _tituloSeccion(entradas),
                      key: const Key('menu-titulo-seccion'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.titulo(
                        size: 20,
                        height: 26 / 20,
                        color: AppTheme.dark,
                      ),
                    )
                  : (!expandido
                        ? const _MarcaCelular()
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                const ManiLogo(size: 40, sombra: null),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _CabeceraSesion(
                                    datos: _datos,
                                    rol: widget.rol,
                                  ),
                                ),
                              ],
                            ),
                          )),
              actions: [
                if (!expandido)
                  ...botonesDeAcciones(titulosDePantalla.acciones),
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
                        : _accionCompacta(),
                  ),
                ),
              ],
              bottom: expandido ? _barraEntradas(context, entradas) : null,
            ),
            body: _navMovil != null && !expandido
                ? _conDeslizar(cuerpo)
                : cuerpo,
            bottomNavigationBar: expandido || enFlujo
                ? null
                : _barraInferior(context, entradas),
          ),
        );
      },
    );
  }

  // ── Navegación para celular (SCRUM-1647): solo con el ancho compacto ─────────────────────────────────────────────────
  //
  // Barra inferior con cuatro destinos: Inicio (atajos), Servicios y Perfil (pantallas que agrupan las entradas del
  // rol) y Avisos. Las pantallas que cuelgan de Servicios o de Perfil muestran «volver» y su título arriba.

  /// Pantallas principales de la barra inferior: no llevan «volver».
  static const _rutasRaizMovil = {
    '/inicio',
    rutaServicios,
    rutaCuenta,
    '/perfil/avisos',
  };

  /// La navegación de celular del rol (cinco destinos con Inicio al centro), o `null` si el rol no la usa.
  NavegacionMovil? get _navMovil => navegacionMovilPara(widget.rol);

  /// Pantallas principales con ancho de celular. Con la navegación del rol, son sus cinco destinos; los avisos se abren
  /// desde la campana de arriba (con flecha de volver), no desde la barra.
  Set<String> get _raicesMovil => _navMovil?.raices ?? _rutasRaizMovil;

  RolUsuario get _rolDePantallas =>
      widget._conContexto ? widget.contextoPlataforma!.rolEfectivo : widget.rol;

  /// Servicios o Perfil, según de cuál cuelgue la ruta actual; `null` si de ninguno.
  String? _seccionActual() => seccionDeLaRuta(
    widget.ubicacion,
    widget.rol,
    actuandoComo: _rolDePantallas,
  );

  bool _esRaiz(List<EntradaMenu> entradas) =>
      _raicesMovil.contains(widget.ubicacion);

  /// Entrada del menú más específica para la ruta actual (la de ruta más larga que sea prefijo), o `null`.
  EntradaMenu? _entradaDeLaRuta(List<EntradaMenu> entradas) {
    EntradaMenu? mejor;
    for (final e in entradas) {
      if (_coincide(e) &&
          (mejor == null || e.ruta.length > mejor.ruta.length)) {
        mejor = e;
      }
    }
    return mejor;
  }

  String _tituloSeccion(List<EntradaMenu> entradas) =>
      _entradaDeLaRuta(entradas)?.etiqueta ?? 'MANI';

  /// A dónde lleva «volver» cuando no hay historial: un flujo, al inicio; una subpantalla, a su pantalla principal;
  /// una pantalla principal de una sección, a Servicios o Perfil.
  String _destinoAtras(List<EntradaMenu> entradas) {
    // Desde una pantalla de la barra inferior se vuelve al inicio; desde el inicio se sale de la app.
    if (_raicesMovil.contains(widget.ubicacion)) return '/inicio';
    final salida = salidaDeFlujo[widget.ubicacion];
    if (salida != null) return salida;
    final entrada = _entradaDeLaRuta(entradas);
    if (entrada != null && entrada.ruta != widget.ubicacion) {
      return entrada.ruta;
    }
    return _seccionActual() ?? '/inicio';
  }

  /// Vuelve un nivel: a la pantalla anterior de la pila si la hay y, si no, a la pantalla lógica de arriba (una opción
  /// → su sección → el inicio). Lo usan la flecha de la barra superior y el «atrás» del sistema.
  void _volver(List<EntradaMenu> entradas) {
    if (widget.onVolver != null && (widget.puedeVolver?.call() ?? false)) {
      widget.onVolver!();
    } else {
      widget.onNavegar(_destinoAtras(entradas));
    }
  }

  Widget _botonAtras(List<EntradaMenu> entradas) {
    return IconButton(
      key: const Key('menu-atras'),
      tooltip: 'Volver',
      icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.dark),
      onPressed: () => _volver(entradas),
    );
  }

  Widget _barraInferior(BuildContext context, List<EntradaMenu> entradas) {
    final seccion = _seccionActual();
    final nav = _navMovil;
    if (nav != null) {
      return BarraInferiorMovil(
        navegacion: nav,
        ubicacion: widget.ubicacion,
        seccion: seccion,
        onNavegar: widget.onNavegar,
      );
    }
    final ubicacion = widget.ubicacion;
    final destinos = [
      (
        etiqueta: 'Inicio',
        icono: Icons.home_outlined,
        ruta: '/inicio',
        activo: ubicacion == '/inicio' || ubicacion.startsWith('/inicio/'),
      ),
      (
        etiqueta: 'Servicios',
        icono: Icons.home_repair_service_outlined,
        ruta: rutaServicios,
        activo: ubicacion == rutaServicios || seccion == rutaServicios,
      ),
      (
        etiqueta: 'Avisos',
        icono: Icons.notifications_none,
        ruta: '/perfil/avisos',
        activo: ubicacion.startsWith('/perfil/avisos'),
      ),
      (
        etiqueta: 'Perfil',
        icono: Icons.person_outline,
        ruta: rutaCuenta,
        activo: ubicacion == rutaCuenta || seccion == rutaCuenta,
      ),
    ];
    return DecoratedBox(
      key: const Key('barra-inferior'),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.dark, width: AppTheme.borderThick),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final d in destinos)
                Expanded(
                  child: _ItemInferior(
                    key: Key('menu-entrada-${d.ruta}'),
                    etiqueta: d.etiqueta,
                    icono: d.icono,
                    activo: d.activo,
                    alTocar: () => widget.onNavegar(d.ruta),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Deslizar a izquierda o derecha pasa al menú vecino (Servicios, Inicio, Mis pedidos, Perfil). Solo cuenta un gesto
  /// claramente horizontal y rápido, para no interferir con el desplazamiento vertical ni con los formularios.
  Widget _conDeslizar(Widget cuerpo) {
    String? vecino(bool adelante) => menuVecinoAlDeslizar(
      widget.ubicacion,
      haciaAdelante: adelante,
      rol: widget.rol,
    );
    if (vecino(true) == null && vecino(false) == null) return cuerpo;
    return _DeslizarMenus(
      alDeslizar: (adelante) {
        final destino = vecino(adelante);
        if (destino != null) widget.onNavegar(destino);
      },
      child: cuerpo,
    );
  }

  /// Acción de la barra superior en celular: la campana de avisos para los roles con navegación de celular (cerrar
  /// sesión vive en su Perfil) y, para los demás, cerrar sesión.
  Widget _accionCompacta() {
    if (_navMovil != null) {
      return FutureBuilder<int>(
        future: _sinLeer,
        builder: (context, snap) => CampanaAvisos(
          sinLeer: snap.data ?? 0,
          alTocar: () => widget.onNavegar('/perfil/avisos'),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dark, width: 2),
        boxShadow: const [AppTheme.hardShadowSm],
      ),
      child: IconButton(
        key: const Key('menu-cerrar-sesion'),
        tooltip: 'Cerrar sesión',
        icon: const Icon(Icons.logout_rounded, color: AppTheme.dark, size: 20),
        onPressed: _cerrarSesion,
      ),
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

/// Un destino de la barra inferior del celular: icono, etiqueta y, si es el activo, la píldora amarilla con borde.
/// Mide al menos 48 px de alto en toda su superficie, como pide la guía de accesibilidad táctil.
class _ItemInferior extends StatelessWidget {
  const _ItemInferior({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.activo,
    required this.alTocar,
  });

  final String etiqueta;
  final IconData icono;
  final bool activo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activo,
      label: etiqueta,
      excludeSemantics: true,
      child: InkWell(
        onTap: alTocar,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppTheme.motionFast,
              width: 52,
              height: 30,
              decoration: BoxDecoration(
                color: activo ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(
                  color: activo ? AppTheme.dark : Colors.transparent,
                  width: AppTheme.borderMedium,
                ),
              ),
              child: Icon(icono, size: 22, color: AppTheme.dark),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: activo ? FontWeight.w900 : FontWeight.w700,
                  color: AppTheme.dark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marca de la cabecera del inicio en celular: punto amarillo y «MANI». El muñequito ya está en el saludo.
class _MarcaCelular extends StatelessWidget {
  const _MarcaCelular();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.dark,
                width: AppTheme.borderThin,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'MANI',
            child: Text(
              'MANI',
              style: AppTheme.titulo(
                size: 22,
                height: 28 / 22,
                color: AppTheme.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Detecta el gesto de pasar al menú vecino: horizontal, rápido (350 px/s o más), de al menos 64 px y con el doble de
/// recorrido horizontal que vertical. No cuenta si empieza a menos de 24 px de un borde (ahí vive el «atrás» del
/// sistema) ni si empieza dentro de un [SinDeslizarMenus].
class _DeslizarMenus extends StatefulWidget {
  const _DeslizarMenus({required this.alDeslizar, required this.child});

  /// `true` si el dedo fue hacia la izquierda (el menú de la derecha).
  final ValueChanged<bool> alDeslizar;
  final Widget child;

  @override
  State<_DeslizarMenus> createState() => _DeslizarMenusState();
}

class _DeslizarMenusState extends State<_DeslizarMenus> {
  static const _margenBorde = 24.0;
  static const _minimoDesplazamiento = 64.0;
  static const _velocidadMinima = 350.0;

  final _inicios = <int, ({Offset posicion, Duration instante})>{};

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const Key('deslizar-menus'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        final ancho = MediaQuery.sizeOf(context).width;
        final enBorde =
            e.position.dx < _margenBorde ||
            e.position.dx > ancho - _margenBorde;
        if (!enBorde) {
          _inicios[e.pointer] = (posicion: e.position, instante: e.timeStamp);
        }
      },
      onPointerCancel: (e) {
        _inicios.remove(e.pointer);
        liberarPuntero(e.pointer);
      },
      onPointerUp: (e) {
        final inicio = _inicios.remove(e.pointer);
        final excluido = punteroSinDeslizar(e.pointer);
        liberarPuntero(e.pointer);
        if (inicio == null || excluido) return;
        final d = e.position - inicio.posicion;
        final segundos = (e.timeStamp - inicio.instante).inMicroseconds / 1e6;
        if (segundos <= 0) return;
        final velocidad = d.dx.abs() / segundos;
        if (d.dx.abs() < _minimoDesplazamiento) return;
        if (d.dx.abs() < 2 * d.dy.abs()) return;
        if (velocidad < _velocidadMinima) return;
        widget.alDeslizar(d.dx < 0);
      },
      child: widget.child,
    );
  }
}
