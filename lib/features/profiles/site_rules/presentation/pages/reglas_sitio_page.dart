import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/features/profiles/site_rules/domain/entities/reglas_sitio.dart';
import 'package:mani/features/profiles/site_rules/presentation/bloc/reglas_sitio_cubit.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

/// Pantalla dual para US-02.2.3 (SCRUM-853):
/// - Como Cliente Corporativo (`esVistaAliado = false`): permite configurar
///   las reglas contextuales de acceso a la sede (EPP, horario, documentos,
///   instrucciones de ingreso).
/// - Como Aliado (`esVistaAliado = true`): muestra de forma destacada las
///   reglas contextuales del sitio antes de iniciar el servicio.
class ReglasSitioPage extends StatefulWidget {
  const ReglasSitioPage({
    super.key,
    required this.siteId,
    this.esVistaAliado = false,
  });

  final String siteId;
  final bool esVistaAliado;

  @override
  State<ReglasSitioPage> createState() => _ReglasSitioPageState();
}

class _ReglasSitioPageState extends State<ReglasSitioPage> {
  final _horarioController = TextEditingController();
  final _instruccionesController = TextEditingController();
  final _documentosController = TextEditingController();
  bool _requiereEpp = false;
  ReglasContextualesSitio? _cargadas;

  @override
  void initState() {
    super.initState();
    context.read<ReglasSitioCubit>().cargarReglas(widget.siteId);
  }

  @override
  void dispose() {
    _horarioController.dispose();
    _instruccionesController.dispose();
    _documentosController.dispose();
    super.dispose();
  }

  void _sincronizarFormulario(ReglasContextualesSitio reglas) {
    _cargadas = reglas;
    _requiereEpp = reglas.requiereEpp;
    _horarioController.text = reglas.horarioPermitido ?? '';
    _instruccionesController.text = reglas.instruccionesIngreso ?? '';
    _documentosController.text = reglas.documentosRequeridos.join(', ');
  }

  void _guardar() {
    final docs = _documentosController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    context.read<ReglasSitioCubit>().guardarReglas(
      ReglasContextualesSitio(
        siteId: widget.siteId,
        horarioPermitido: _horarioController.text,
        // Se conservan los valores que este formulario no edita.
        diasPermitidos:
            _cargadas?.diasPermitidos ?? ReglasContextualesSitio.diasHabiles,
        permisosRequeridos: docs,
        elementosProteccion: _requiereEpp
            ? ((_cargadas?.elementosProteccion.isNotEmpty ?? false)
                  ? _cargadas!.elementosProteccion
                  : const ['Casco', 'Botas de seguridad'])
            : const [],
        instruccionesIngreso: _instruccionesController.text,
        requiereAprobacionPrevia: _cargadas?.requiereAprobacionPrevia ?? false,
        contactoAcceso: _cargadas?.contactoAcceso,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ManiColors.background,

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManiEncabezadoPantalla(
            ancho: ManiAncho.formulario,
            icono: Icons.rule_rounded,
            titulo: widget.esVistaAliado
                ? 'Reglas de ingreso a la sede'
                : 'Configurar reglas contextuales de la sede',
          ),
          Expanded(
            child: BlocConsumer<ReglasSitioCubit, ReglasSitioState>(
              listener: (context, state) {
                if (state.reglas != null && !state.guardadoExitoso) {
                  setState(() => _sincronizarFormulario(state.reglas!));
                }
              },
              builder: (context, state) {
                final reglas = state.reglas;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(ManiSpace.xxl),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: ManiAncho.formulario,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (reglas != null)
                            _buildTarjetaVisibleAliado(reglas),
                          if (!widget.esVistaAliado) ...[
                            ManiGap.vXl,
                            _buildFormularioConfiguracion(state.cargando),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaVisibleAliado(ReglasContextualesSitio reglas) {
    return Container(
      key: const Key('card_reglas_visibles_aliado'),
      padding: const EdgeInsets.all(ManiSpace.xl),
      decoration: BoxDecoration(
        color: ManiColors.brand,
        borderRadius: ManiRadius.brLg,
        border: Border.all(color: ManiColors.border, width: ManiBorder.thick),
        boxShadow: const [ManiShadow.sm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.health_and_safety_rounded,
                color: ManiColors.ink,
                size: 26,
              ),
              ManiGap.hSm,
              Expanded(
                child: Text(
                  'Requisitos de Ingreso al Sitio (${reglas.siteId})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ManiFontSize.body,
                    fontWeight: FontWeight.w900,
                    color: ManiColors.ink,
                  ),
                ),
              ),
            ],
          ),
          ManiGap.vSm,
          Text(
            '• Requiere EPP (Botas / Casco): ${reglas.requiereEpp ? "SÍ" : "NO"}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: ManiFontSize.bodySm,
              fontWeight: FontWeight.w800,
              color: ManiColors.ink,
            ),
          ),
          if (reglas.horarioPermitido != null &&
              reglas.horarioPermitido!.isNotEmpty)
            Text(
              '• Horario permitido: ${reglas.horarioPermitido}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: ManiFontSize.bodySm,
                fontWeight: FontWeight.w700,
                color: ManiColors.ink,
              ),
            ),
          if (reglas.documentosRequeridos.isNotEmpty)
            Text(
              '• Documentos exigidos en portería: ${reglas.documentosRequeridos.join(", ")}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: ManiFontSize.bodySm,
                fontWeight: FontWeight.w700,
                color: ManiColors.ink,
              ),
            ),
          if (reglas.instruccionesIngreso != null &&
              reglas.instruccionesIngreso!.isNotEmpty)
            Text(
              '• Instrucciones: ${reglas.instruccionesIngreso}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: ManiFontSize.bodySm,
                fontWeight: FontWeight.w700,
                color: ManiColors.ink,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormularioConfiguracion(bool cargando) {
    return Container(
      padding: const EdgeInsets.all(ManiSpace.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ManiRadius.brLg,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              key: const Key('switch_requiere_epp'),
              title: const Text(
                'Exigir Elementos de Protección Personal (EPP)',
              ),
              value: _requiereEpp,
              onChanged: (val) => setState(() => _requiereEpp = val),
            ),
          ),
          ManiGap.vMd,
          TextFormField(
            key: const Key('input_horario_reglas_sitio'),
            controller: _horarioController,
            decoration: const InputDecoration(
              labelText:
                  'Horario permitido (ej. Lunes a Viernes 08:00 - 17:00)',
            ),
          ),
          ManiGap.vMd,
          TextFormField(
            key: const Key('input_documentos_reglas_sitio'),
            controller: _documentosController,
            decoration: const InputDecoration(
              labelText:
                  'Documentos requeridos en portería (separados por coma)',
            ),
          ),
          ManiGap.vMd,
          TextFormField(
            key: const Key('input_instrucciones_reglas_sitio'),
            controller: _instruccionesController,
            decoration: const InputDecoration(
              labelText: 'Instrucciones de ingreso para el aliado',
            ),
          ),
          ManiGap.vLg,
          ElevatedButton(
            key: const Key('btn_guardar_reglas_sitio'),
            onPressed: cargando ? null : _guardar,
            child: Text(cargando ? 'GUARDANDO...' : 'GUARDAR REGLAS DEL SITIO'),
          ),
        ],
      ),
    );
  }
}
