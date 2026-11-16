import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/platform/selector_documento.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/features/profiles/direct_employees/domain/entities/empleado_directo.dart';
import 'package:mani/features/profiles/direct_employees/presentation/bloc/empleado_directo_cubit.dart';
import 'package:mani/features/services/categories/data/datasources/categorias_remote_datasource.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';

/// Pantalla de administración del Tenant para registrar empleados directos
/// que quedan con estado `VERIFICADO` inmediato sin pasar por cola KYC (US-02.1.5 / SCRUM-850 / SCRUM-1376).
/// Datos obligatorios (PO, 26-oct): nombre, tipo y número de documento, correo, teléfono, categorías y la copia del
/// documento de identidad (PDF, JPG o PNG, hasta 5 MB).
class RegistrarEmpleadoDirectoPage extends StatefulWidget {
  const RegistrarEmpleadoDirectoPage({
    super.key,
    this.categoriasDisponibles,
    this.selectorDocumento = const FilePickerSelectorDocumento(),
  });

  /// Selector de la copia del documento; se inyecta en las pruebas.
  final SelectorDocumento selectorDocumento;

  /// Categorías a mostrar (id -> nombre). Si es `null`, se cargan las
  /// categorías activas del catálogo del tenant de la sesión
  /// (`/api/v1/core/catalog/categories`); antes eran UUID fijos de la semilla
  /// de desarrollo, que no existen en QA ni en otros tenants.
  final Map<String, String>? categoriasDisponibles;

  @override
  State<RegistrarEmpleadoDirectoPage> createState() =>
      _RegistrarEmpleadoDirectoPageState();
}

class _RegistrarEmpleadoDirectoPageState
    extends State<RegistrarEmpleadoDirectoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _numeroDocumentoController = TextEditingController();

  String? _tipoDocumento;
  DocumentoIdentidad? _documento;
  String? _errorDocumento;

  final Set<String> _categoriasSeleccionadas = {};
  late Future<Map<String, String>> _categorias = _cargarCategorias();

  Future<Map<String, String>> _cargarCategorias() async {
    final dadas = widget.categoriasDisponibles;
    if (dadas != null) return dadas;
    final lista = await sl<CategoriasRemoteDataSource>().listar();
    return {
      for (final c in lista)
        if (c['active'] != false && c['id'] is String && c['name'] is String)
          c['id'] as String: c['name'] as String,
    };
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _telefonoController.dispose();
    _numeroDocumentoController.dispose();
    super.dispose();
  }

  Future<void> _elegirDocumento() async {
    try {
      final archivo = await widget.selectorDocumento.seleccionar();
      if (archivo == null || !mounted) return;
      final doc = DocumentoIdentidad(
        nombre: archivo.nombre,
        bytes: archivo.bytes,
      );
      setState(() {
        _documento = doc;
        _errorDocumento = _validarDocumento(doc);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorDocumento = 'No pudimos leer el archivo elegido.');
    }
  }

  String? _validarDocumento(DocumentoIdentidad? doc) {
    if (doc == null) return 'Adjunta la copia del documento de identidad';
    if (doc.tipoContenido == null) return 'Debe ser PDF, JPG o PNG';
    if (doc.bytes.isEmpty) return 'El archivo está vacío';
    if (doc.bytes.length > maxBytesDocumentoIdentidad) {
      return 'El archivo no puede superar 5 MB';
    }
    return null;
  }

  void _enviar() {
    final formularioValido = _formKey.currentState?.validate() ?? false;
    final errorDocumento = _validarDocumento(_documento);
    setState(() => _errorDocumento = errorDocumento);
    if (!formularioValido || errorDocumento != null) return;
    context.read<EmpleadoDirectoCubit>().registrar(
      email: _emailController.text,
      password: _passwordController.text,
      nombreCompleto: _nombreController.text,
      telefono: _telefonoController.text,
      tipoDocumento: _tipoDocumento!,
      numeroDocumento: _numeroDocumentoController.text,
      documento: _documento!,
      categoriaIds: _categoriasSeleccionadas.toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: barraDePantalla(context, titulo: 'Registrar empleado directo'),
      body: BlocConsumer<EmpleadoDirectoCubit, EmpleadoDirectoState>(
        listener: (context, state) {
          if (state is EmpleadoDirectoError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                key: const Key('snackbar_error_empleado_directo'),
                backgroundColor: AppTheme.error,
                content: Text(state.message),
              ),
            );
          }
        },
        builder: (context, state) {
          final cargando = state is EmpleadoDirectoLoading;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBannerInfo(),
                      const SizedBox(height: 20),
                      if (state is EmpleadoDirectoRegistrado) ...[
                        _buildConfirmacionCard(state),
                        const SizedBox(height: 20),
                      ],
                      _buildFormularioCard(cargando),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBannerInfo() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        border: Border.all(color: AppTheme.dark, width: 2.5),
        boxShadow: const [AppTheme.hardShadowSm],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: AppTheme.dark,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activación Inmediata (Estado VERIFICADO)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.dark,
                  ),
                ),
                Text(
                  'Los empleados directos creados por el administrador del tenant no pasan por la bandeja de verificación: quedan habilitados de inmediato, con la copia de su documento de identidad como único documento.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmacionCard(EmpleadoDirectoRegistrado state) {
    final emp = state.empleado;
    return Container(
      key: const Key('card_empleado_directo_creado'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        border: Border.all(color: AppTheme.dark, width: 2.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Empleado Directo Registrado: ${emp.nombreCompleto}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppTheme.dark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Estado: ${emp.estadoVerificacion} · Nómina directa: ${emp.esEmpleadoDirecto ? "SÍ" : "NO"}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormularioCard(bool cargando) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        border: Border.all(color: AppTheme.dark, width: 2),
        boxShadow: const [AppTheme.hardShadowMd],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('input_nombre_empleado_directo'),
            controller: _nombreController,
            decoration: const InputDecoration(
              labelText: 'Nombre completo del técnico',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'El nombre es obligatorio'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('input_email_empleado_directo'),
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico corporativo',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'El correo es obligatorio'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('input_password_empleado_directo'),
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña inicial (mín. 8 caracteres)',
            ),
            validator: (v) =>
                (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('input_telefono_empleado_directo'),
            controller: _telefonoController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono de contacto',
            ),
            validator: (v) => (v == null || v.trim().length < 7)
                ? 'El teléfono es obligatorio'
                : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: const Key('input_tipo_documento_empleado_directo'),
            initialValue: _tipoDocumento,
            decoration: const InputDecoration(
              labelText: 'Tipo de documento de identidad',
            ),
            items: const [
              DropdownMenuItem(
                value: 'CC',
                child: Text('Cédula de ciudadanía'),
              ),
              DropdownMenuItem(
                value: 'CE',
                child: Text('Cédula de extranjería'),
              ),
              DropdownMenuItem(value: 'PASSPORT', child: Text('Pasaporte')),
            ],
            onChanged: (v) => setState(() => _tipoDocumento = v),
            validator: (v) =>
                v == null ? 'Selecciona el tipo de documento' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('input_numero_documento_empleado_directo'),
            controller: _numeroDocumentoController,
            decoration: const InputDecoration(labelText: 'Número de documento'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'El número de documento es obligatorio'
                : null,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const Key('btn_adjuntar_documento_empleado_directo'),
            onPressed: _elegirDocumento,
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(
              _documento == null
                  ? 'Adjuntar copia del documento (PDF, JPG o PNG, máx. 5 MB)'
                  : _documento!.nombre,
            ),
          ),
          if (_errorDocumento != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _errorDocumento!,
                key: const Key('error_documento_empleado_directo'),
                style: const TextStyle(color: AppTheme.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Categorías Operativas Asignadas',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppTheme.dark,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, String>>(
            future: _categorias,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(
                    key: Key('categorias_empleado_cargando'),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Row(
                  key: const Key('categorias_empleado_error'),
                  children: [
                    const Expanded(
                      child: Text(
                        'No pudimos cargar las categorías del tenant.',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final nuevo = _cargarCategorias();
                        setState(() {
                          _categorias = nuevo;
                        });
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                );
              }
              final categorias = snapshot.data ?? const <String, String>{};
              if (categorias.isEmpty) {
                return const Text(
                  'El tenant aún no tiene categorías activas.',
                  key: Key('categorias_empleado_vacias'),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...categorias.entries.map((entry) {
                    final seleccionado = _categoriasSeleccionadas.contains(
                      entry.key,
                    );
                    return Material(
                      type: MaterialType.transparency,
                      child: CheckboxListTile(
                        key: Key('chk_categoria_${entry.key}'),
                        value: seleccionado,
                        title: Text(entry.value),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _categoriasSeleccionadas.add(entry.key);
                            } else {
                              _categoriasSeleccionadas.remove(entry.key);
                            }
                          });
                        },
                      ),
                    );
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            key: const Key('btn_registrar_empleado_directo'),
            onPressed: cargando ? null : _enviar,
            child: Text(
              cargando ? 'REGISTRANDO...' : 'CREAR EMPLEADO DIRECTO VERIFICADO',
            ),
          ),
        ],
      ),
    );
  }
}
