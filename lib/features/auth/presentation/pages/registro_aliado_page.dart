import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mani/core/config/tenant_config.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/features/auth/presentation/widgets/auth_layout.dart';
import 'package:mani/features/auth/presentation/widgets/registro_comun.dart';
import 'package:mani/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:mani/features/auth/presentation/widgets/selector_categoria_catalogo.dart';
import 'package:mani/features/auth/presentation/widgets/terminos_condiciones_section.dart';
import 'package:mani/features/services/categories/data/datasources/catalogo_publico_datasource.dart';

/// Pantalla independiente de Registro para Aliados Técnicos de MANI Web.
/// - Formulario con selección de especialidad técnica y validación KYC.
/// - Enrutamiento independiente sin navegación cruzada con Cliente.
class RegistroAliadoPage extends StatelessWidget {
  const RegistroAliadoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthCubit>(),
      child: const _RegistroAliadoView(),
    );
  }
}

class _RegistroAliadoView extends StatefulWidget {
  const _RegistroAliadoView();

  @override
  State<_RegistroAliadoView> createState() => _RegistroAliadoViewState();
}

class _RegistroAliadoViewState extends State<_RegistroAliadoView> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _aceptaTerminos = false;
  bool _mostrarErrorTerminos = false;

  // Tenant del despliegue (TENANT_SLUG): el aliado se registra en el
  // operador configurado, igual que el cliente (ADR-0018).
  late final String _tenantSlug = tenantSlugRegistro();

  // Especialidad elegida del catálogo del tenant; null hasta que se elige.
  String? _selectedCategoriaId;

  // Documentos KYC adjuntos
  PlatformFile? _cedulaFile;
  PlatformFile? _rutFile;

  // Contenido de cada documento, leído al seleccionarlo, para que viaje por
  // el Gateway junto con el formulario (US-02.1.1-M3).
  final Map<String, Uint8List> _contenidos = {};

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument({required bool isCedula}) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (result.isNotEmpty) {
        final bytes = await result.first.readAsBytes();
        if (!mounted) return;
        setState(() {
          if (isCedula) {
            _cedulaFile = result.first;
            _contenidos['cedula'] = bytes;
          } else {
            _rutFile = result.first;
            _contenidos['rut'] = bytes;
          }
        });
      }
    } catch (e) {
      _showNotification('Error al seleccionar documento: $e');
    }
  }

  void _handleRegistro() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final categoriaId = _selectedCategoriaId;
    if (categoriaId == null) {
      _showNotification('Selecciona tu especialidad técnica principal.');
      return;
    }

    if (_cedulaFile == null) {
      _showNotification(
        'Debes adjuntar tu Cédula de Ciudadanía para validación.',
      );
      return;
    }

    if (!_aceptaTerminos) {
      setState(() => _mostrarErrorTerminos = true);
      _showNotification(AuthCubit.mensajeTerminosObligatorios);
      return;
    }

    final documentos = <Map<String, String>>[
      _documento('CEDULA_CIUDADANIA', 'cedula', _cedulaFile!),
      if (_rutFile != null) _documento('RUT_CERTIFICADO', 'rut', _rutFile!),
    ];

    context.read<AuthCubit>().registerAliado(
      email: _emailController.text,
      password: _passwordController.text,
      nombreCompleto: _nombreController.text,
      tenantId: _tenantSlug,
      categoriaId: categoriaId,
      documentosKYC: documentos,
      aceptaTerminos: _aceptaTerminos,
    );
  }

  /// La ruta en Storage la decide Core (ADR-0013); aquí solo va el archivo.
  Map<String, String> _documento(
    String tipo,
    String docType,
    PlatformFile archivo,
  ) => {
    'tipo_documento': tipo,
    'nombre_archivo': archivo.name,
    'contenido_base64': base64Encode(_contenidos[docType] ?? const <int>[]),
  };

  void _mostrarExitoAliadoDialog() => mostrarRegistroExitoso(
    context,
    icono: Icons.check_circle_outline,
    titulo: '¡Registro Enviado a Revisión!',
    mensaje: 'Tu solicitud como Aliado Técnico ha sido enviada a validación.',
    tituloDetalle: '📋 Estado: PENDIENTE DE REVISIÓN',
    detalle:
        'El Backoffice validará tu cédula y certificaciones. Te notificaremos en cuanto tu cuenta sea habilitada para prestar servicios.',
  );

  void _showNotification(String message, {bool isError = true}) =>
      mostrarAvisoRegistro(context, message, esError: isError);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthRegistrationSuccess) {
          _mostrarExitoAliadoDialog();
        } else if (state is AuthError) {
          _showNotification(state.message);
        }
      },
      builder: (context, state) => RegistroEstructura(
        formKey: _formKey,
        banner: _buildHeroBanner(),
        izquierda: _buildLeftColumn(),
        derecha: _buildRightColumn(),
        // Sección obligatoria de Términos y Condiciones (SCRUM-856)
        terminos: TerminosCondicionesSection(
          aceptaTerminos: _aceptaTerminos,
          mostrarError: _mostrarErrorTerminos,
          onChanged: (val) => setState(() {
            _aceptaTerminos = val;
            if (val) _mostrarErrorTerminos = false;
          }),
        ),
        accion: _buildBottomAction(state is AuthLoading),
      ),
    );
  }

  // ── Hero Banner de Aliado ───────────────────────────────────────────────────
  Widget _buildHeroBanner() => RegistroBanner(
    icono: Icons.handyman_rounded,
    titulo: 'Registro de Aliado Técnico',
    descripcion:
        'Adjunta tus documentos de identidad para validación de Backoffice y empieza a recibir servicios.',
  );

  // ── Columna Izquierda: Datos del Aliado ──────────────────────────────────────
  Widget _buildLeftColumn() {
    return RegistroTarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(Icons.badge_outlined, '1. Información del Aliado'),
          ManiGap.vXl,

          // Nombre Completo
          _buildFieldLabel('NOMBRE COMPLETO'),
          ManiGap.vSm,
          TextFormField(
            controller: _nombreController,
            style: estiloCampoRegistro,
            decoration: _inputDecoration(
              hint: 'Ej: Carlos Alberto Gómez Mendoza',
              prefixIcon: Icons.person_outline,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'El nombre completo es obligatorio'
                : null,
          ),
          ManiGap.vLg,

          // Tipo de Afiliación
          _buildFieldLabel('TIPO DE AFILIACIÓN'),
          ManiGap.vSm,
          _buildTipoPersonaCard(),
          ManiGap.vLg,

          // Especialidad Técnica
          _buildFieldLabel('ESPECIALIDAD TÉCNICA PRINCIPAL'),
          ManiGap.vSm,
          _buildCategoriaDropdown(),
        ],
      ),
    );
  }

  // ── Columna Derecha: Credenciales y KYC ─────────────────────────────────────
  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tarjeta de Credenciales
        RegistroTarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardTitle(Icons.lock_rounded, '2. Credenciales de Acceso'),
              ManiGap.vLg,

              // Correo
              _buildFieldLabel('CORREO ELECTRÓNICO'),
              ManiGap.vSm,
              RegistroCampoCorreo(
                controller: _emailController,
                hint: 'tecnico@ejemplo.com',
              ),
              ManiGap.vLg,

              // Contraseña
              _buildFieldLabel('CONTRASEÑA'),
              ManiGap.vSm,
              RegistroCampoContrasena(controller: _passwordController),
            ],
          ),
        ),
        ManiGap.vXxl,

        // Documentos KYC
        RegistroTarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardTitle(
                Icons.document_scanner_rounded,
                '3. Documentos de Validación (KYC)',
              ),
              ManiGap.vSm,
              Text(
                'El Backoffice valida estos documentos antes de habilitar tu cuenta para recibir solicitudes.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: ManiFontSize.caption,
                  color: ManiColors.inkMuted,
                ),
              ),
              ManiGap.vLg,
              _buildWebFileUploader(
                title: 'Cédula de Ciudadanía (Obligatorio)',
                subtitle: 'PDF, JPG o PNG de tu documento de identidad',
                file: _cedulaFile,
                onTap: () => _pickDocument(isCedula: true),
              ),
              ManiGap.vMd,
              _buildWebFileUploader(
                title: 'RUT o Certificado Técnico (Recomendado)',
                subtitle:
                    'Acredita tu experiencia técnica para mayor prioridad',
                file: _rutFile,
                onTap: () => _pickDocument(isCedula: false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Botón Inferior ─────────────────────────────────────────────────────────
  Widget _buildBottomAction(bool isLoading) {
    return AuthBarraEnvio(
      titulo: 'Registro con Garantía Multi-tenant',
      descripcion:
          'Tus documentos quedan aislados y protegidos para el tenant seleccionado.',
      etiquetaBoton: 'ENVIAR REGISTRO A REVISIÓN',
      cargando: isLoading,
      onPressed: _handleRegistro,
    );
  }

  // ── Helpers de diseño ────────────────────────────────────────────────────────
  Widget _buildCardTitle(IconData icon, String title) =>
      RegistroTituloTarjeta(icono: icon, titulo: title);

  Widget _buildFieldLabel(String text) => RegistroEtiquetaCampo(text);

  Widget _buildCategoriaDropdown() {
    return SelectorCategoriaCatalogo(
      cargar: () =>
          sl<CatalogoPublicoDataSource>().categoriasActivas(_tenantSlug),
      value: _selectedCategoriaId,
      onChanged: (val) => setState(() => _selectedCategoriaId = val),
    );
  }

  Widget _buildTipoPersonaCard() {
    return Container(
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: ManiColors.background,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(ManiSpace.sm),
            decoration: BoxDecoration(
              color: ManiColors.brand,
              borderRadius: ManiRadius.brSm,
              border: Border.all(
                color: ManiColors.border,
                width: ManiBorder.thin,
              ),
            ),
            child: const Icon(
              Icons.engineering_rounded,
              color: ManiColors.ink,
              size: 20,
            ),
          ),
          ManiGap.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Persona Natural (Técnico Independiente)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ManiFontSize.bodySm,
                    fontWeight: FontWeight.w800,
                    color: ManiColors.ink,
                  ),
                ),
                Text(
                  'Registro individual con validación KYC para prestación directa de servicios.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ManiFontSize.micro,
                    color: ManiColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebFileUploader({
    required String title,
    required String subtitle,
    required PlatformFile? file,
    required VoidCallback onTap,
  }) => RegistroCargadorArchivo(
    titulo: title,
    subtitulo: subtitle,
    archivo: file,
    onTap: onTap,
  );

  InputDecoration _inputDecoration({
    required String hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) => decoracionCampoRegistro(
    hint: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
  );
}
