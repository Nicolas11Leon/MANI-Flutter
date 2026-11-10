import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';

import '../../domain/entities/motivo_rechazo.dart';
import '../../domain/entities/solicitud_entity.dart';

/// Resultado del diálogo: el motivo es obligatorio y el detalle solo viene
/// con «Otro» (SCRUM-1617).
typedef ConfirmacionRechazo = ({MotivoRechazo motivo, String? detalle});

/// Confirma el rechazo y pide el motivo con un toque, de una lista corta.
/// «Rechazar» se habilita al elegir uno; «Otro» pide además el texto.
/// Devuelve `null` si el aliado cancela.
Future<ConfirmacionRechazo?> confirmarRechazo(
  BuildContext context,
  SolicitudEntity solicitud,
) => showDialog<ConfirmacionRechazo>(
  context: context,
  builder: (_) => _DialogoRechazo(solicitud: solicitud),
);

class _DialogoRechazo extends StatefulWidget {
  const _DialogoRechazo({required this.solicitud});

  final SolicitudEntity solicitud;

  @override
  State<_DialogoRechazo> createState() => _DialogoRechazoState();
}

class _DialogoRechazoState extends State<_DialogoRechazo> {
  MotivoRechazo? _motivo;
  final _detalle = TextEditingController();

  bool get _listo {
    final m = _motivo;
    if (m == null) {
      return false;
    }
    return !m.requiereDetalle || MotivoRechazo.detalleValido(_detalle.text);
  }

  @override
  void dispose() {
    _detalle.dispose();
    super.dispose();
  }

  void _confirmar() {
    final m = _motivo!;
    Navigator.pop<ConfirmacionRechazo>(context, (
      motivo: m,
      detalle: m.requiereDetalle ? _detalle.text.trim() : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ManiColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: ManiRadius.brLg,
        side: const BorderSide(color: ManiColors.ink, width: 3),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        ManiSpace.xxl,
        ManiSpace.xxl,
        ManiSpace.xxl,
        ManiSpace.sm,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        ManiSpace.xxl,
        ManiSpace.sm,
        ManiSpace.xxl,
        ManiSpace.xxl,
      ),
      title: Text(
        '¿Rechazar ${widget.solicitud.categoria}?',
        style: const TextStyle(
          fontSize: ManiFontSize.title,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No volverás a verla. Seguirá disponible para otros aliados, '
              'así el cliente no se queda sin servicio.',
            ),
            ManiGap.vLg,
            const Text(
              '¿Por qué la rechazas?',
              style: TextStyle(
                fontSize: ManiFontSize.caption,
                fontWeight: FontWeight.w800,
              ),
            ),
            ManiGap.vSm,
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in MotivoRechazo.values)
                  ChoiceChip(
                    key: ValueKey('motivo-${m.codigo}'),
                    label: Text(
                      m.etiqueta,
                      style: const TextStyle(
                        fontSize: ManiFontSize.caption,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    selected: _motivo == m,
                    onSelected: (sel) =>
                        setState(() => _motivo = sel ? m : null),
                    selectedColor: ManiColors.brand,
                    backgroundColor: ManiColors.surface,
                    side: ManiBorder.sideThin,
                    shape: RoundedRectangleBorder(
                      borderRadius: ManiRadius.brSm,
                    ),
                  ),
              ],
            ),
            if (_motivo?.requiereDetalle ?? false) ...[
              ManiGap.vMd,
              TextField(
                key: const ValueKey('detalle-rechazo'),
                controller: _detalle,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: MotivoRechazo.detalleMaximo,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Cuéntanos el motivo',
                  helperText:
                      'Mínimo ${MotivoRechazo.detalleMinimo} caracteres',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else if (_motivo == null) ...[
              ManiGap.vSm,
              const Text(
                'Elige un motivo para continuar.',
                key: ValueKey('rechazo-sin-motivo'),
                style: TextStyle(
                  fontSize: ManiFontSize.caption,
                  color: ManiColors.inkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 12,
          children: [
            ManiButton(
              key: const ValueKey('dlg-cancelar-rechazo'),
              etiqueta: 'Volver',
              variante: ManiButtonVariante.secundario,
              onPressed: () => Navigator.pop(context),
            ),
            ManiButton(
              key: const ValueKey('dlg-confirmar-rechazo'),
              etiqueta: 'Rechazar',
              icono: Icons.close_rounded,
              variante: ManiButtonVariante.peligro,
              onPressed: _listo ? _confirmar : null,
            ),
          ],
        ),
      ],
    );
  }
}
