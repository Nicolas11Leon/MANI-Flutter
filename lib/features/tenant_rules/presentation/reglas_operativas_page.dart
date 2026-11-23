import 'package:mani/core/widgets/mani_text_field.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/barra_accion_principal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/regla_tenant.dart';
import 'tenant_rules_cubit.dart';

import 'package:mani/core/shell/titulo_de_pantalla.dart';

class ReglasOperativasPage extends StatefulWidget {
  const ReglasOperativasPage({super.key});

  @override
  State<ReglasOperativasPage> createState() => _ReglasOperativasPageState();
}

class _ReglasOperativasPageState extends State<ReglasOperativasPage> {
  final _formKey = GlobalKey<FormState>();

  String _criterioOrden = 'CALIFICACION';
  double _toleranciaTarifa = 10.0;
  double _comision = 10.0;
  double _ventanaHoras = 2.0;
  double _penalizacion = 20.0;
  int _minutosOferta = 15;
  bool _inicializado = false;

  void _sincronizarConVigente(ReglasOperativas reglas) {
    if (_inicializado) return;
    _criterioOrden = reglas.criterioOrden;
    _toleranciaTarifa = reglas.toleranciaTarifa;
    _comision = reglas.comisionPorcentaje;
    _ventanaHoras = reglas.ventanaCancelacionHoras;
    _penalizacion = reglas.penalizacionCancelacion;
    _minutosOferta = reglas.minutosParaAceptarOferta;
    _inicializado = true;
  }

  void _guardar(BuildContext context) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<TenantRulesCubit>().guardar(
      ReglasOperativas(
        criterioOrden: _criterioOrden,
        toleranciaTarifa: _toleranciaTarifa,
        comisionPorcentaje: _comision,
        ventanaCancelacionHoras: _ventanaHoras,
        penalizacionCancelacion: _penalizacion,
        minutosParaAceptarOferta: _minutosOferta,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barraDePantalla(context, titulo: 'Reglas de operación'),
      // La acción principal queda fija abajo y visible sin desplazarse, aunque el formulario tenga 5 parámetros
      // (SCRUM-1717, QAS-30). Solo aparece con las reglas cargadas.
      bottomNavigationBar: BlocBuilder<TenantRulesCubit, TenantRulesState>(
        builder: (context, state) {
          if (state is! TenantRulesLoaded) return const SizedBox.shrink();
          return BarraAccionPrincipal(
            anchoMaximo: 800 - 48,
            child: ManiButton(
              key: const Key('btn_guardar_reglas'),
              etiqueta: 'GUARDAR NUEVA VERSIÓN',
              expandir: true,
              cargando: state.guardando,
              onPressed: state.guardando ? null : () => _guardar(context),
            ),
          );
        },
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: BlocConsumer<TenantRulesCubit, TenantRulesState>(
            listener: (context, state) {
              if (state is TenantRulesLoaded) {
                if (state.mensajeExito != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.mensajeExito!),
                      backgroundColor: Colors.green[800],
                    ),
                  );
                }
                if (state.mensajeError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.mensajeError!),
                      backgroundColor: Colors.red[800],
                    ),
                  );
                }
              }
            },
            builder: (context, state) {
              if (state is TenantRulesLoading || state is TenantRulesInitial) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is TenantRulesError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.mensaje,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ManiButton(
                          etiqueta: 'Reintentar',
                          onPressed: () =>
                              context.read<TenantRulesCubit>().cargar(),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final loaded = state as TenantRulesLoaded;
              _sincronizarConVigente(loaded.vigente.reglas);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Encabezado de estado vigente
                      _buildHeaderCard(loaded.vigente),
                      const SizedBox(height: 24),

                      // Formulario de reglas. «Guardar nueva versión» va en la franja fija del pie (QAS-30).
                      _buildFormCard(loaded.guardando),
                      const SizedBox(height: 40),

                      // Historial
                      _buildHistorialCard(loaded.historial),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ReglaTenantVigente vigente) {
    final esPorOmision = vigente.origen == 'POR_OMISION';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esPorOmision ? Colors.yellow[100] : Colors.blue[50],
        border: Border.all(width: 2, color: Colors.black),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                esPorOmision ? Icons.info_outline : Icons.check_circle_outline,
                color: Colors.black,
              ),
              const SizedBox(width: 8),
              Text(
                esPorOmision
                    ? 'VERSIÓN 0 (POR OMISIÓN)'
                    : 'VERSIÓN VIGENTE ${vigente.version}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            esPorOmision
                ? 'El tenant aún no ha configurado reglas propias. Al guardar se creará la versión 1.'
                : 'Configuración personalizada activa para el tenant.',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(bool guardando) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(width: 2, color: Colors.black),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PARÁMETROS OPERATIVOS',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const Divider(thickness: 2, color: Colors.black, height: 24),

          // 1. Criterio de orden
          const Text(
            '1. Criterio para ordenar aliados (RF-13):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('dropdown_criterio_orden'),
            initialValue: _criterioOrden,
            decoration: const InputDecoration(
              border: OutlineInputBorder(borderSide: BorderSide(width: 2)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(
                value: 'CALIFICACION',
                child: Text('Calificación promedio de clientes'),
              ),
              DropdownMenuItem(
                value: 'COBERTURA',
                child: Text('Zonas de cobertura geográfica'),
              ),
            ],
            onChanged: guardando
                ? null
                : (v) => setState(() => _criterioOrden = v ?? 'CALIFICACION'),
          ),
          const SizedBox(height: 20),

          // 2. Tolerancia de tarifa
          Row(
            children: [
              const Expanded(
                child: Text(
                  '2. Tolerancia de tarifa de referencia (RF-16):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${_toleranciaTarifa.round()} %',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          Slider(
            key: const Key('slider_tolerancia'),
            value: _toleranciaTarifa,
            min: 0,
            max: 50,
            divisions: 50,
            activeColor: Colors.black,
            onChanged: guardando
                ? null
                : (v) => setState(() => _toleranciaTarifa = v),
          ),
          const SizedBox(height: 12),

          // 3. Comisión del tenant
          Row(
            children: [
              const Expanded(
                child: Text(
                  '3. Comisión del tenant (RNF-10):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${_comision.round()} %',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          Slider(
            key: const Key('slider_comision'),
            value: _comision,
            min: 0,
            max: 30,
            divisions: 30,
            activeColor: Colors.black,
            onChanged: guardando ? null : (v) => setState(() => _comision = v),
          ),
          const SizedBox(height: 12),

          // 4. Cancelación
          const Text(
            '4. Política de cancelación y penalización (RNF-10):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ManiTextField(
                  key: const Key('input_ventana_cancelacion'),
                  initialValue: _ventanaHoras.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ventana (horas, 0-72)',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(width: 2),
                    ),
                  ),
                  onChanged: (v) {
                    final n = double.tryParse(v);
                    if (n != null) _ventanaHoras = n;
                  },
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n < 0 || n > 72) return '0 a 72 horas';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ManiTextField(
                  key: const Key('input_penalizacion_cancelacion'),
                  initialValue: _penalizacion.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Penalización (%)',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(width: 2),
                    ),
                  ),
                  onChanged: (v) {
                    final n = double.tryParse(v);
                    if (n != null) _penalizacion = n;
                  },
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n < 0 || n > 100) return '0 a 100 %';
                    if (n > 0 && _ventanaHoras == 0) {
                      return 'Requiere ventana > 0';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 5. Oferta
          const Text(
            '5. Tiempo límite para aceptar oferta (RNF-10):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ManiTextField(
            key: const Key('input_minutos_oferta'),
            initialValue: _minutosOferta.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minutos para aceptar (1-1440)',
              border: OutlineInputBorder(borderSide: BorderSide(width: 2)),
            ),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null) _minutosOferta = n;
            },
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 1 || n > 1440) return 'Entre 1 y 1440 min';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialCard(List<ReglaTenantHistorialItem> historial) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(width: 2, color: Colors.black),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'HISTORIAL DE VERSIONES',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              Text(
                '${historial.length} versión(es)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(thickness: 2, color: Colors.black, height: 24),
          if (historial.isEmpty)
            const Text('No hay versiones históricas registradas todavía.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: historial.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = historial[index];
                final esVigente = item.estado == 'VIGENTE';
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: esVigente ? Colors.lightGreen[100] : Colors.white,
                    border: Border.all(width: 1.5, color: Colors.black),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Versión ${item.version} · ${item.estado}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            item.auditoria?['creadaEn'] != null
                                ? item.auditoria!['creadaEn']
                                      .toString()
                                      .substring(0, 10)
                                : '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Criterio: ${item.reglas.criterioOrden} | Tolerancia: ${item.reglas.toleranciaTarifa.round()}% | Comisión: ${item.reglas.comisionPorcentaje.round()}% | Oferta: ${item.reglas.minutosParaAceptarOferta} min',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
