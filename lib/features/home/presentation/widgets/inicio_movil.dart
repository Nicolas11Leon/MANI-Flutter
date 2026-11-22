import 'package:flutter/material.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/shell/menu_por_rol.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_esqueleto.dart';
import 'package:mani/core/widgets/mani_layout.dart';
import 'package:mani/core/widgets/mani_pagina.dart';
import 'package:mani/features/home/presentation/widgets/saludo_inicio.dart';
import 'package:mani/features/home/data/resumen_inicio.dart';

/// Inicio del celular (SCRUM-1647): un tablero por módulos con un poco de cada cosa, para que se vea de un vistazo qué
/// pasa y se llegue a cualquier parte con un toque.
///
///  1. **Saludo y resumen** con los números del rol.
///  2. **Servicios**: los dos atajos a lo más usado y «Ver todos».
///  3. **Tu cuenta**: acceso al perfil y a todas las opciones de la cuenta.
///
/// Solo presenta datos que la app ya consulta; no tiene lógica de negocio.
class InicioMovil extends StatelessWidget {
  const InicioMovil({
    super.key,
    required this.sesion,
    required this.resumen,
    required this.atajos,
    required this.subtitulo,
    required this.accionSaludo,
    required this.onNavegar,
  });

  final Future<DatosSesion> sesion;
  final Future<List<IndicadorResumen>> resumen;

  final List<EntradaMenu> atajos;
  final String subtitulo;
  final AccionSaludo? accionSaludo;
  final ValueChanged<String> onNavegar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('inicio-movil'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SaludoInicio(
          sesion: sesion,
          subtitulo: subtitulo,
          accion: accionSaludo,
          onNavegar: onNavegar,
        ),
        const SizedBox(height: 16),
        _Resumen(resumen: resumen, onNavegar: onNavegar),
        if (atajos.isNotEmpty) ...[
          _Modulo(
            id: 'servicios',
            titulo: 'Servicios',
            accion: 'Ver todos',
            alAccion: () => onNavegar(rutaServicios),
            hijos: [
              for (final e in atajos)
                _Fila(
                  key: Key('inicio-acceso-${e.ruta}'),
                  icono: e.icono,
                  titulo: e.etiqueta,
                  alTocar: () => onNavegar(e.ruta),
                ),
            ],
          ),
        ],
        _Modulo(
          id: 'cuenta',
          titulo: 'Tu cuenta',
          accion: 'Ver todo',
          alAccion: () => onNavegar(rutaCuenta),
          hijos: [
            _Fila(
              key: const Key('inicio-acceso-/perfil/editar'),
              icono: Icons.person_outline,
              titulo: 'Mi perfil',
              alTocar: () => onNavegar('/perfil/editar'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Números del rol, de dos en dos. Si no se pueden consultar no se muestra nada: el resto del inicio sigue usable.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.resumen, required this.onNavegar});

  final Future<List<IndicadorResumen>> resumen;
  final ValueChanged<String> onNavegar;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<IndicadorResumen>>(
      future: resumen,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ManiEsqueleto.tarjetas(),
          );
        }
        final indicadores = snap.data ?? const <IndicadorResumen>[];
        if (indicadores.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: LayoutBuilder(
            builder: (context, c) {
              const espacio = 12.0;
              final ancho = (c.maxWidth - espacio) / 2;
              return Wrap(
                spacing: espacio,
                runSpacing: espacio,
                children: [
                  for (final i in indicadores)
                    SizedBox(
                      width: ancho,
                      child: ManiCard(
                        padding: EdgeInsets.zero,
                        child: InkWell(
                          key: Key('inicio-indicador-${i.etiqueta}'),
                          borderRadius: BorderRadius.circular(ManiRadius.lg),
                          onTap: () => onNavegar(i.ruta),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  i.valor ?? '—',
                                  style: AppTheme.titulo(
                                    size: 28,
                                    height: 32 / 28,
                                    color: i.valor == '0'
                                        ? context.mani.inkMuted
                                        : context.mani.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  i.etiqueta,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.mani.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Un módulo del tablero: título, enlace «Ver todos» a su pantalla y su contenido. Las filas van juntas dentro de una
/// sola tarjeta, separadas por divisores.
class _Modulo extends StatelessWidget {
  const _Modulo({
    required this.id,
    required this.titulo,
    required this.accion,
    required this.alAccion,
    required this.hijos,
  });

  /// Identifica el módulo en las claves de prueba: `modulo-<id>` y `modulo-<id>-ver-todos`.
  final String id;
  final String titulo;
  final String accion;
  final VoidCallback alAccion;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('modulo-$id'),
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManiTituloSeccion(
            titulo: titulo,
            // Área táctil de al menos 48 px de alto.
            accion: ManiButton(
              key: Key('modulo-$id-ver-todos'),
              etiqueta: accion,
              variante: ManiButtonVariante.texto,
              onPressed: alAccion,
            ),
          ),
          const SizedBox(height: 4),
          ManiCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < hijos.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1.0,
                      indent: 68,
                      color: context.mani.borderSubtle,
                    ),
                  hijos[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una fila tocable del tablero: caja de icono suave, título y flecha.
class _Fila extends StatelessWidget {
  const _Fila({
    super.key,
    required this.icono,
    required this.titulo,
    required this.alTocar,
  });

  final IconData icono;
  final String titulo;
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
                  titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.mani.ink,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.mani.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
