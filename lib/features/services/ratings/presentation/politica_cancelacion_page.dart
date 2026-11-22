import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/widgets/mani_button.dart';

import '../data/politica_cancelacion_datasource.dart';
import '../domain/calificacion_cierre_modelos.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

class PoliticaCancelacionState extends Equatable {
  const PoliticaCancelacionState({
    this.cargando = false,
    this.guardando = false,
    this.politica,
    this.error,
    this.aviso,
    this.avisoEsError = false,
  });

  final bool cargando;
  final bool guardando;
  final PoliticaCancelacion? politica;
  final String? error;
  final String? aviso;
  final bool avisoEsError;

  @override
  List<Object?> get props => [
    cargando,
    guardando,
    politica,
    error,
    aviso,
    avisoEsError,
  ];
}

String _mensaje(Object e) => e is ModuloM08Failure
    ? e.mensajeUsuario
    : const ModuloM08Failure(ModuloM08ErrorTipo.desconocido).mensajeUsuario;

/// Política de cancelación tardía del tenant (SCRUM-878). El administrador la
/// activa o desactiva y ajusta la ventana gratuita y el cobro. Lo que se ve
/// tras guardar es lo que devolvió Core.
class PoliticaCancelacionCubit extends Cubit<PoliticaCancelacionState> {
  PoliticaCancelacionCubit(this._fuente)
    : super(const PoliticaCancelacionState());

  final FuentePoliticaCancelacion _fuente;

  Future<void> cargar() async {
    emit(const PoliticaCancelacionState(cargando: true));
    try {
      emit(PoliticaCancelacionState(politica: await _fuente.obtener()));
    } catch (e) {
      emit(PoliticaCancelacionState(error: _mensaje(e)));
    }
  }

  Future<bool> guardar(PoliticaCancelacion politica) async {
    final invalida = politica.error;
    if (invalida != null) {
      emit(
        PoliticaCancelacionState(
          politica: state.politica,
          aviso: invalida,
          avisoEsError: true,
        ),
      );
      return false;
    }
    emit(PoliticaCancelacionState(politica: state.politica, guardando: true));
    try {
      final guardada = await _fuente.guardar(politica);
      emit(
        PoliticaCancelacionState(
          politica: guardada,
          aviso: guardada.activa
              ? 'Política activada: se cobrará penalización por cancelación tardía.'
              : 'Política desactivada: las cancelaciones no tienen penalización.',
        ),
      );
      return true;
    } catch (e) {
      emit(
        PoliticaCancelacionState(
          politica: state.politica,
          aviso: _mensaje(e),
          avisoEsError: true,
        ),
      );
      return false;
    }
  }
}

class PoliticaCancelacionPage extends StatelessWidget {
  const PoliticaCancelacionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PoliticaCancelacionCubit, PoliticaCancelacionState>(
      listenWhen: (a, b) => b.aviso != null && a.aviso != b.aviso,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('politica-aviso'),
              content: Text(state.aviso!),
              backgroundColor: state.avisoEsError
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          );
      },
      builder: (context, state) {
        final cubit = context.read<PoliticaCancelacionCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ManiEncabezadoPantalla(
              ancho: ManiAncho.formulario,
              icono: Icons.event_busy_rounded,
              titulo: 'Política de cancelación',
              descripcion:
                  'Si está activa, el cliente que cancela un servicio ya asignado después de la ventana gratuita '
                  'paga una penalización. El cliente la ve antes de confirmar la cancelación.',
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ManiAncho.formulario,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(ManiSpace.lg),
                    children: [
                      if (state.cargando)
                        const ManiCargando()
                      else if (state.error != null)
                        Card(
                          key: const Key('politica-error'),
                          child: ListTile(
                            leading: const Icon(Icons.error_outline),
                            title: Text(state.error!),
                            trailing: TextButton(
                              onPressed: cubit.cargar,
                              child: const Text('Reintentar'),
                            ),
                          ),
                        )
                      else if (state.politica != null)
                        _FormularioPolitica(
                          // La clave renueva el formulario con lo que devolvió Core tras guardar.
                          key: ValueKey(state.politica),
                          politica: state.politica!,
                          guardando: state.guardando,
                          onGuardar: cubit.guardar,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FormularioPolitica extends StatefulWidget {
  const _FormularioPolitica({
    super.key,
    required this.politica,
    required this.guardando,
    required this.onGuardar,
  });

  final PoliticaCancelacion politica;
  final bool guardando;
  final Future<bool> Function(PoliticaCancelacion) onGuardar;

  @override
  State<_FormularioPolitica> createState() => _FormularioPoliticaState();
}

class _FormularioPoliticaState extends State<_FormularioPolitica> {
  late bool _activa = widget.politica.activa;
  late TipoCobroPenalizacion _tipo = widget.politica.tipoCobro;
  late final _ventana = TextEditingController(
    text: '${widget.politica.ventanaGratuitaMinutos}',
  );
  late final _valor = TextEditingController(
    text: widget.politica.valor == widget.politica.valor.roundToDouble()
        ? widget.politica.valor.toStringAsFixed(0)
        : '${widget.politica.valor}',
  );

  @override
  void dispose() {
    _ventana.dispose();
    _valor.dispose();
    super.dispose();
  }

  void _guardar() {
    widget.onGuardar(
      widget.politica.copiar(
        activa: _activa,
        tipoCobro: _tipo,
        ventanaGratuitaMinutos: int.tryParse(_ventana.text.trim()) ?? -1,
        valor: double.tryParse(_valor.text.trim().replaceAll(',', '.')) ?? -1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('politica-formulario'),
      child: Padding(
        padding: const EdgeInsets.all(ManiSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: const Key('politica-activa'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Cobrar penalización por cancelación tardía'),
              subtitle: Text(_activa ? 'Activa' : 'Desactivada'),
              value: _activa,
              onChanged: widget.guardando
                  ? null
                  : (v) => setState(() => _activa = v),
            ),
            ManiGap.vSm,
            TextField(
              key: const Key('politica-ventana'),
              controller: _ventana,
              enabled: !widget.guardando,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Ventana gratuita (minutos desde la asignación)',
                helperText: 'De 0 a 1440',
              ),
            ),
            ManiGap.vMd,
            DropdownButtonFormField<TipoCobroPenalizacion>(
              key: const Key('politica-tipo'),
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo de cobro'),
              items: [
                for (final t in TipoCobroPenalizacion.values)
                  DropdownMenuItem(value: t, child: Text(t.etiqueta)),
              ],
              onChanged: widget.guardando
                  ? null
                  : (t) => setState(() => _tipo = t ?? _tipo),
            ),
            ManiGap.vMd,
            TextField(
              key: const Key('politica-valor'),
              controller: _valor,
              enabled: !widget.guardando,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: _tipo == TipoCobroPenalizacion.porcentaje
                    ? 'Porcentaje (0 a 100)'
                    : 'Monto en pesos',
              ),
            ),
            ManiGap.vLg,
            ManiButton(
              key: const Key('politica-guardar'),
              etiqueta: 'Guardar política',
              cargando: widget.guardando,
              onPressed: widget.guardando ? null : _guardar,
            ),
          ],
        ),
      ),
    );
  }
}
