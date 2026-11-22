import 'package:flutter/material.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/menu_por_rol.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_mano.dart';

const _rutaInicio = '/inicio';

/// Navegación en celular (SCRUM-1647): cinco destinos en una barra inferior con **Inicio en el centro**, resaltado, y
/// dos destinos a cada lado; los menús se pueden recorrer deslizando. Cada rol tiene sus destinos.
///
/// Solo aplica con ancho de celular. La web (escritorio) conserva su menú superior de siempre. El administrador de
/// plataforma no usa esta navegación y conserva la barra de cuatro destinos.

/// Publicar una solicitud nueva: es un flujo de varios pasos, no un menú, y no forma parte del deslizado.
const rutaNuevaSolicitud = '/cliente/solicitudes/nueva';

/// «Mis pedidos»: las solicitudes del cliente en curso.
const rutaMisPedidos = '/cliente/solicitudes';

/// Un destino de la barra inferior.
class DestinoMovil {
  const DestinoMovil(
    this.etiqueta,
    this.icono,
    this.ruta, {
    this.esAccion = false,
  });

  final String etiqueta;
  final IconData icono;
  final String ruta;

  /// Es una acción (abre un flujo), no un menú: no entra en el deslizado.
  final bool esAccion;

  /// Servicios y Perfil son pantallas que agrupan; los demás destinos son una pantalla concreta.
  bool get esSeccion => ruta == rutaServicios || ruta == rutaCuenta;
}

const _inicio = DestinoMovil('Inicio', Icons.home_outlined, _rutaInicio);

/// Destinos de un rol: dos a la izquierda y dos a la derecha de Inicio, que va siempre al centro.
class NavegacionMovil {
  const NavegacionMovil({required this.izquierda, required this.derecha});

  final List<DestinoMovil> izquierda;
  final List<DestinoMovil> derecha;

  /// Los cinco, de izquierda a derecha.
  List<DestinoMovil> get todos => [...izquierda, _inicio, ...derecha];

  /// Menús entre los que se desliza, en el orden de la barra y sin las acciones.
  List<String> get deslizables => [
    for (final d in todos)
      if (!d.esAccion) d.ruta,
  ];

  /// Pantallas principales: no llevan flecha de volver.
  Set<String> get raices => {for (final d in todos) d.ruta};
}

const _servicios = DestinoMovil(
  'Servicios',
  Icons.home_repair_service_outlined,
  rutaServicios,
);
const _perfil = DestinoMovil('Perfil', Icons.person_outline, rutaCuenta);

/// Cliente: Nueva solicitud y Servicios | Inicio | Mis pedidos y Perfil.
const navegacionCliente = NavegacionMovil(
  izquierda: [
    DestinoMovil(
      'Nueva',
      Icons.add_circle_outline,
      rutaNuevaSolicitud,
      esAccion: true,
    ),
    _servicios,
  ],
  derecha: [
    DestinoMovil('Mis pedidos', Icons.list_alt_outlined, rutaMisPedidos),
    _perfil,
  ],
);

/// Aliado: Solicitudes y Cobros | Inicio | Servicios y Perfil.
const navegacionAliado = NavegacionMovil(
  izquierda: [
    DestinoMovil('Solicitudes', Icons.inbox_outlined, '/aliado/solicitudes'),
    DestinoMovil('Cobros', Icons.payments_outlined, '/aliado/cobros'),
  ],
  derecha: [_servicios, _perfil],
);

/// Administrador de la empresa: Verificación y Quejas | Inicio | Gestión y Perfil. «Gestión» agrupa catálogo, reglas,
/// tarifario y seguimiento.
const navegacionAdmin = NavegacionMovil(
  izquierda: [
    DestinoMovil(
      'Verificación',
      Icons.verified_user_outlined,
      '/admin/verificacion-aliados',
    ),
    DestinoMovil('Quejas', Icons.support_agent_outlined, '/admin/quejas'),
  ],
  derecha: [
    DestinoMovil('Gestión', Icons.settings_outlined, rutaServicios),
    _perfil,
  ],
);

/// La navegación de celular del [rol], o `null` si no la usa (administrador de plataforma y rol desconocido).
NavegacionMovil? navegacionMovilPara(RolUsuario rol) => switch (rol) {
  RolUsuario.cliente => navegacionCliente,
  RolUsuario.aliado => navegacionAliado,
  RolUsuario.adminTenant => navegacionAdmin,
  _ => null,
};

/// Menús del cliente entre los que se desliza, de izquierda a derecha.
final menusDeslizablesCliente = navegacionCliente.deslizables;

/// El menú vecino al deslizar, o `null` si la pantalla no es uno de los menús del [rol] o ya está en el extremo.
///
/// [haciaAdelante] es deslizar el dedo hacia la izquierda (se pasa al menú de la derecha).
String? menuVecinoAlDeslizar(
  String ubicacion, {
  required bool haciaAdelante,
  RolUsuario rol = RolUsuario.cliente,
}) {
  final menus = navegacionMovilPara(rol)?.deslizables ?? const <String>[];
  final i = menus.indexOf(ubicacion);
  if (i < 0) return null;
  final j = haciaAdelante ? i + 1 : i - 1;
  if (j < 0 || j >= menus.length) return null;
  return menus[j];
}

/// Barra inferior de celular: dos destinos, **Inicio** resaltado en el centro y dos destinos más.
class BarraInferiorMovil extends StatelessWidget {
  const BarraInferiorMovil({
    super.key,
    required this.navegacion,
    required this.ubicacion,
    required this.seccion,
    required this.onNavegar,
  });

  final NavegacionMovil navegacion;

  /// Ruta actual.
  final String ubicacion;

  /// Servicios o Perfil, según de cuál cuelgue la ruta actual (`seccionDeLaRuta`); `null` si de ninguno.
  final String? seccion;
  final ValueChanged<String> onNavegar;

  /// Alto del botón central por encima de la línea de la barra.
  static const _saliente = 0.0;
  static const _alto = 66.0 + _saliente;

  bool _coincide(String ruta) =>
      ubicacion == ruta || ubicacion.startsWith('$ruta/');

  /// El destino concreto (no Servicios ni Perfil) más específico que coincide con la ruta actual: en
  /// `/cliente/solicitudes/nueva` gana «Nueva» y no «Mis pedidos», cuya ruta es prefijo de la actual.
  String? get _directo {
    String? mejor;
    for (final d in navegacion.todos) {
      if (d.esSeccion || d.ruta == _rutaInicio) continue;
      if (_coincide(d.ruta) &&
          (mejor == null || d.ruta.length > mejor.length)) {
        mejor = d.ruta;
      }
    }
    return mejor;
  }

  bool _activo(DestinoMovil d) {
    if (d.ruta == _rutaInicio) return _coincide(_rutaInicio);
    final directo = _directo;
    if (d.esSeccion) {
      return directo == null && (ubicacion == d.ruta || seccion == d.ruta);
    }
    return directo == d.ruta;
  }

  Widget _lateral(DestinoMovil d) => Expanded(
    child: _Destino(
      key: Key('menu-entrada-${d.ruta}'),
      etiqueta: d.etiqueta,
      icono: d.icono,
      activo: _activo(d),
      alTocar: () => onNavegar(d.ruta),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        key: const Key('barra-inferior'),
        height: _alto,
        child: Stack(
          children: [
            Positioned(
              top: _saliente,
              left: 0,
              right: 0,
              bottom: 0,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: ManiColors.surface,
                  border: Border(
                    top: BorderSide(color: ManiColors.ink, width: 2),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final d in navegacion.izquierda) _lateral(d),
                Expanded(
                  child: _Centro(
                    key: const Key('menu-entrada-/inicio'),
                    activo: _activo(_inicio),
                    alTocar: () => onNavegar(_rutaInicio),
                  ),
                ),
                for (final d in navegacion.derecha) _lateral(d),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Un destino lateral: icono en píldora (amarilla con borde si es el activo) y etiqueta. Toda su superficie se toca.
class _Destino extends StatelessWidget {
  const _Destino({
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
        child: Padding(
          padding: const EdgeInsets.only(top: BarraInferiorMovil._saliente),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: ManiMotion.fast,
                width: 48,
                height: 28,
                decoration: BoxDecoration(
                  color: activo ? ManiColors.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(ManiRadius.pill),
                  border: Border.all(
                    color: activo ? ManiColors.ink : Colors.transparent,
                    width: ManiBorder.thick,
                  ),
                ),
                child: Icon(icono, size: 22, color: ManiColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: activo ? FontWeight.w900 : FontWeight.w700,
                  color: ManiColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El destino del centro, Inicio: la manita de MANI en un círculo dentro de la barra, al mismo alto que los demás
/// destinos. Activo va en amarillo; inactivo, en amarillo suave.
class _Centro extends StatelessWidget {
  const _Centro({super.key, required this.activo, required this.alTocar});

  final bool activo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activo,
      label: 'Inicio',
      excludeSemantics: true,
      child: InkWell(
        onTap: alTocar,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: ManiMotion.fast,
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: activo ? ManiColors.brand : ManiColors.brandSoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: ManiColors.ink,
                  width: ManiBorder.thick,
                ),
              ),
              child: const ManiMano(mini: true),
            ),
            const SizedBox(height: 2),
            Text(
              'Inicio',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: activo ? FontWeight.w900 : FontWeight.w700,
                color: ManiColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La campana de avisos de la barra superior, con el número de avisos sin leer.
class CampanaAvisos extends StatelessWidget {
  const CampanaAvisos({
    super.key,
    required this.sinLeer,
    required this.alTocar,
  });

  /// Avisos sin leer; con 0 (o sin dato) no se muestra el número.
  final int sinLeer;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final texto = sinLeer > 9 ? '9+' : '$sinLeer';
    return Semantics(
      button: true,
      label: sinLeer > 0 ? 'Avisos, $sinLeer sin leer' : 'Avisos',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: ManiColors.surface,
          borderRadius: BorderRadius.circular(ManiRadius.lg),
          border: Border.all(color: ManiColors.ink, width: ManiBorder.thin),
        ),
        child: InkWell(
          key: const Key('menu-avisos'),
          borderRadius: BorderRadius.circular(ManiRadius.lg),
          onTap: alTocar,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.notifications_none,
                  color: ManiColors.ink,
                  size: 24,
                ),
                if (sinLeer > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      key: const Key('menu-avisos-contador'),
                      constraints: const BoxConstraints(minWidth: 20),
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ManiColors.danger,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: ManiColors.background,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        texto,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
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
