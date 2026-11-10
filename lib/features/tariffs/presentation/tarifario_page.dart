import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/network/mensaje_error_gateway.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/features/services/categories/domain/entities/categoria_servicio.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart'
    show formatearPesos;

import '../domain/tarifa.dart';
import 'tarifario_cubit.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_estado.dart';

final _importeRe = RegExp(r'^\d{1,10}([.,]\d{1,2})?$');
final _fechaRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

double? _importe(String texto) {
  final t = texto.trim();
  return _importeRe.hasMatch(t) ? double.parse(t.replaceAll(',', '.')) : null;
}

/// Tarifario de referencia del tenant (HU-M10-01 / SCRUM-885).
///
/// Lista las categorías del tenant con su tarifa activa. «Cargar tarifa» crea
/// la primera versión; «Editar» crea la siguiente y deja la anterior en el
/// historial. Tenant y actor salen del JWT; las reglas las vuelve a aplicar
/// Core, que rechaza sin tocar la tarifa vigente.
class TarifarioPage extends StatelessWidget {
  const TarifarioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TarifarioCubit, TarifarioState>(
      listenWhen: (a, b) => b.aviso != null && a.aviso != b.aviso,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('tarifario-aviso'),
              content: Text(state.aviso!),
              backgroundColor: state.avisoEsError
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          );
      },
      builder: (context, state) {
        final cubit = context.read<TarifarioCubit>();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: RefreshIndicator(
              onRefresh: cubit.cargar,
              child: ListView(
                padding: const EdgeInsets.all(ManiSpace.lg),
                children: [
                  Text(
                    'Tarifario de referencia',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  ManiGap.vXs,
                  const Text(
                    'Rango de precios por categoría que el motor de reglas usa '
                    'para contrastar las cotizaciones. Editar crea una versión '
                    'nueva y conserva la anterior.',
                  ),
                  ManiGap.vLg,
                  if (state.cargando && state.categorias.isEmpty)
                    const ManiCargando()
                  else if (state.error != null)
                    _Error(mensaje: state.error!, onReintentar: cubit.cargar)
                  else if (state.categorias.isEmpty)
                    const Card(
                      key: Key('tarifario-sin-categorias'),
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Aún no hay categorías en el catálogo'),
                        subtitle: Text(
                          'Crea una categoría para poder cargar su tarifa.',
                        ),
                      ),
                    )
                  else
                    for (final c in state.categorias)
                      _TarjetaCategoria(
                        categoria: c,
                        tarifas: state.tarifasDe(c.id),
                        guardando: state.guardando,
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TarjetaCategoria extends StatelessWidget {
  const _TarjetaCategoria({
    required this.categoria,
    required this.tarifas,
    required this.guardando,
  });

  final CategoriaServicio categoria;
  final List<Tarifa> tarifas;
  final bool guardando;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final cubit = context.read<TarifarioCubit>();
    return Card(
      key: Key('tarifa-categoria-${categoria.id}'),
      child: Padding(
        padding: const EdgeInsets.all(ManiSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(categoria.nombre, style: tema.titleMedium),
                ),
                if (!categoria.activa) const Chip(label: Text('Inactiva')),
              ],
            ),
            ManiGap.vSm,
            if (tarifas.isEmpty)
              const Text('Sin tarifa de referencia.')
            else
              for (final t in tarifas) ...[
                Text(
                  '${formatearPesos(t.valorMin)} – ${formatearPesos(t.valorMax)} '
                  '(típico ${formatearPesos(t.valorTipico)}) ${t.moneda}',
                  key: Key('tarifa-rango-${t.id}'),
                  style: tema.bodyLarge,
                ),
                Text(
                  '${t.vigencia} · versión ${t.version}',
                  style: tema.bodySmall,
                ),
                if (t.condiciones != null)
                  Text('Condiciones: ${t.condiciones}', style: tema.bodySmall),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: Key('editar-tarifa-${t.id}'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                    onPressed: guardando
                        ? null
                        : () => _abrirFormulario(context, cubit, categoria, t),
                  ),
                ),
              ],
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton.icon(
                  key: Key('historial-tarifa-${categoria.id}'),
                  icon: const Icon(Icons.history),
                  label: const Text('Historial'),
                  onPressed: () => _verHistorial(context, cubit, categoria),
                ),
                TextButton.icon(
                  key: Key('cargar-tarifa-${categoria.id}'),
                  icon: const Icon(Icons.add),
                  label: Text(
                    tarifas.isEmpty ? 'Cargar tarifa' : 'Otra vigencia',
                  ),
                  onPressed: guardando
                      ? null
                      : () => _abrirFormulario(context, cubit, categoria, null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _abrirFormulario(
  BuildContext context,
  TarifarioCubit cubit,
  CategoriaServicio categoria,
  Tarifa? actual,
) async {
  final datos = await showDialog<DatosTarifa>(
    context: context,
    builder: (_) => DialogoTarifa(categoria: categoria.nombre, actual: actual),
  );
  if (datos == null) return;
  await cubit.guardar(
    categoriaId: categoria.id,
    tarifaId: actual?.id,
    datos: datos,
  );
}

Future<void> _verHistorial(
  BuildContext context,
  TarifarioCubit cubit,
  CategoriaServicio categoria,
) => showDialog<void>(
  context: context,
  builder: (_) => AlertDialog(
    title: Text('Historial · ${categoria.nombre}'),
    content: SizedBox(
      width: 480,
      child: FutureBuilder<List<Tarifa>>(
        future: cubit.historial(categoria.id),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 80, child: ManiCargando());
          }
          if (snap.hasError) return Text(mensajeErrorGateway(snap.error!));
          final versiones = snap.data!;
          if (versiones.isEmpty) {
            return const Text('Sin versiones registradas.');
          }
          return ListView(
            shrinkWrap: true,
            children: [
              for (final v in versiones)
                ListTile(
                  key: Key('historial-version-${v.version}'),
                  dense: true,
                  leading: CircleAvatar(child: Text('v${v.version}')),
                  title: Text(
                    '${formatearPesos(v.valorMin)} – ${formatearPesos(v.valorMax)}',
                  ),
                  subtitle: Text(
                    '${v.activa ? 'Activa' : 'Reemplazada'} · ${v.vigencia}',
                  ),
                ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cerrar'),
      ),
    ],
  ),
);

/// Formulario de una tarifa. Devuelve los [DatosTarifa] solo si cumplen las
/// reglas de C2; Core las vuelve a aplicar.
class DialogoTarifa extends StatefulWidget {
  const DialogoTarifa({super.key, required this.categoria, this.actual});

  final String categoria;
  final Tarifa? actual;

  @override
  State<DialogoTarifa> createState() => _DialogoTarifaState();
}

class _DialogoTarifaState extends State<DialogoTarifa> {
  late final _min = TextEditingController(
    text: _texto(widget.actual?.valorMin),
  );
  late final _tipico = TextEditingController(
    text: _texto(widget.actual?.valorTipico),
  );
  late final _max = TextEditingController(
    text: _texto(widget.actual?.valorMax),
  );
  late final _desde = TextEditingController(
    text: widget.actual?.vigenciaDesde ?? '',
  );
  late final _hasta = TextEditingController(
    text: widget.actual?.vigenciaHasta ?? '',
  );
  late final _condiciones = TextEditingController(
    text: widget.actual?.condiciones ?? '',
  );
  String? _error;

  static String _texto(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');

  @override
  void dispose() {
    for (final c in [_min, _tipico, _max, _desde, _hasta, _condiciones]) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    final min = _importe(_min.text);
    final tipico = _importe(_tipico.text);
    final max = _importe(_max.text);
    if (min == null || tipico == null || max == null) {
      setState(
        () => _error =
            'Escribe los tres valores sin signos, con máximo dos decimales.',
      );
      return;
    }
    final desde = _desde.text.trim();
    final hasta = _hasta.text.trim();
    if ((desde.isNotEmpty && !_fechaRe.hasMatch(desde)) ||
        (hasta.isNotEmpty && !_fechaRe.hasMatch(hasta))) {
      setState(() => _error = 'Las fechas van en formato AAAA-MM-DD.');
      return;
    }
    final condiciones = _condiciones.text.trim();
    final datos = DatosTarifa(
      valorMin: min,
      valorTipico: tipico,
      valorMax: max,
      vigenciaDesde: desde.isEmpty ? null : desde,
      vigenciaHasta: hasta.isEmpty ? null : hasta,
      condiciones: condiciones.isEmpty ? null : condiciones,
    );
    final invalida = datos.error;
    if (invalida != null) {
      setState(() => _error = invalida);
      return;
    }
    Navigator.of(context).pop(datos);
  }

  Widget _campo(
    TextEditingController c,
    String etiqueta,
    String clave, {
    bool numerico = false,
    String? ayuda,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: ManiSpace.sm),
    child: TextField(
      key: Key(clave),
      controller: c,
      maxLength: maxLength,
      keyboardType: numerico
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      inputFormatters: numerico
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : null,
      decoration: InputDecoration(labelText: etiqueta, helperText: ayuda),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.actual == null
            ? 'Cargar tarifa · ${widget.categoria}'
            : 'Editar tarifa · ${widget.categoria} (v${widget.actual!.version + 1})',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _campo(_min, 'Valor mínimo', 'tarifa-min', numerico: true),
              _campo(_tipico, 'Valor típico', 'tarifa-tipico', numerico: true),
              _campo(_max, 'Valor máximo', 'tarifa-max', numerico: true),
              _campo(
                _desde,
                'Vigente desde (AAAA-MM-DD)',
                'tarifa-desde',
                ayuda: 'Vacío: desde hoy',
              ),
              _campo(
                _hasta,
                'Vigente hasta (AAAA-MM-DD)',
                'tarifa-hasta',
                ayuda: 'Vacío: sin fecha de fin',
              ),
              _campo(
                _condiciones,
                'Condiciones contractuales',
                'tarifa-condiciones',
                maxLength: 500,
              ),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('tarifa-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ManiButton(
          key: const Key('tarifa-guardar'),
          etiqueta: 'Guardar',
          onPressed: _guardar,
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('tarifario-error'),
    child: ListTile(
      leading: const Icon(Icons.error_outline),
      title: Text(mensaje),
      trailing: TextButton(
        onPressed: onReintentar,
        child: const Text('Reintentar'),
      ),
    ),
  );
}
