import 'package:mani/core/widgets/mani_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/shell/al_cambiar_visibilidad.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_esqueleto.dart';
import 'package:mani/core/widgets/mani_estados.dart';
import 'package:mani/core/widgets/mani_personaje.dart';

import '../domain/mensaje.dart';
import 'chat_cubit.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';

/// Conversación del cliente con el aliado de un servicio (SCRUM-881, HU-M09-02).
/// Se actualiza consultando a Core cada pocos segundos mientras está a la vista, y
/// deja de consultar cuando la app pasa a segundo plano o la pantalla queda oculta.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  int _vistos = 0;

  @override
  void dispose() {
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _alCambiarVisibilidad(bool visible) {
    final cubit = context.read<ChatCubit>();
    if (visible) {
      cubit.reanudar();
    } else {
      cubit.pausar();
    }
  }

  Future<void> _enviar() async {
    final cubit = context.read<ChatCubit>();
    if (await cubit.enviar(_texto.text)) _texto.clear();
  }

  /// Baja al último mensaje cuando llegan nuevos y la persona ya estaba abajo
  /// (o es la primera carga); si está leyendo más arriba, no la mueve.
  void _bajarSiCorresponde(int total) {
    final nuevos = total > _vistos;
    final primera = _vistos == 0;
    _vistos = total;
    if (!nuevos) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (primera || pos.maxScrollExtent - pos.pixels < 120) {
        _scroll.jumpTo(pos.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlCambiarVisibilidad(
      alCambiar: _alCambiarVisibilidad,
      child: _pantalla(context),
    );
  }

  Widget _pantalla(BuildContext context) {
    return Scaffold(
      appBar: barraDePantalla(context, titulo: 'Mensajes'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: BlocConsumer<ChatCubit, ChatState>(
            listenWhen: (a, b) => a.mensajes.length != b.mensajes.length,
            listener: (context, state) =>
                _bajarSiCorresponde(state.mensajes.length),
            builder: (context, state) => Column(
              children: [
                if (state.errorLectura != null)
                  _Aviso(
                    key: const Key('aviso-lectura'),
                    texto: state.errorLectura!.mensajeUsuario,
                  ),
                Expanded(
                  child: _Hilo(state: state, scroll: _scroll),
                ),
                if (state.soloLectura)
                  const _Aviso(
                    key: Key('aviso-solo-lectura'),
                    cerrado: true,
                    texto:
                        'Este servicio ya no admite mensajes nuevos. Puedes leer '
                        'la conversación.',
                  )
                else if (state.errorEnvio != null)
                  _Aviso(
                    key: const Key('error-envio'),
                    texto: state.errorEnvio!.mensajeUsuario,
                  ),
                if (state.puedeEscribir)
                  _Redactor(
                    controlador: _texto,
                    enviando: state.enviando,
                    alEnviar: _enviar,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hilo extends StatelessWidget {
  const _Hilo({required this.state, required this.scroll});

  final ChatState state;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    if (state.cargando) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: KeyedSubtree(
          key: const Key('cargando-chat'),
          child: ManiEsqueleto.lista(filas: 3),
        ),
      );
    }
    if (state.mensajes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: ManiEstadoVacio(
            key: Key('chat-vacio'),
            compacto: true,
            pose: PoseMani.saludo,
            titulo: 'Mensajes',
            texto: 'Aún no hay mensajes. Escribe el primero.',
          ),
        ),
      );
    }
    return ListView.builder(
      key: const Key('lista-mensajes'),
      controller: scroll,
      padding: const EdgeInsets.all(12),
      itemCount: state.mensajes.length,
      itemBuilder: (_, i) => _Burbuja(mensaje: state.mensajes[i]),
    );
  }
}

String _hora(DateTime? fecha) => fecha == null
    ? ''
    : '${fecha.hour.toString().padLeft(2, '0')}:'
          '${fecha.minute.toString().padLeft(2, '0')}';

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.mensaje});

  final Mensaje mensaje;

  @override
  Widget build(BuildContext context) {
    final mio = mensaje.esMio;
    final hora = _hora(mensaje.creadoEn);
    const radio = Radius.circular(16);
    const esquina = Radius.circular(4);
    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: Key('mensaje-${mensaje.id}'),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          // Propias en amarillo suave y sin borde; ajenas en blanco con borde fino.
          color: mio ? context.mani.brandSoft : context.mani.surface,
          border: mio
              ? null
              : Border.all(color: context.mani.ink, width: ManiBorder.thin),
          borderRadius: BorderRadius.only(
            topLeft: radio,
            topRight: radio,
            bottomLeft: mio ? radio : esquina,
            bottomRight: mio ? esquina : radio,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mio && mensaje.etiquetaRemitente.isNotEmpty)
              Text(
                mensaje.etiquetaRemitente,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.mani.inkMuted,
                ),
              ),
            Text(
              mensaje.contenido,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: context.mani.ink,
              ),
            ),
            if (hora.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  hora,
                  style: TextStyle(fontSize: 12, color: context.mani.inkMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Aviso plano sobre el redactor o la conversación: un candado cuando el chat está cerrado.
class _Aviso extends StatelessWidget {
  const _Aviso({super.key, required this.texto, this.cerrado = false});

  final String texto;
  final bool cerrado;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: cerrado ? context.mani.surfaceMuted : ManiColors.warningContainer,
      child: Row(
        children: [
          Icon(
            cerrado ? Icons.lock_outline : Icons.info_outline,
            size: 20,
            color: cerrado ? context.mani.ink : ManiColors.warningText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cerrado ? context.mani.ink : ManiColors.warningText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Redactor extends StatelessWidget {
  const _Redactor({
    required this.controlador,
    required this.enviando,
    required this.alEnviar,
  });

  final TextEditingController controlador;
  final bool enviando;
  final VoidCallback alEnviar;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ManiTextField(
                key: const Key('campo-mensaje'),
                controller: controlador,
                enabled: !enviando,
                minLines: 1,
                maxLines: 4,
                maxLength: maxCaracteresMensaje,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje…',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide(
                      color: context.mani.ink,
                      width: ManiBorder.thin,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide(
                      color: context.mani.ink,
                      width: ManiBorder.thin,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: 'Enviar',
              child: Material(
                color: enviando
                    ? context.mani.surfaceMuted
                    : context.mani.brand,
                shape: CircleBorder(
                  side: BorderSide(color: context.mani.ink, width: 2),
                ),
                child: InkWell(
                  key: const Key('btn-enviar-mensaje'),
                  customBorder: const CircleBorder(),
                  onTap: enviando ? null : alEnviar,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: enviando
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Icon(Icons.send_rounded, color: context.mani.ink),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
