import 'package:mani/core/widgets/mani_text_field.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/features/catalog/map/presentation/widgets/mapa_zonas.dart';
import 'package:mani/features/profiles/company_sites/domain/entities/sede_empresa.dart';
import 'package:mani/features/profiles/company_sites/presentation/bloc/sedes_empresa_cubit.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';

/// Pantalla de gestión de múltiples sedes (`sitio`) del cliente empresa de la
/// sesión (US-02.2.2 / SCRUM-852, SCRUM-1387): alta y edición, cada sede con
/// una zona del catálogo de Core (RF-09). Quién puede ver y modificar las
/// sedes lo decide Core con el token; la pantalla no envía ningún id de
/// cliente.
class GestionSedesEmpresaPage extends StatefulWidget {
  const GestionSedesEmpresaPage({super.key, this.conMapa = false});

  /// Dibuja el mapa con la ubicación de las sedes. El cliente mira un mapa por
  /// una sola razón —comprobar sus propias sedes—, así que va aquí y no en una
  /// pantalla de catálogo aparte (HU-M04-07 / SCRUM-1396).
  ///
  /// Exige un `MapaCubit` en el contexto, así que lo activa quien monta la
  /// ruta; por omisión está apagado y la pantalla no depende de ese cubit.
  final bool conMapa;

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
            ManiButton(
              key: const Key('btn_cancelar_edicion'),
              variante: ManiButtonVariante.enlace,
              etiqueta: 'Cancelar',
              onPressed: () => Navigator.of(dialogo).pop(),
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
      appBar: barraDePantalla(context, titulo: 'Mis sedes'),
      body: BlocBuilder<SedesEmpresaCubit, SedesEmpresaState>(
        builder: (context, state) {
          if (state.soloClientesEmpresa) {
            return const _SoloClientesEmpresa();
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                      const SizedBox(height: 16),
                    ],
                    if (state.aviso != null) ...[
                      _Banner(
                        key: const Key('banner_aviso_sedes'),
                        texto: state.aviso!,
                        color: ManiColors.ink,
                      ),
                      const SizedBox(height: 16),
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
                    if (widget.conMapa) ...[
                      const SizedBox(height: 24),
                      _Tarjeta(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Dónde quedan tus sedes',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: ManiColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Comprueba que la dirección que registraste cae donde esperas. '
                              'Las sedes sin ubicación capturada se informan abajo y no se marcan.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            // Alto fijo: la pantalla ya hace scroll, así que el
                            // mapa no puede pedir el espacio disponible.
                            const MapaZonas(key: Key('sedes_mapa'), alto: 320),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Sedes Registradas (${state.sedes.length})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: ManiColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: ManiColors.ink,
              ),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
          ],
          ManiTextField(
            key: const Key('input_nombre_sede'),
            controller: _nombre,
            decoration: const InputDecoration(
              labelText: 'Nombre de la sede (ej. Sede Norte)',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'El nombre de la sede es obligatorio'
                : null,
          ),
          const SizedBox(height: 12),
          ManiTextField(
            key: const Key('input_direccion_sede'),
            controller: _direccion,
            decoration: const InputDecoration(
              labelText: 'Dirección física de la sede',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'La dirección es obligatoria'
                : null,
          ),
          const SizedBox(height: 12),
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
                  ManiTextField(
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
          const SizedBox(height: 12),
          ManiTextField(
            key: const Key('input_contacto_sede'),
            controller: _contactoNombre,
            decoration: const InputDecoration(
              labelText: 'Encargado en sitio (opcional)',
            ),
          ),
          const SizedBox(height: 12),
          ManiTextField(
            key: const Key('input_telefono_sede'),
            controller: _contactoTelefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono del encargado (opcional)',
            ),
          ),
          const SizedBox(height: 16),
          ManiButton(
            key: const Key('btn_guardar_sede'),
            etiqueta: widget.guardando ? 'GUARDANDO...' : widget.textoBoton,
            onPressed: widget.guardando || sinZonas ? null : _guardar,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: ManiColors.ink, width: 2),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ManiRadius.lg),
        border: Border.all(color: color, width: 2),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ManiRadius.lg),
        border: Border.all(color: ManiColors.ink, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.business_rounded, color: ManiColors.ink, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sede.nombre,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ManiColors.ink,
                  ),
                ),
                Text(
                  '${sede.direccion} · Zona: $zona',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
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

/// Explicación para quien entra con una cuenta que no es de cliente empresa: las sedes no le aplican, así que no se
/// muestran los formularios (no podrían funcionar) ni un error genérico.
class _SoloClientesEmpresa extends StatelessWidget {
  const _SoloClientesEmpresa();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _Tarjeta(
            child: Column(
              key: const Key('sedes_solo_empresa'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.apartment_outlined,
                  size: 36,
                  color: ManiColors.ink,
                ),
                const SizedBox(height: 12),
                Text(
                  'Las sedes son para clientes empresa',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: ManiColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu cuenta es de persona natural, así que no necesitas registrar sedes: '
                  'al pedir un servicio indicas la dirección directamente. '
                  'Si representas a una empresa, regístrala como cliente empresa desde la pantalla de inicio de sesión.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
