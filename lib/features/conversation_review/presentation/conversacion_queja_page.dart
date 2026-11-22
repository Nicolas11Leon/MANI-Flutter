import 'package:mani/core/widgets/mani_text_field.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/utils/formato_fecha.dart';

import 'conversacion_queja_cubit.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';

/// Conversación de una queja (SCRUM-883): el administrador abre el hilo de un
/// servicio indicando el motivo. La consulta queda registrada en la auditoría.
/// [solicitudId] y [quejaRef] prellenan el formulario cuando se llega desde una
/// queja concreta.
class ConversacionQuejaPage extends StatelessWidget {
  const ConversacionQuejaPage({super.key, this.solicitudId, this.quejaRef});

  final String? solicitudId;
  final String? quejaRef;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ConversacionQuejaCubit(sl()),
    child: ConversacionQuejaView(solicitudId: solicitudId, quejaRef: quejaRef),
  );
}

class ConversacionQuejaView extends StatefulWidget {
  const ConversacionQuejaView({super.key, this.solicitudId, this.quejaRef});

  final String? solicitudId;
  final String? quejaRef;

  @override
  State<ConversacionQuejaView> createState() => _ConversacionQuejaViewState();
}

class _ConversacionQuejaViewState extends State<ConversacionQuejaView> {
  late final _solicitud = TextEditingController(text: widget.solicitudId);
  late final _queja = TextEditingController(text: widget.quejaRef);
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _solicitud.dispose();
    _queja.dispose();
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barraDePantalla(context, titulo: 'Conversación de una queja'),
      body: BlocBuilder<ConversacionQuejaCubit, ConversacionQuejaState>(
        builder: (context, state) {
          final consultando = state.fase == FaseConversacion.consultando;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Cada consulta queda registrada con quién la hizo, el motivo y '
                'cuántos mensajes se vieron.',
                key: Key('aviso-auditoria'),
              ),
              const SizedBox(height: 12),
              ManiTextField(
                key: const Key('campo-solicitud'),
                controller: _solicitud,
                decoration: const InputDecoration(
                  labelText: 'Id de la solicitud',
                ),
              ),
              ManiTextField(
                key: const Key('campo-queja'),
                controller: _queja,
                decoration: const InputDecoration(
                  labelText: 'Referencia de la queja (opcional)',
                ),
              ),
              ManiTextField(
                key: const Key('campo-motivo'),
                controller: _motivo,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Motivo de la consulta',
                ),
              ),
              const SizedBox(height: 8),
              ManiButton(
                key: const Key('btn-consultar'),
                etiqueta: consultando ? 'Consultando…' : 'Ver conversación',
                onPressed: consultando
                    ? null
                    : () => context.read<ConversacionQuejaCubit>().consultar(
                        solicitudId: _solicitud.text,
                        motivo: _motivo.text,
                        quejaRef: _queja.text,
                      ),
              ),
              const SizedBox(height: 16),
              if (state.fase == FaseConversacion.error)
                Text(state.error!, key: const Key('error-conversacion')),
              if (state.fase == FaseConversacion.listo) ...[
                Text(
                  'Mensajes vistos: ${state.resultado!.consulta.mensajesVistos}',
                  key: const Key('mensajes-vistos'),
                ),
                const SizedBox(height: 8),
                if (state.resultado!.mensajes.isEmpty)
                  const Text(
                    'Este servicio no tiene mensajes.',
                    key: Key('conversacion-vacia'),
                  ),
                for (final m in state.resultado!.mensajes)
                  Card(
                    key: Key('mensaje-${m.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(m.contenido),
                      subtitle: Text(
                        '${m.etiquetaRemitente.isEmpty ? 'Participante' : m.etiquetaRemitente}'
                        ' · ${formatearFechaHora(m.creadoEn)}',
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
