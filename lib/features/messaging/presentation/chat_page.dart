import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';

import '../domain/mensaje.dart';
import 'chat_cubit.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

/// Conversación del cliente con el aliado de un servicio (SCRUM-881, HU-M09-02).
/// Se actualiza consultando a Core cada pocos segundos mientras está abierta, y
/// deja de consultar cuando la app pasa a segundo plano.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  int _vistos = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    final cubit = context.read<ChatCubit>();
    if (estado == AppLifecycleState.resumed) {
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
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManiBarraPagina(
            icono: Icons.chat_rounded,
            titulo: 'Mensajes del servicio',
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ManiAncho.formulario,
                ),
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
          ),
        ],
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
      return const Center(
        child: CircularProgressIndicator(key: Key('cargando-chat')),
      );
    }
    if (state.mensajes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(ManiSpace.xxl),
          child: Text(
            'Aún no hay mensajes. Escribe el primero.',
            key: Key('chat-vacio'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      key: const Key('lista-mensajes'),
      controller: scroll,
      padding: const EdgeInsets.all(ManiSpace.md),
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
    final colores = Theme.of(context).colorScheme;
    final mio = mensaje.esMio;
    final hora = _hora(mensaje.creadoEn);
    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: Key('mensaje-${mensaje.id}'),
        margin: const EdgeInsets.symmetric(vertical: ManiSpace.xs),
        padding: const EdgeInsets.all(ManiSpace.sm),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: mio ? colores.primaryContainer : colores.surfaceContainerHigh,
          borderRadius: ManiRadius.brMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mio && mensaje.etiquetaRemitente.isNotEmpty)
              Text(
                mensaje.etiquetaRemitente,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            Text(mensaje.contenido),
            if (hora.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  hora,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ManiSpace.sm),
      color: colores.tertiaryContainer,
      child: Text(texto, style: TextStyle(color: colores.onTertiaryContainer)),
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
        padding: const EdgeInsets.fromLTRB(
          ManiSpace.lg,
          ManiSpace.sm,
          ManiSpace.lg,
          ManiSpace.lg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
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
                  filled: true,
                  fillColor: ManiColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: ManiSpace.lg,
                    vertical: ManiSpace.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: ManiRadius.brSm,
                    borderSide: ManiBorder.side,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: ManiRadius.brSm,
                    borderSide: ManiBorder.side,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: ManiRadius.brSm,
                    borderSide: ManiBorder.side,
                  ),
                ),
              ),
            ),
            ManiGap.hSm,
            Padding(
              padding: const EdgeInsets.only(bottom: ManiSpace.xxs),
              child: ManiButton(
                key: const Key('btn-enviar-mensaje'),
                etiqueta: 'Enviar',
                icono: Icons.send,
                cargando: enviando,
                onPressed: enviando ? null : alEnviar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
