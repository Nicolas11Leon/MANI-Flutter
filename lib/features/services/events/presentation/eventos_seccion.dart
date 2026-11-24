import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/platform/selector_fotos.dart';
import 'package:mani/core/platform/url_opener.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/features/services/requests/domain/entities/foto_adjunta.dart';
import 'package:mani/features/services/requests/domain/failures/solicitud_failure.dart';
import 'package:mani/features/services/tracking/presentation/mis_solicitudes_page.dart'
    show formatearFecha;

import '../data/cola_eventos.dart';
import '../data/eventos_datasource.dart';
import 'eventos_cubit.dart';

/// Bitácora del servicio: la secuencia de eventos que guarda Core.
///
/// - Aliado (US-04.3.2 / SCRUM-869): mientras el servicio está en ejecución,
///   además registra eventos con foto opcional.
/// - Cliente (US-04.3.3 / SCRUM-870): la consulta en solo lectura.
///
/// En los eventos con foto, «Ver foto» pide a Core una URL temporal y la abre.
///
/// Sin conexión (SCRUM-873), los eventos del aliado que esperan envío se ven
/// arriba de la bitácora como «Pendiente de enviar», con la hora de captura.
class EventosSeccion extends StatelessWidget {
  const EventosSeccion({
    super.key,
    required this.puedeRegistrar,
    required this.urlOpener,
    this.selectorFotos,
  });

  /// El aliado puede registrar: el servicio está en ejecución. Siempre `false`
  /// para el cliente.
  final bool puedeRegistrar;
  final UrlOpener urlOpener;

  /// Solo hace falta si [puedeRegistrar].
  final SelectorFotos? selectorFotos;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EventosCubit, EventosState>(
      listenWhen: (a, b) => b.aviso != null && a.aviso != b.aviso,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.aviso!),
              backgroundColor: state.avisoEsError
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          );
      },
      builder: (context, state) {
        return ManiCard(
          key: const Key('seccion-eventos'),
          padding: const EdgeInsets.all(ManiSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(ManiSpace.sm),
                    decoration: BoxDecoration(
                      color: context.mani.brand,
                      borderRadius: ManiRadius.brXs,
                      border: Border.all(
                        color: context.mani.border,
                        width: ManiBorder.thin,
                      ),
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: context.mani.onBrand,
                    ),
                  ),
                  ManiGap.hSm,
                  Flexible(
                    child: Text(
                      'Bitácora del servicio',
                      style: TextStyle(
                        fontSize: ManiFontSize.bodyLg,
                        fontWeight: FontWeight.w800,
                        color: context.mani.ink,
                      ),
                    ),
                  ),
                ],
              ),
              ManiGap.vMd,
              if (puedeRegistrar && selectorFotos != null)
                _FormularioEvento(
                  enviando: state.enviando,
                  selectorFotos: selectorFotos!,
                ),
              if (state.pendientes.isNotEmpty) _Pendientes(state.pendientes),
              if (state.cargando && state.eventos.isEmpty)
                LinearProgressIndicator(color: context.mani.ink)
              else if (state.error != null && state.eventos.isEmpty)
                Row(
                  children: [
                    Expanded(child: Text(state.error!)),
                    TextButton(
                      onPressed: context.read<EventosCubit>().cargar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                )
              else if (state.eventos.isEmpty)
                const Text('Aún no hay eventos registrados.')
              else
                for (final e in state.eventos) _Evento(e, urlOpener: urlOpener),
            ],
          ),
        );
      },
    );
  }
}

class _Evento extends StatelessWidget {
  const _Evento(this.evento, {required this.urlOpener});

  final EventoServicio evento;
  final UrlOpener urlOpener;

  Future<void> _verFoto(BuildContext context) async {
    final url = await context.read<EventosCubit>().urlEvidencia(evento.id);
    if (url == null) return;
    final abierta = await urlOpener.abrir(url);
    if (!abierta && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la foto.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = evento;
    return ListTile(
      key: Key('evento-${e.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        e.tieneEvidencia ? Icons.photo_camera_outlined : Icons.circle_outlined,
        size: 20,
      ),
      title: Text(e.etiquetaTipo),
      subtitle: Text(
        [
          if ((e.descripcion ?? '').trim().isNotEmpty) e.descripcion!.trim(),
          // La hora de captura es la oficial (SCRUM-873); si el evento llegó
          // después, también se muestra cuándo lo recibió Core.
          if (e.llegoTarde)
            'Tomado: ${formatearFecha(e.ocurridoEn)} · '
                'Enviado: ${formatearFecha(e.registradoEn)}'
          else
            formatearFecha(e.ocurridoEn),
        ].join('\n'),
      ),
      trailing: e.tieneEvidencia
          ? TextButton(
              key: Key('ver-foto-${e.id}'),
              onPressed: () => _verFoto(context),
              child: const Text('Ver foto'),
            )
          : null,
    );
  }
}

class _Pendientes extends StatelessWidget {
  const _Pendientes(this.pendientes);

  final List<EventoPendiente> pendientes;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Container(
      key: const Key('eventos-pendientes'),
      margin: const EdgeInsets.only(bottom: ManiSpace.sm),
      padding: const EdgeInsets.all(ManiSpace.sm),
      decoration: BoxDecoration(
        color: colores.secondaryContainer,
        borderRadius: ManiRadius.brSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: colores.onSecondaryContainer,
              ),
              ManiGap.hSm,
              Expanded(
                child: Text(
                  pendientes.length == 1
                      ? '1 evento pendiente de enviar'
                      : '${pendientes.length} eventos pendientes de enviar',
                  style: TextStyle(color: colores.onSecondaryContainer),
                ),
              ),
              TextButton(
                key: const Key('btn-enviar-pendientes'),
                onPressed: context.read<EventosCubit>().sincronizar,
                child: const Text('Enviar ahora'),
              ),
            ],
          ),
          for (final e in pendientes)
            ListTile(
              key: Key('pendiente-${e.clave}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                e.foto != null
                    ? Icons.photo_camera_outlined
                    : Icons.schedule_outlined,
                size: 20,
              ),
              title: Text('${e.tipo.etiqueta} · Pendiente de enviar'),
              subtitle: Text(
                '${e.observacion}\nTomado: '
                '${formatearFecha(e.ocurridoEn.toLocal())}',
              ),
            ),
        ],
      ),
    );
  }
}

class _FormularioEvento extends StatefulWidget {
  const _FormularioEvento({
    required this.enviando,
    required this.selectorFotos,
  });

  final bool enviando;
  final SelectorFotos selectorFotos;

  @override
  State<_FormularioEvento> createState() => _FormularioEventoState();
}

class _FormularioEventoState extends State<_FormularioEvento> {
  final _observacion = TextEditingController();
  TipoEventoAliado _tipo = TipoEventoAliado.avance;
  FotoAdjunta? _foto;

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto() async {
    final elegidas = await widget.selectorFotos.seleccionar();
    if (elegidas.isEmpty || !mounted) return;
    try {
      setState(
        () => _foto = FotoAdjunta.crear(
          nombre: elegidas.first.nombre,
          bytes: elegidas.first.bytes,
        ),
      );
    } on SolicitudFailure catch (f) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.mensajeUsuario)));
    }
  }

  Future<void> _enviar() async {
    final ok = await context.read<EventosCubit>().registrar(
      tipo: _tipo,
      observacion: _observacion.text.trim(),
      foto: _foto,
    );
    if (ok && mounted) {
      setState(() {
        _observacion.clear();
        _foto = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final valido = _observacion.text.trim().length >= 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TipoEventoAliado>(
          key: const Key('tipo-evento'),
          segments: [
            for (final t in TipoEventoAliado.values)
              ButtonSegment(value: t, label: Text(t.etiqueta)),
          ],
          selected: {_tipo},
          onSelectionChanged: (s) => setState(() => _tipo = s.first),
        ),
        ManiGap.vSm,
        TextField(
          key: const Key('campo-observacion-evento'),
          controller: _observacion,
          maxLength: 2000,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '¿Qué pasó?',
            helperText: 'Mínimo 3 caracteres',
          ),
          onChanged: (_) => setState(() {}),
        ),
        Row(
          children: [
            TextButton.icon(
              key: const Key('btn-foto-evento'),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(_foto == null ? 'Agregar foto' : 'Cambiar foto'),
              onPressed: widget.enviando ? null : _elegirFoto,
            ),
            if (_foto != null)
              Expanded(
                child: Text(
                  _foto!.nombre,
                  key: const Key('foto-evento-elegida'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        ManiGap.vMd,
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
            child: ManiButton(
              key: const Key('btn-registrar-evento'),
              etiqueta: widget.enviando ? 'Registrando…' : 'Registrar evento',
              icono: Icons.note_add_outlined,
              expandir: true,
              cargando: widget.enviando,
              onPressed: widget.enviando || !valido ? null : _enviar,
            ),
          ),
        ),
        ManiGap.vMd,
      ],
    );
  }
}
