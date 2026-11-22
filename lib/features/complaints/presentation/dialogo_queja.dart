import 'package:flutter/material.dart';
import 'package:mani/core/network/mensaje_error_gateway.dart';
import 'package:mani/core/widgets/mani_button.dart';

import '../data/quejas_datasource.dart';
import '../domain/queja.dart';
import 'package:mani/core/theme/app_theme.dart';

/// El cliente presenta una queja sobre un servicio propio (HU-M12-01 /
/// SCRUM-895). Motivo obligatorio y descripción de 10 a 1000 caracteres; Core
/// verifica que la solicitud sea suya y no tenga otra queja abierta.
///
/// Devuelve la [Queja] registrada, o `null` si el cliente cancela.
Future<Queja?> presentarQueja(
  BuildContext context, {
  required FuenteQuejas fuente,
  required String solicitudId,
}) => showDialog<Queja>(
  context: context,
  builder: (_) => DialogoQueja(fuente: fuente, solicitudId: solicitudId),
);

class DialogoQueja extends StatefulWidget {
  const DialogoQueja({
    super.key,
    required this.fuente,
    required this.solicitudId,
  });

  final FuenteQuejas fuente;
  final String solicitudId;

  @override
  State<DialogoQueja> createState() => _DialogoQuejaState();
}

class _DialogoQuejaState extends State<DialogoQueja> {
  final _descripcion = TextEditingController();
  MotivoQueja? _motivo;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  bool get _valido =>
      _motivo != null && descripcionQuejaValida(_descripcion.text);

  Future<void> _enviar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final queja = await widget.fuente.registrar(
        widget.solicitudId,
        motivo: _motivo!,
        descripcion: _descripcion.text,
      );
      if (mounted) Navigator.of(context).pop(queja);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = mensajeErrorGateway(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Presentar una queja'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<MotivoQueja>(
                key: const Key('queja-motivo'),
                initialValue: _motivo,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items: [
                  for (final m in MotivoQueja.values)
                    DropdownMenuItem(value: m, child: Text(m.etiqueta)),
                ],
                onChanged: _enviando
                    ? null
                    : (m) => setState(() => _motivo = m),
              ),
              ManiGap.vMd,
              TextField(
                key: const Key('queja-descripcion'),
                controller: _descripcion,
                enabled: !_enviando,
                maxLines: 4,
                maxLength: 1000,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Cuéntanos qué pasó',
                  helperText: 'Mínimo 10 caracteres',
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('queja-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ManiButton(
          key: const Key('queja-enviar'),
          etiqueta: 'Enviar queja',
          cargando: _enviando,
          onPressed: _valido && !_enviando ? _enviar : null,
        ),
      ],
    );
  }
}
