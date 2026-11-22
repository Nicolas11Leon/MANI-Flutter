import 'package:flutter/material.dart';
import 'package:mani/core/session/contexto_plataforma.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/menu_por_rol.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_layout.dart';

/// Las dos pantallas de agrupación de la barra inferior del celular (SCRUM-1647).
enum TipoSeccion { servicios, cuenta }

/// Pantalla que reúne las entradas de un rol en una sola lista de accesos grandes, fáciles de tocar con el pulgar:
/// *Servicios* (lo operativo del día a día) o *Perfil* (la cuenta y cerrar sesión).
///
/// No tiene lógica ni permisos propios: muestra las mismas entradas que el menú del escritorio, repartidas. Ocultar una
/// entrada no protege la ruta; la autorización la aplica el servidor.
class SeccionMenuPage extends StatelessWidget {
  const SeccionMenuPage({
    super.key,
    required this.tipo,
    required this.rol,
    required this.onNavegar,
    this.onCerrarSesion,
    this.contextoPlataforma,
  });

  final TipoSeccion tipo;
  final RolUsuario rol;
  final ValueChanged<String> onNavegar;
  final Future<void> Function()? onCerrarSesion;

  /// Contexto del administrador de plataforma: sus entradas son las del rol con el que actúa.
  final ContextoPlataforma? contextoPlataforma;

  RolUsuario get _rolDePantallas =>
      rol == RolUsuario.adminPlataforma && contextoPlataforma != null
      ? contextoPlataforma!.rolEfectivo
      : rol;

  String _titulo(bool gestion) {
    if (tipo == TipoSeccion.cuenta) return 'Tu cuenta';
    return gestion ? 'Gestión' : 'Servicios';
  }

  String _subtitulo(bool gestion) {
    if (tipo == TipoSeccion.cuenta) {
      return 'Tu perfil y los datos de tu cuenta.';
    }
    return gestion
        ? 'Catálogo, reglas, tarifario y seguimiento de tu empresa.'
        : 'Todo lo que haces en MANI, en un solo lugar.';
  }

  Widget _listaEntradas(List<EntradaMenu> entradas) {
    return ManiCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < entradas.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1.0,
                indent: 68,
                color: ManiColors.borderSubtle,
              ),
            _Acceso(
              key: Key('seccion-acceso-${entradas[i].ruta}'),
              etiqueta: entradas[i].etiqueta,
              icono: entradas[i].icono,
              alTocar: () => onNavegar(entradas[i].ruta),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entradas = switch (tipo) {
      TipoSeccion.servicios => entradasServiciosPara(
        rol,
        actuandoComo: _rolDePantallas,
      ),
      TipoSeccion.cuenta => entradasCuentaPara(
        rol,
        actuandoComo: _rolDePantallas,
      ),
    };
    // El administrador de la empresa lo ve como «Gestión»: no pide ni presta servicios, administra su empresa.
    final gestion = _rolDePantallas == RolUsuario.adminTenant;
    final titulo = _titulo(gestion);
    final subtitulo = _subtitulo(gestion);

    return Scaffold(
      backgroundColor: ManiColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            key: Key('seccion-${tipo.name}'),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              Text(
                titulo,
                style: AppTheme.titulo(
                  size: 26,
                  height: 32 / 26,
                  color: ManiColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitulo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ManiColors.inkMuted,
                ),
              ),
              const SizedBox(height: 18),
              if (entradas.isEmpty)
                const Text(
                  'Por ahora no hay nada aquí para tu cuenta.',
                  key: Key('seccion-vacia'),
                  style: TextStyle(color: ManiColors.inkMuted),
                ),
              if (entradas.isNotEmpty) _listaEntradas(entradas),
              if (tipo == TipoSeccion.cuenta && onCerrarSesion != null) ...[
                const SizedBox(height: 32),
                ManiButton(
                  key: const Key('seccion-cerrar-sesion'),
                  etiqueta: 'Cerrar sesión',
                  icono: Icons.logout,
                  variante: ManiButtonVariante.secundario,
                  colorTexto: ManiColors.dangerText,
                  expandir: true,
                  onPressed: () async => onCerrarSesion!(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Un acceso de la lista: caja de icono suave, etiqueta y flecha. Mide al menos 56 px de alto.
class _Acceso extends StatelessWidget {
  const _Acceso({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.alTocar,
  });

  final String etiqueta;
  final IconData icono;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alTocar,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              ManiIconoCaja(icono: icono),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  etiqueta,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ManiColors.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: ManiColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
