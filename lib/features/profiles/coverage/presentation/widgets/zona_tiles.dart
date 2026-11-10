import 'package:flutter/material.dart';

import '../../domain/entities/zona.dart';
import '../controllers/cobertura_controller.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Fila seleccionable de una zona sin hijas cargables (barrio o resultado de
/// búsqueda). Si ya está cubierta por un ancestro, se muestra marcada y
/// deshabilitada con la explicación "Incluida en …".
class ZonaCheckTile extends StatelessWidget {
  const ZonaCheckTile({
    super.key,
    required this.zona,
    required this.controller,
    this.mostrarRuta = false,
    this.titulo,
  });

  final Zona zona;
  final CoberturaController controller;
  final bool mostrarRuta;

  /// Texto alterno al nombre (p. ej. "Toda Bogotá").
  final String? titulo;

  @override
  Widget build(BuildContext context) {
    final sel = controller.seleccion;
    final ancestro = sel.ancestroSeleccionado(zona);
    final subtitulo = ancestro != null
        ? 'Incluida en ${ancestro.nombre}'
        : (mostrarRuta
              ? '${zona.nivel.etiqueta} · ${controller.rutaDe(zona)}'
              : null);

    return CheckboxListTile(
      key: ValueKey('zona-${zona.id}'),
      value: sel.cubre(zona),
      onChanged: ancestro != null || controller.guardando
          ? null
          : (_) => controller.alternar(zona),
      title: Text(titulo ?? zona.nombre),
      subtitle: subtitulo == null ? null : Text(subtitulo),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }
}

/// Localidad/comuna expandible: el checkbox de la izquierda declara la
/// localidad completa; al expandir se cargan (lazy) sus barrios.
/// Checkbox tri-estado: marcado = localidad completa · guion = algunos
/// barrios · vacío = nada.
class ZonaGrupoTile extends StatelessWidget {
  const ZonaGrupoTile({
    super.key,
    required this.zona,
    required this.controller,
  });

  final Zona zona;
  final CoberturaController controller;

  @override
  Widget build(BuildContext context) {
    final sel = controller.seleccion;
    final completa = sel.cubre(zona);
    final parcial = !completa && sel.tieneDescendienteSeleccionada(zona);
    final hijas = controller.hijasDe(zona.id);
    final bloqueada = sel.estaCubiertaPorAncestro(zona) || controller.guardando;

    return ExpansionTile(
      key: PageStorageKey('grupo-${zona.id}'),
      leading: Semantics(
        label: completa
            ? '${zona.nombre} completa seleccionada'
            : parcial
            ? '${zona.nombre} con algunos barrios seleccionados'
            : '${zona.nombre} sin seleccionar',
        child: Checkbox(
          key: ValueKey('grupo-check-${zona.id}'),
          tristate: true,
          value: completa ? true : (parcial ? null : false),
          onChanged: bloqueada ? null : (_) => controller.alternar(zona),
        ),
      ),
      title: Text(zona.nombre),
      subtitle: Text(
        completa
            ? '${zona.nivel.etiqueta} completa'
            : parcial
            ? 'Algunos barrios'
            : zona.nivel.etiqueta,
      ),
      onExpansionChanged: (abierta) {
        if (abierta) controller.cargarHijas(zona.id);
      },
      children: [
        if (controller.cargandoHijasDe(zona.id))
          const Padding(
            padding: EdgeInsets.all(ManiSpace.md),
            child: Center(child: CircularProgressIndicator.adaptive()),
          )
        else if (hijas != null && hijas.isEmpty)
          const ListTile(
            dense: true,
            title: Text(
              'Esta localidad no tiene barrios en el catálogo. Selecciónala completa.',
            ),
          )
        else if (hijas != null)
          for (final h in hijas)
            h.tieneHijas
                ? ZonaGrupoTile(zona: h, controller: controller)
                : ZonaCheckTile(zona: h, controller: controller),
      ],
    );
  }
}
