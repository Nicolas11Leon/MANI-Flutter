import 'package:flutter/material.dart';

import '../controllers/cobertura_controller.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Barra inferior fija: resumen de lo seleccionado + Descartar / Guardar.
class ResumenCoberturaBar extends StatelessWidget {
  const ResumenCoberturaBar({super.key, required this.controller});

  final CoberturaController controller;
  static const _maxChips = 6;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final zonas = c.seleccion.zonas.toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    final tema = Theme.of(context);

    return Material(
      elevation: 8,
      color: tema.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ManiSpace.lg,
            ManiSpace.md,
            ManiSpace.lg,
            ManiSpace.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                zonas.isEmpty
                    ? 'Aún no has seleccionado zonas'
                    : '${zonas.length} ${zonas.length == 1 ? 'zona seleccionada' : 'zonas seleccionadas'}',
                key: const ValueKey('resumen-cantidad'),
                style: tema.textTheme.titleSmall,
              ),
              if (zonas.isNotEmpty) ...[
                ManiGap.vSm,
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final z in zonas.take(_maxChips))
                      InputChip(
                        label: Text(z.nombre),
                        avatar: z.activa
                            ? null
                            : const Icon(Icons.warning_amber_rounded, size: 18),
                        onDeleted: c.guardando ? null : () => c.alternar(z),
                        deleteButtonTooltipMessage: 'Quitar ${z.nombre}',
                      ),
                    if (zonas.length > _maxChips)
                      Chip(label: Text('+${zonas.length - _maxChips}')),
                  ],
                ),
              ],
              ManiGap.vMd,
              Row(
                children: [
                  if (c.hayCambios && !c.esPrimeraDeclaracion)
                    TextButton(
                      onPressed: c.guardando ? null : c.descartarCambios,
                      child: const Text('Descartar'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const ValueKey('btn-guardar-cobertura'),
                    onPressed: c.puedeGuardar ? c.guardar : null,
                    icon: c.guardando
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      c.guardando ? 'Guardando…' : 'Guardar cobertura',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
