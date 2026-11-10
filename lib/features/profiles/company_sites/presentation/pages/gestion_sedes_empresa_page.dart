import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/features/profiles/company_sites/domain/entities/sede_empresa.dart';
import 'package:mani/features/profiles/company_sites/presentation/bloc/sedes_empresa_cubit.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

/// Pantalla de gestión de múltiples sedes (`sitio`) del cliente empresa de la
/// sesión (US-02.2.2 / SCRUM-852, SCRUM-1387): alta y edición, cada sede con
/// una zona del catálogo de Core (RF-09). Quién puede ver y modificar las
/// sedes lo decide Core con el token; la pantalla no envía ningún id de
/// cliente.
class GestionSedesEmpresaPage extends StatefulWidget {
  const GestionSedesEmpresaPage({super.key});

  @override
  State<GestionSedesEmpresaPage> createState() =>
      _GestionSedesEmpresaPageState();
}

class _GestionSedesEmpresaPageState extends State<GestionSedesEmpresaPage> {
  /// Cambia después de cada alta para vaciar el formulario.
  int _versionFormulario = 0;

  @override
  void initState() {
    super.initState();
    context.read<SedesEmpresaCubit>().cargar();
  }

  Future<void> _agregar(NuevaSedeEmpresa sede) async {
    final cubit = context.read<SedesEmpresaCubit>();
    await cubit.agregar(sede);
    if (mounted && cubit.state.error == null) {
      setState(() => _versionFormulario++);
    }
  }

  Future<void> _editar(SedeEmpresa sede) {
    final cubit = context.read<SedesEmpresaCubit>();
    return showDialog<void>(
      context: context,
      builder: (dialogo) => BlocProvider.value(
        value: cubit,
        child: AlertDialog(
          title: const Text('Editar sede'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: BlocBuilder<SedesEmpresaCubit, SedesEmpresaState>(
                builder: (context, state) => FormularioSede(
                  key: const Key('formulario_editar_sede'),
                  zonas: state.zonasElegibles,
                  nombreZona: state.nombreZona,
                  inicial: sede,
                  error: state.error,
                  guardando: state.cargando,
                  textoBoton: 'GUARDAR CAMBIOS',
                  onGuardar: (datos) async {
                    final guardado = await cubit.editar(sede, datos);
                    if (guardado && dialogo.mounted) {
                      Navigator.of(dialogo).pop();
                    }
                  },
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('btn_cancelar_edicion'),
              onPressed: () => Navigator.of(dialogo).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
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
          ManiBarraPagina(
            icono: Icons.apartment_rounded,
            titulo: 'Mis sedes y sucursales corporativas',
          ),
          Expanded(
            child: BlocBuilder<SedesEmpresaCubit, SedesEmpresaState>(
              builder: (context, state) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(ManiSpace.xxl),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.error != null) ...[
                            _Banner(
                              key: const Key('banner_error_sedes'),
                              texto: state.error!,
                              color: ManiColors.danger,
                            ),
                            ManiGap.vLg,
                          ],
                          if (state.aviso != null) ...[
                            _Banner(
                              key: const Key('banner_aviso_sedes'),
                              texto: state.aviso!,
                              color: ManiColors.ink,
                            ),
                            ManiGap.vLg,
                          ],
                          _Tarjeta(
                            child: FormularioSede(
                              key: ValueKey(
                                'formulario_nueva_sede_$_versionFormulario',
                              ),
                              titulo: 'Registrar Nueva Sede / Sucursal',
                              zonas: state.zonasElegibles,
                              nombreZona: state.nombreZona,
                              guardando: state.cargando,
                              textoBoton: 'AGREGAR SEDE',
                              onGuardar: _agregar,
                            ),
                          ),
                          ManiGap.vXxl,
                          Text(
                            'Sedes Registradas (${state.sedes.length})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: ManiFontSize.bodyLg,
                              fontWeight: FontWeight.w900,
                              color: ManiColors.ink,
                            ),
                          ),
                          ManiGap.vMd,
                          for (final sede in state.sedes)
                            _SedeCard(
                              sede: sede,
                              zona: state.nombreZona(sede.zonaId),
                              onEditar: state.zonas.isEmpty
                                  ? null
                                  : () => _editar(sede),
                            ),
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
}

/// Formulario de una sede, para el alta y para la edición. La zona se busca
/// por nombre entre las zonas elegibles del catálogo; sin una zona elegida no
/// se puede guardar (RF-09).
class FormularioSede extends StatefulWidget {
  const FormularioSede({
    super.key,
    required this.zonas,
    required this.nombreZona,
    required this.onGuardar,
    required this.textoBoton,
    this.titulo,
    this.inicial,
    this.error,
    this.guardando = false,
  });

  final List<ZonaSede> zonas;
  final String Function(String zonaId) nombreZona;
  final Future<void> Function(NuevaSedeEmpresa datos) onGuardar;
  final String textoBoton;
  final String? titulo;
  final SedeEmpresa? inicial;

  /// Error que se muestra dentro del formulario (en el diálogo de edición).
  final String? error;
  final bool guardando;

  @override
  State<FormularioSede> createState() => _FormularioSedeState();
}

class _FormularioSedeState extends State<FormularioSede> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.inicial?.nombre);
  late final _direccion = TextEditingController(
    text: widget.inicial?.direccion,
  );
  late final _contactoNombre = TextEditingController(
    text: widget.inicial?.contactoNombre,
  );
  late final _contactoTelefono = TextEditingController(
    text: widget.inicial?.contactoTelefono,
  );
  late String? _zonaId = widget.inicial?.zonaId;

  @override
  void dispose() {
    _nombre.dispose();
    _direccion.dispose();
    _contactoNombre.dispose();
    _contactoTelefono.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.onGuardar(
      NuevaSedeEmpresa(
        nombre: _nombre.text,
        direccion: _direccion.text,
        zonaId: _zonaId!,
        contactoNombre: _contactoNombre.text,
        contactoTelefono: _contactoTelefono.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sinZonas = widget.zonas.isEmpty;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.titulo != null) ...[
            Text(
              widget.titulo!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: ManiFontSize.body,
                fontWeight: FontWeight.w900,
                color: ManiColors.ink,
              ),
            ),
            ManiGap.vMd,
          ],
          if (widget.error != null) ...[
            Text(
              widget.error!,
              key: const Key('error_formulario_sede'),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: ManiColors.danger,
              ),
            ),
            ManiGap.vMd,
          ],
          TextFormField(
            key: const Key('input_nombre_sede'),
            controller: _nombre,
            decoration: const InputDecoration(
              labelText: 'Nombre de la sede (ej. Sede Norte)',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'El nombre de la sede es obligatorio'
                : null,
          ),
          ManiGap.vMd,
          TextFormField(
            key: const Key('input_direccion_sede'),
            controller: _direccion,
            decoration: const InputDecoration(
              labelText: 'Dirección física de la sede',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'La dirección es obligatoria'
                : null,
          ),
          ManiGap.vMd,
          FormField<String>(
            initialValue: _zonaId,
            validator: (_) =>
                _zonaId == null ? 'Elige la zona de la sede' : null,
            builder: (campo) => Autocomplete<ZonaSede>(
              key: const Key('autocomplete_zona_sede'),
              initialValue: TextEditingValue(
                text: _zonaId == null ? '' : widget.nombreZona(_zonaId!),
              ),
              displayStringForOption: (z) => widget.nombreZona(z.id),
              optionsBuilder: (valor) {
                final buscado = valor.text.trim().toLowerCase();
                return widget.zonas.where(
                  (z) =>
                      widget.nombreZona(z.id).toLowerCase().contains(buscado),
                );
              },
              onSelected: (z) {
                setState(() => _zonaId = z.id);
                campo.didChange(z.id);
              },
              fieldViewBuilder: (context, texto, foco, alEnviar) =>
                  TextFormField(
                    key: const Key('input_zona_sede'),
                    controller: texto,
                    focusNode: foco,
                    enabled: !sinZonas,
                    decoration: InputDecoration(
                      labelText: 'Zona (barrio o localidad)',
                      helperText: sinZonas
                          ? 'No hay zonas disponibles por ahora.'
                          : 'Escribe para buscar en el catálogo.',
                      errorText: campo.errorText,
                    ),
                    onChanged: (_) {
                      // Escribir otra vez invalida la zona elegida hasta que
                      // se elija una opción de la lista.
                      if (_zonaId != null) {
                        setState(() => _zonaId = null);
                        campo.didChange(null);
                      }
                    },
                  ),
            ),
          ),
          ManiGap.vMd,
          TextFormField(
            key: const Key('input_contacto_sede'),
            controller: _contactoNombre,
            decoration: const InputDecoration(
              labelText: 'Encargado en sitio (opcional)',
            ),
          ),
          ManiGap.vMd,
          TextFormField(
            key: const Key('input_telefono_sede'),
            controller: _contactoTelefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono del encargado (opcional)',
            ),
          ),
          ManiGap.vLg,
          ElevatedButton(
            key: const Key('btn_guardar_sede'),
            onPressed: widget.guardando || sinZonas ? null : _guardar,
            child: Text(widget.guardando ? 'GUARDANDO...' : widget.textoBoton),
          ),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ManiSpace.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ManiRadius.brLg,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
        boxShadow: const [ManiShadow.sm],
      ),
      child: child,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: color, width: ManiBorder.regular),
      ),
      child: Text(
        texto,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SedeCard extends StatelessWidget {
  const _SedeCard({required this.sede, required this.zona, this.onEditar});

  final SedeEmpresa sede;
  final String zona;

  /// `null` mientras no haya catálogo de zonas: sin él no se puede editar.
  final VoidCallback? onEditar;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('sede_card_${sede.id}'),
      margin: const EdgeInsets.only(bottom: ManiSpace.md),
      padding: const EdgeInsets.all(ManiSpace.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
      ),
      child: Row(
        children: [
          const Icon(Icons.business_rounded, color: ManiColors.ink, size: 28),
          ManiGap.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sede.nombre,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ManiFontSize.body,
                    fontWeight: FontWeight.w800,
                    color: ManiColors.ink,
                  ),
                ),
                Text(
                  '${sede.direccion} · Zona: $zona',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ManiFontSize.caption,
                    color: ManiColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('btn_editar_sede_${sede.id}'),
            tooltip: 'Editar sede',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEditar,
          ),
        ],
      ),
    );
  }
}
