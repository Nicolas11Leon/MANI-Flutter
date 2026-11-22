import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart'
    show formatearPesos;

import '../data/adiciones_datasource.dart';
import 'adiciones_cubit.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Importe de la adición: no negativo, hasta diez enteros y dos decimales, el
/// mismo formato que valida Core (DECIMAL(12,2)).
final _importeRe = RegExp(r'^\d{1,10}([.,]\d{1,2})?$');
const _motivoMin = 10;
const _motivoMax = 500;
const _tiempoMax = 7 * 24 * 60;

/// Sección «Adiciones» de la pantalla del servicio (US-04.3.5 / SCRUM-872).
///
/// - Aliado asignado: con el servicio en ejecución ([puedePedir]) pide una
///   adición con motivo, mano de obra y materiales; solo una pendiente a la vez.
/// - Cliente dueño: acepta o rechaza la adición pendiente. Rechazarla no
///   termina el servicio.
/// - Ambos ven el total vigente (cotización aceptada + adiciones aceptadas),
///   que es lo que cobra el pago. El tope del 50 % lo aplica Core.
///
/// Sin cotización aceptada y sin adiciones no muestra nada.
class AdicionesSeccion extends StatelessWidget {
  const AdicionesSeccion({
    super.key,
    required this.esAliado,
    required this.puedePedir,
  });

  final bool esAliado;
  final bool puedePedir;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdicionesCubit, AdicionesState>(
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
        final datos = state.datos;
        if (datos == null && !state.cargando && state.error == null) {
          return const SizedBox.shrink();
        }
        if (datos != null && datos.resumen == null && datos.adiciones.isEmpty) {
          return const SizedBox.shrink();
        }
        return Card(
          key: const Key('seccion-adiciones'),
          child: Padding(
            padding: const EdgeInsets.all(ManiSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Adiciones',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ManiGap.vSm,
                if (state.cargando && datos == null)
                  const LinearProgressIndicator()
                else if (state.error != null && datos == null)
                  Row(
                    children: [
                      Expanded(child: Text(state.error!)),
                      TextButton(
                        onPressed: context.read<AdicionesCubit>().cargar,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  )
                else if (datos != null) ...[
                  if (datos.resumen != null) _Resumen(datos.resumen!),
                  for (final a in datos.adiciones)
                    _AdicionTile(
                      a,
                      esAliado: esAliado,
                      enviando: state.enviando,
                    ),
                  if (esAliado) _AccionAliado(datos, puedePedir: puedePedir),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen(this.resumen);

  final ResumenAdiciones resumen;

  @override
  Widget build(BuildContext context) {
    Widget renglon(String etiqueta, double valor, {bool negrita = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: ManiSpace.xxs),
          child: Row(
            children: [
              Expanded(child: Text(etiqueta)),
              Text(
                formatearPesos(valor),
                style: negrita
                    ? const TextStyle(fontWeight: FontWeight.w800)
                    : null,
              ),
            ],
          ),
        );
    return Column(
      key: const Key('resumen-adiciones'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        renglon('Cotización aceptada', resumen.totalCotizacion),
        renglon('Adiciones aceptadas', resumen.totalAdicionesAceptadas),
        renglon('Total vigente', resumen.totalVigente, negrita: true),
        renglon('Disponible para adiciones', resumen.disponibleParaAdiciones),
        const Divider(),
      ],
    );
  }
}

class _AdicionTile extends StatelessWidget {
  const _AdicionTile(
    this.adicion, {
    required this.esAliado,
    required this.enviando,
  });

  final Adicion adicion;
  final bool esAliado;
  final bool enviando;

  @override
  Widget build(BuildContext context) {
    final estado = switch (adicion.estado) {
      EstadoAdicion.pendiente =>
        esAliado
            ? 'Esperando decisión del cliente'
            : 'Pendiente de tu decisión',
      EstadoAdicion.aceptada => 'Aceptada',
      EstadoAdicion.rechazada => 'Rechazada',
      EstadoAdicion.desconocido => 'Estado desconocido',
    };
    final tiempo = adicion.tiempoAdicionalMinutos;
    return Padding(
      key: Key('adicion-${adicion.id}'),
      padding: const EdgeInsets.symmetric(vertical: ManiSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${formatearPesos(adicion.total)} · $estado',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(adicion.motivo),
          Text(
            'Mano de obra ${formatearPesos(adicion.valorManoObra)} · '
            'Materiales ${formatearPesos(adicion.valorMateriales)}'
            '${tiempo == null ? '' : ' · $tiempo min adicionales'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if ((adicion.comentarioCliente ?? '').isNotEmpty)
            Text(
              'Comentario del cliente: ${adicion.comentarioCliente}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (!esAliado && adicion.pendiente) ...[
            ManiGap.vSm,
            Row(
              children: [
                Expanded(
                  child: ManiButton(
                    key: const Key('btn-aceptar-adicion'),
                    etiqueta: 'Aceptar',
                    icono: Icons.check_rounded,
                    cargando: enviando,
                    onPressed: enviando
                        ? null
                        : () => _decidir(context, DecisionAdicion.aceptar),
                  ),
                ),
                ManiGap.hSm,
                Expanded(
                  child: ManiButton(
                    key: const Key('btn-rechazar-adicion'),
                    etiqueta: 'Rechazar',
                    icono: Icons.close_rounded,
                    variante: ManiButtonVariante.secundario,
                    onPressed: enviando
                        ? null
                        : () => _decidir(context, DecisionAdicion.rechazar),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _decidir(BuildContext context, DecisionAdicion decision) async {
    final cubit = context.read<AdicionesCubit>();
    final comentario = await showDialog<String>(
      context: context,
      builder: (_) =>
          _DialogoDecision(decision: decision, total: adicion.total),
    );
    if (comentario == null) return;
    await cubit.responder(adicion.id, decision, comentario: comentario);
  }
}

/// Confirma la decisión con un comentario opcional. Devuelve null si se cancela.
class _DialogoDecision extends StatefulWidget {
  const _DialogoDecision({required this.decision, required this.total});

  final DecisionAdicion decision;
  final double total;

  @override
  State<_DialogoDecision> createState() => _DialogoDecisionState();
}

class _DialogoDecisionState extends State<_DialogoDecision> {
  final _comentario = TextEditingController();

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aceptar = widget.decision == DecisionAdicion.aceptar;
    return AlertDialog(
      title: Text(aceptar ? 'Aceptar adición' : 'Rechazar adición'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            aceptar
                ? 'Se sumarán ${formatearPesos(widget.total)} al total del servicio.'
                : 'El servicio sigue en ejecución con el valor pactado.',
          ),
          ManiGap.vSm,
          TextField(
            key: const Key('campo-comentario-adicion'),
            controller: _comentario,
            maxLength: _motivoMax,
            decoration: const InputDecoration(
              labelText: 'Comentario (opcional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('btn-confirmar-decision-adicion'),
          onPressed: () => Navigator.of(context).pop(_comentario.text),
          child: Text(aceptar ? 'Aceptar' : 'Rechazar'),
        ),
      ],
    );
  }
}

class _AccionAliado extends StatelessWidget {
  const _AccionAliado(this.datos, {required this.puedePedir});

  final AdicionesServicio datos;
  final bool puedePedir;

  @override
  Widget build(BuildContext context) {
    if (!puedePedir || datos.resumen == null) return const SizedBox.shrink();
    if (datos.hayPendiente) {
      return const Padding(
        padding: EdgeInsets.only(top: ManiSpace.sm),
        child: Text(
          'Hay una adición esperando la decisión del cliente.',
          key: Key('adicion-pendiente-aliado'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: ManiSpace.sm),
      child: ManiButton(
        key: const Key('btn-pedir-adicion'),
        etiqueta: 'Pedir adición por imprevisto',
        icono: Icons.add_circle_outline,
        variante: ManiButtonVariante.secundario,
        expandir: true,
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => BlocProvider.value(
            value: context.read<AdicionesCubit>(),
            child: _FormularioAdicion(
              disponible: datos.resumen!.disponibleParaAdiciones,
            ),
          ),
        ),
      ),
    );
  }
}

/// Formulario del aliado. Se cierra solo cuando Core registró la adición, así
/// un error (por ejemplo, el tope) no le borra lo que escribió.
class _FormularioAdicion extends StatefulWidget {
  const _FormularioAdicion({required this.disponible});

  final double disponible;

  @override
  State<_FormularioAdicion> createState() => _FormularioAdicionState();
}

class _FormularioAdicionState extends State<_FormularioAdicion> {
  final _form = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  final _manoObra = TextEditingController();
  final _materiales = TextEditingController();
  final _tiempo = TextEditingController();
  bool _enviando = false;
  String? _errorTotal;

  @override
  void dispose() {
    _motivo.dispose();
    _manoObra.dispose();
    _materiales.dispose();
    _tiempo.dispose();
    super.dispose();
  }

  static String _normalizado(String v) => v.trim().replaceAll(',', '.');

  static double _valor(String v) =>
      _importeRe.hasMatch(v.trim()) ? double.parse(_normalizado(v)) : 0;

  static String? _validarImporte(String? v) {
    if (v == null || v.trim().isEmpty) return 'Obligatorio (puede ser 0)';
    if (!_importeRe.hasMatch(v.trim())) {
      return 'Valor no negativo con máximo dos decimales';
    }
    return null;
  }

  static String? _validarMotivo(String? v) {
    final largo = (v ?? '').trim().length;
    if (largo < _motivoMin || largo > _motivoMax) {
      return 'Describe el imprevisto ($_motivoMin a $_motivoMax caracteres)';
    }
    return null;
  }

  static String? _validarTiempo(String? v) {
    final texto = (v ?? '').trim();
    if (texto.isEmpty) return null;
    final minutos = int.tryParse(texto);
    if (minutos == null || minutos < 1 || minutos > _tiempoMax) {
      return 'Minutos entre 1 y $_tiempoMax';
    }
    return null;
  }

  double get _total => _valor(_manoObra.text) + _valor(_materiales.text);

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    if (_total <= 0) {
      setState(() => _errorTotal = 'Al menos un valor debe ser mayor que 0');
      return;
    }
    setState(() {
      _errorTotal = null;
      _enviando = true;
    });
    final tiempo = _tiempo.text.trim();
    final ok = await context.read<AdicionesCubit>().solicitar(
      motivo: _motivo.text,
      valorManoObra: _normalizado(_manoObra.text),
      valorMateriales: _normalizado(_materiales.text),
      tiempoAdicionalMinutos: tiempo.isEmpty ? null : int.parse(tiempo),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formato = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return AlertDialog(
      title: const Text('Pedir adición'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Disponible para adiciones: ${formatearPesos(widget.disponible)}',
                key: const Key('disponible-adicion'),
              ),
              ManiGap.vSm,
              TextFormField(
                key: const Key('campo-motivo-adicion'),
                controller: _motivo,
                maxLength: _motivoMax,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Motivo'),
                validator: _validarMotivo,
              ),
              TextFormField(
                key: const Key('campo-mano-obra-adicion'),
                controller: _manoObra,
                decoration: const InputDecoration(
                  labelText: 'Mano de obra adicional',
                  prefixText: '\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: formato,
                validator: _validarImporte,
                onChanged: (_) => setState(() {}),
              ),
              TextFormField(
                key: const Key('campo-materiales-adicion'),
                controller: _materiales,
                decoration: const InputDecoration(
                  labelText: 'Materiales adicionales',
                  prefixText: '\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: formato,
                validator: _validarImporte,
                onChanged: (_) => setState(() {}),
              ),
              TextFormField(
                key: const Key('campo-tiempo-adicion'),
                controller: _tiempo,
                decoration: const InputDecoration(
                  labelText: 'Tiempo adicional estimado (minutos, opcional)',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validarTiempo,
              ),
              ManiGap.vSm,
              Text(
                'Total de la adición: ${formatearPesos(_total)}',
                key: const Key('total-adicion'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (_errorTotal != null)
                Text(
                  _errorTotal!,
                  key: const Key('error-total-adicion'),
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
        FilledButton(
          key: const Key('btn-enviar-adicion'),
          onPressed: _enviando ? null : _enviar,
          child: Text(_enviando ? 'Enviando…' : 'Enviar'),
        ),
      ],
    );
  }
}
