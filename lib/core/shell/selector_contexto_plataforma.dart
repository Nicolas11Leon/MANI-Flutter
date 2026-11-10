import 'package:flutter/material.dart';
import 'package:mani/core/network/mensaje_error_gateway.dart';
import 'package:mani/core/session/contexto_plataforma.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/features/platform/data/tenants_datasource.dart';

/// Franja del administrador de plataforma (SCRUM-901): elige el tenant que
/// administra y, si quiere, el cliente, aliado o administrador de ese tenant
/// con el que actúa. Cada cambio recarga la pantalla con el contexto nuevo.
class SelectorContextoPlataforma extends StatefulWidget {
  const SelectorContextoPlataforma({
    super.key,
    required this.contexto,
    required this.fuenteTenants,
    required this.fuenteUsuarios,
    this.alCambiar,
  });

  final ContextoPlataforma contexto;
  final FuenteTenants fuenteTenants;
  final FuenteUsuariosTenant fuenteUsuarios;

  /// Se llama tras cada cambio de contexto (p. ej. volver al inicio).
  final VoidCallback? alCambiar;

  @override
  State<SelectorContextoPlataforma> createState() =>
      _SelectorContextoPlataformaState();
}

class _SelectorContextoPlataformaState
    extends State<SelectorContextoPlataforma> {
  List<TenantPlataforma>? _tenants;
  List<UsuarioTenant>? _usuarios;
  String? _usuariosDe;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarTenants();
  }

  Future<void> _cargarTenants() async {
    try {
      final tenants = await widget.fuenteTenants.listar();
      if (mounted) setState(() => _tenants = tenants);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeErrorGateway(e));
    }
  }

  Future<List<UsuarioTenant>> _usuariosDelTenant(String tenantId) async {
    if (_usuariosDe == tenantId && _usuarios != null) return _usuarios!;
    final usuarios = await widget.fuenteUsuarios.listar(tenantId);
    _usuariosDe = tenantId;
    _usuarios = usuarios;
    return usuarios;
  }

  /// Tenant en uso: el elegido o, si no hay, el primero del listado que
  /// coincide con el de la sesión (se muestra como «Mi tenant»).
  String get _etiquetaTenant => widget.contexto.tenantNombre ?? 'Mi tenant';

  String get _etiquetaActuar {
    final u = widget.contexto.actuarComo;
    if (u == null) return 'Administrador del tenant';
    return '${u.email} · ${_rolLegible(u.rolApp.name)}';
  }

  static String _rolLegible(String rol) => switch (rol) {
    'cliente' => 'Cliente',
    'aliado' => 'Aliado',
    'adminTenant' => 'Administrador',
    _ => rol,
  };

  void _cambio() => widget.alCambiar?.call();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('selector-contexto-plataforma'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.xxl,
        vertical: ManiSpace.sm,
      ),
      decoration: const BoxDecoration(
        color: ManiColors.brandSoft,
        border: Border(bottom: ManiBorder.side),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: ManiColors.ink),
              ManiGap.hSm,
              Text(
                'ADMINISTRACIÓN DE PLATAFORMA',
                style: TextStyle(
                  fontSize: ManiFontSize.caption,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: ManiColors.ink,
                ),
              ),
            ],
          ),
          _Pildora(
            clave: const Key('selector-tenant'),
            icono: Icons.domain_outlined,
            titulo: 'Tenant',
            valor: _etiquetaTenant,
            menu: () async => [
              for (final t in _tenants ?? const <TenantPlataforma>[])
                PopupMenuItem<VoidCallback>(
                  key: Key('selector-tenant-${t.id}'),
                  value: () {
                    widget.contexto.elegirTenant(t.id, t.nombre);
                    _cambio();
                  },
                  child: Text('${t.nombre} (${t.estado.etiqueta})'),
                ),
            ],
          ),
          _Pildora(
            clave: const Key('selector-actuar-como'),
            icono: Icons.switch_account_outlined,
            titulo: 'Actuar como',
            valor: _etiquetaActuar,
            menu: () async {
              final tenantId = widget.contexto.tenantId;
              if (tenantId == null) {
                return [
                  const PopupMenuItem<VoidCallback>(
                    enabled: false,
                    child: Text('Elige primero un tenant'),
                  ),
                ];
              }
              final usuarios = await _usuariosDelTenant(tenantId);
              return [
                PopupMenuItem<VoidCallback>(
                  key: const Key('selector-actuar-admin'),
                  value: () {
                    widget.contexto.actuarComoUsuario(null);
                    _cambio();
                  },
                  child: const Text('Administrador del tenant'),
                ),
                const PopupMenuDivider(),
                for (final u in usuarios)
                  PopupMenuItem<VoidCallback>(
                    key: Key('selector-actuar-${u.id}'),
                    value: () {
                      widget.contexto.actuarComoUsuario(u);
                      _cambio();
                    },
                    child: Text('${u.email} · ${_rolLegible(u.rolApp.name)}'),
                  ),
              ];
            },
          ),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(
                fontSize: ManiFontSize.caption,
                fontWeight: FontWeight.w700,
                color: ManiColors.dangerText,
              ),
            ),
        ],
      ),
    );
  }
}

/// Botón en píldora con borde negro que abre un menú cuyas opciones son
/// acciones (se ejecuta la elegida).
class _Pildora extends StatelessWidget {
  const _Pildora({
    required this.clave,
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.menu,
  });

  final Key clave;
  final IconData icono;
  final String titulo;
  final String valor;
  final Future<List<PopupMenuEntry<VoidCallback>>> Function() menu;

  Future<void> _abrir(BuildContext context) async {
    final caja = context.findRenderObject()! as RenderBox;
    final origen = caja.localToGlobal(Offset(0, caja.size.height + 4));
    List<PopupMenuEntry<VoidCallback>> opciones;
    try {
      opciones = await menu();
    } catch (e) {
      opciones = [
        PopupMenuItem<VoidCallback>(
          enabled: false,
          child: Text(mensajeErrorGateway(e)),
        ),
      ];
    }
    if (!context.mounted) return;
    final elegida = await showMenu<VoidCallback>(
      context: context,
      position: RelativeRect.fromLTRB(origen.dx, origen.dy, origen.dx, 0),
      items: opciones,
    );
    elegida?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => DecoratedBox(
        decoration: BoxDecoration(
          color: ManiColors.surface,
          borderRadius: ManiRadius.brMd,
          border: Border.all(
            color: ManiColors.border,
            width: ManiBorder.regular,
          ),
          boxShadow: const [ManiShadow.sm],
        ),
        child: TextButton(
          key: clave,
          onPressed: () => _abrir(context),
          style: TextButton.styleFrom(
            foregroundColor: ManiColors.ink,
            padding: const EdgeInsets.symmetric(
              horizontal: ManiSpace.md,
              vertical: ManiSpace.sm,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 18),
              ManiGap.hSm,
              Text(
                '$titulo: ',
                style: const TextStyle(
                  fontSize: ManiFontSize.caption,
                  fontWeight: FontWeight.w700,
                  color: ManiColors.inkMuted,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  valor,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: ManiFontSize.bodySm,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ManiGap.hXs,
              const Icon(Icons.expand_more, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
