import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/regla_tenant.dart';
import 'tenant_rules_cubit.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

class ReglasOperativasPage extends StatefulWidget {
  const ReglasOperativasPage({super.key});

  @override
  State<ReglasOperativasPage> createState() => _ReglasOperativasPageState();
}

class _ReglasOperativasPageState extends State<ReglasOperativasPage> {
  final _formKey = GlobalKey<FormState>();

  String _criterioOrden = 'CALIFICACION';
  double _toleranciaTarifa = 10.0;
  double _comision = 15.0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManiEncabezadoPantalla(
            ancho: ManiAncho.formulario,
            icono: Icons.tune_rounded,
            titulo: 'Reglas operativas del tenant',
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ManiAncho.formulario,
                ),
                child: BlocConsumer<TenantRulesCubit, TenantRulesState>(
                  listener: (context, state) {
                    if (state is TenantRulesLoaded) {
                      if (state.mensajeExito != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.mensajeExito!),
                            backgroundColor: ManiColors.success,
                          ),
                        );
                      }
                      if (state.mensajeError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.mensajeError!),
                            backgroundColor: ManiColors.dangerText,
                          ),
                        );
                      }
                    }
                  },
                  builder: (context, state) {
                    if (state is TenantRulesLoading ||
                        state is TenantRulesInitial) {
                      return const ManiCargando();
                    }
                    if (state is TenantRulesError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(ManiSpace.xxl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                state.mensaje,
                                style: const TextStyle(
                                  color: ManiColors.dangerText,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              ManiGap.vLg,
                              ElevatedButton(
                                onPressed: () =>
                                    context.read<TenantRulesCubit>().cargar(),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final loaded = state as TenantRulesLoaded;
                    _sincronizarConVigente(loaded.vigente.reglas);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(ManiSpace.xxl),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Encabezado de estado vigente
                            _buildHeaderCard(loaded.vigente),
                            ManiGap.vXxl,

                            // Formulario de reglas
                            _buildFormCard(loaded.guardando),
                            ManiGap.vXxxl,

                            // Botón guardar
                            ElevatedButton(
                              key: const Key('btn_guardar_reglas'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: ManiSpace.lg,
                                ),
                                backgroundColor: ManiColors.brand,
                                foregroundColor: ManiColors.ink,
                                side: ManiBorder.side,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: ManiRadius.brXs,
                                ),
                              ),
                              onPressed: loaded.guardando
                                  ? null
                                  : () {
                                      if (_formKey.currentState?.validate() ??
                                          false) {
                                        context
                                            .read<TenantRulesCubit>()
                                            .guardar(
                                              ReglasOperativas(
                                                criterioOrden: _criterioOrden,
                                                toleranciaTarifa:
                                                    _toleranciaTarifa,
                                                comisionPorcentaje: _comision,
                                                ventanaCancelacionHoras:
                                                    _ventanaHoras,
                                                penalizacionCancelacion:
                                                    _penalizacion,
                                                minutosParaAceptarOferta:
                                                    _minutosOferta,
                                              ),
                                            );
                                      }
                                    },
                              child: loaded.guardando
                                  ? const CircularProgressIndicator(
                                      color: ManiColors.ink,
                                    )
                                  : const Text(
                                      'GUARDAR NUEVA VERSIÓN',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: ManiFontSize.bodyLg,
                                      ),
                                    ),
                            ),
                            ManiGap.vHuge,

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
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ReglaTenantVigente vigente) {
    final esPorOmision = vigente.origen == 'POR_OMISION';
    return Container(
      padding: const EdgeInsets.all(ManiSpace.lg),
      decoration: BoxDecoration(
        color: esPorOmision ? ManiColors.brandSoft : ManiColors.infoContainer,
        border: Border.all(width: ManiBorder.regular, color: ManiColors.border),
        boxShadow: const [
          BoxShadow(color: ManiColors.ink, offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                esPorOmision ? Icons.info_outline : Icons.check_circle_outline,
                color: ManiColors.ink,
              ),
              ManiGap.hSm,
              Text(
                esPorOmision
                    ? 'VERSIÓN 0 (POR OMISIÓN)'
                    : 'VERSIÓN VIGENTE ${vigente.version}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: ManiFontSize.bodyLg,
                ),
              ),
            ],
          ),
          ManiGap.vSm,
          Text(
            esPorOmision
                ? 'El tenant aún no ha configurado reglas propias. Al guardar se creará la versión 1.'
                : 'Configuración personalizada activa para el tenant.',
            style: const TextStyle(fontSize: ManiFontSize.bodySm),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(bool guardando) {
    return Container(
      padding: const EdgeInsets.all(ManiSpace.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(width: ManiBorder.regular, color: ManiColors.border),
        boxShadow: const [
          BoxShadow(color: ManiColors.ink, offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PARÁMETROS OPERATIVOS',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: ManiFontSize.title,
            ),
          ),
          const Divider(thickness: 2, color: ManiColors.ink, height: 24),

          // 1. Criterio de orden
          const Text(
            '1. Criterio para ordenar aliados (RF-13):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ManiGap.vSm,
          DropdownButtonFormField<String>(
            key: const Key('dropdown_criterio_orden'),
            initialValue: _criterioOrden,
            decoration: const InputDecoration(
              border: OutlineInputBorder(
                borderSide: BorderSide(width: ManiBorder.regular),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: ManiSpace.md,
                vertical: ManiSpace.sm,
              ),
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
          ManiGap.vXl,

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
            activeColor: ManiColors.ink,
            onChanged: guardando
                ? null
                : (v) => setState(() => _toleranciaTarifa = v),
          ),
          ManiGap.vMd,

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
            activeColor: ManiColors.ink,
            onChanged: guardando ? null : (v) => setState(() => _comision = v),
          ),
          ManiGap.vMd,

          // 4. Cancelación
          const Text(
            '4. Política de cancelación y penalización (RNF-10):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ManiGap.vSm,
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('input_ventana_cancelacion'),
                  initialValue: _ventanaHoras.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ventana (horas, 0-72)',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(width: ManiBorder.regular),
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
              ManiGap.hLg,
              Expanded(
                child: TextFormField(
                  key: const Key('input_penalizacion_cancelacion'),
                  initialValue: _penalizacion.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Penalización (%)',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(width: ManiBorder.regular),
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
          ManiGap.vXl,

          // 5. Oferta
          const Text(
            '5. Tiempo límite para aceptar oferta (RNF-10):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ManiGap.vSm,
          TextFormField(
            key: const Key('input_minutos_oferta'),
            initialValue: _minutosOferta.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minutos para aceptar (1-1440)',
              border: OutlineInputBorder(
                borderSide: BorderSide(width: ManiBorder.regular),
              ),
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
      padding: const EdgeInsets.all(ManiSpace.xl),
      decoration: BoxDecoration(
        color: ManiColors.surfaceMuted,
        border: Border.all(width: ManiBorder.regular, color: ManiColors.border),
        boxShadow: const [
          BoxShadow(color: ManiColors.ink, offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'HISTORIAL DE VERSIONES',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: ManiFontSize.bodyLg,
                ),
              ),
              Text(
                '${historial.length} versión(es)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(thickness: 2, color: ManiColors.ink, height: 24),
          if (historial.isEmpty)
            const Text('No hay versiones históricas registradas todavía.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: historial.length,
              separatorBuilder: (_, _) => ManiGap.vMd,
              itemBuilder: (context, index) {
                final item = historial[index];
                final esVigente = item.estado == 'VIGENTE';
                return Container(
                  padding: const EdgeInsets.all(ManiSpace.md),
                  decoration: BoxDecoration(
                    color: esVigente
                        ? ManiColors.successContainer
                        : ManiColors.surface,
                    border: Border.all(
                      width: ManiBorder.thin,
                      color: ManiColors.border,
                    ),
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
                            style: const TextStyle(
                              fontSize: ManiFontSize.caption,
                            ),
                          ),
                        ],
                      ),
                      ManiGap.vSm,
                      Text(
                        'Criterio: ${item.reglas.criterioOrden} | Tolerancia: ${item.reglas.toleranciaTarifa.round()}% | Comisión: ${item.reglas.comisionPorcentaje.round()}% | Oferta: ${item.reglas.minutosParaAceptarOferta} min',
                        style: const TextStyle(fontSize: ManiFontSize.caption),
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
