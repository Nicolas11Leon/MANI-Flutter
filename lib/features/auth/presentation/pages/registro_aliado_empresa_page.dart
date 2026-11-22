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

/// Pantalla independiente de Registro para Empresas de Servicios (Persona Jurídica).
/// US-02.1.2: Registro de empresa con Cámara de Comercio y datos del representante legal.
class RegistroAliadoEmpresaPage extends StatelessWidget {
  const RegistroAliadoEmpresaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthCubit>(),
      child: const _RegistroAliadoEmpresaView(),
    );
  }
}

class _RegistroAliadoEmpresaView extends StatefulWidget {
  const _RegistroAliadoEmpresaView();

  @override
  State<_RegistroAliadoEmpresaView> createState() =>
      _RegistroAliadoEmpresaViewState();
}

class _RegistroAliadoEmpresaViewState
    extends State<_RegistroAliadoEmpresaView> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de Empresa y Representante Legal
  final _razonSocialController = TextEditingController();
  final _nitController = TextEditingController();
  final _nombreRepController = TextEditingController();
  final _docRepController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _aceptaTerminos = false;
  bool _mostrarErrorTerminos = false;

  // Tenant del despliegue (TENANT_SLUG): el aliado se registra en el
  // operador configurado, igual que el cliente (ADR-0018).
  late final String _tenantSlug = tenantSlugRegistro();

  // Especialidad elegida del catálogo del tenant; null hasta que se elige.
  String? _selectedCategoriaId;

  // Documentos KYC corporativos adjuntos
  PlatformFile? _camaraComercioFile;
  PlatformFile? _rutEmpresaFile;
  PlatformFile? _cedulaRepFile;

  // Contenido de cada documento, leído al seleccionarlo, para que viaje por
  // el Gateway junto con el formulario (US-02.1.2-M3).
  final Map<String, Uint8List> _contenidos = {};

  @override
  void dispose() {
    _razonSocialController.dispose();
    _nitController.dispose();
    _nombreRepController.dispose();
    _docRepController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument({required String docType}) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (result.isNotEmpty) {
        final bytes = await result.first.readAsBytes();
        if (!mounted) return;
        setState(() {
          _contenidos[docType] = bytes;
          if (docType == 'camara') {
            _camaraComercioFile = result.first;
          } else if (docType == 'rut') {
            _rutEmpresaFile = result.first;
          } else if (docType == 'rep') {
            _cedulaRepFile = result.first;
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

    if (_camaraComercioFile == null) {
      _showNotification(
        'Debes adjuntar el Certificado de Cámara de Comercio vigente.',
      );
      return;
    }

    if (_rutEmpresaFile == null) {
      _showNotification('Debes adjuntar el RUT de la empresa con NIT visible.');
      return;
    }

    if (!_aceptaTerminos) {
      setState(() => _mostrarErrorTerminos = true);
      _showNotification(AuthCubit.mensajeTerminosObligatorios);
      return;
    }

    final documentos = <Map<String, String>>[
      _documento('CAMARA_COMERCIO', 'camara', _camaraComercioFile!),
      _documento('RUT_EMPRESA', 'rut', _rutEmpresaFile!),
      if (_cedulaRepFile != null)
        _documento('CEDULA_REPRESENTANTE', 'rep', _cedulaRepFile!),
    ];

    context.read<AuthCubit>().registerEmpresa(
      email: _emailController.text,
      password: _passwordController.text,
      razonSocial: _razonSocialController.text,
      nit: _nitController.text,
      tenantId: _tenantSlug,
      nombreRepresentante: _nombreRepController.text,
      docRepresentante: _docRepController.text,
      telefonoContacto: _telefonoController.text,
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

  void _mostrarExitoEmpresaDialog() => mostrarRegistroExitoso(
    context,
    icono: Icons.apartment_rounded,
    titulo: '¡Registro Empresarial Enviado!',
    mensaje:
        'Tu solicitud para operar como Empresa Aliada ha sido enviada a validación de Backoffice.',
    tituloDetalle: '📋 Estado: PENDIENTE DE REVISIÓN',
    detalle:
        'El Backoffice revisará la Cámara de Comercio y el RUT. Recibirás una notificación en el correo corporativo cuando tu empresa esté habilitada para recibir solicitudes empresariales.',
  );

  void _showNotification(String message, {bool isError = true}) =>
      mostrarAvisoRegistro(context, message, esError: isError);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthRegistrationSuccess) {
          _mostrarExitoEmpresaDialog();
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

  // ── Hero Banner de Empresa ──────────────────────────────────────────────────
  Widget _buildHeroBanner() => RegistroBanner(
    icono: Icons.domain_rounded,
    titulo: 'Registro de Empresa de Servicios',
    descripcion:
        'Registra tu empresa para operar formalmente en la plataforma y recibir solicitudes de mantenimiento corporativo.',
  );

  // ── Columna Izquierda: Información Legal de la Empresa ─────────────────────
  Widget _buildLeftColumn() {
    return RegistroTarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            Icons.business_rounded,
            '1. Datos de la Empresa y Representante',
          ),
          ManiGap.vXl,

          // Razón Social
          _buildFieldLabel('RAZÓN SOCIAL DE LA EMPRESA'),
          ManiGap.vSm,
          TextFormField(
            controller: _razonSocialController,
            style: estiloCampoRegistro,
            decoration: _inputDecoration(
              hint: 'Ej: Redes y Mantenimientos Industriales S.A.S.',
              prefixIcon: Icons.apartment_rounded,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'La razón social es obligatoria'
                : null,
          ),
          ManiGap.vLg,

          // NIT
          _buildFieldLabel('NIT DE LA EMPRESA (CON DÍGITO DE VERIFICACIÓN)'),
          ManiGap.vSm,
          TextFormField(
            controller: _nitController,
            style: estiloCampoRegistro,
            decoration: _inputDecoration(
              hint: 'Ej: 900.123.456-7',
              prefixIcon: Icons.pin_outlined,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'El NIT es obligatorio'
                : null,
          ),
          ManiGap.vLg,

          // Nombre del Representante Legal
          _buildFieldLabel('NOMBRE DEL REPRESENTANTE LEGAL'),
          ManiGap.vSm,
          TextFormField(
            controller: _nombreRepController,
            style: estiloCampoRegistro,
            decoration: _inputDecoration(
              hint: 'Ej: Claudia Marcela Restrepo López',
              prefixIcon: Icons.badge_outlined,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'El nombre del representante es obligatorio'
                : null,
          ),
          ManiGap.vLg,

          // Documento de Identidad del Representante Legal
          _buildFieldLabel('DOCUMENTO DE IDENTIDAD DEL REPRESENTANTE LEGAL'),
          ManiGap.vSm,
          TextFormField(
            controller: _docRepController,
            style: estiloCampoRegistro,
            decoration: _inputDecoration(
              hint: 'Ej: C.C. 52.345.678',
              prefixIcon: Icons.credit_card_outlined,
            ),
          ),
          ManiGap.vLg,

          // Teléfono / PBX
          _buildFieldLabel('TELÉFONO O PBX DE CONTACTO'),
          ManiGap.vSm,
          TextFormField(
            controller: _telefonoController,
            keyboardType: TextInputType.phone,
            style: estiloCampoRegistro,
            decoration: _inputDecoration(
              hint: '+57 (601) 745 0000 / +57 310 987 6543',
              prefixIcon: Icons.phone_outlined,
            ),
          ),
          ManiGap.vLg,

          // Especialidad Técnica Principal
          _buildFieldLabel('ESPECIALIDAD TÉCNICA PRINCIPAL'),
          ManiGap.vSm,
          _buildCategoriaDropdown(),
        ],
      ),
    );
  }

  // ── Columna Derecha: Credenciales y KYC Corporativo ─────────────────────────
  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tarjeta de Credenciales
        RegistroTarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardTitle(
                Icons.lock_rounded,
                '2. Credenciales de Acceso Corporativo',
              ),
              ManiGap.vLg,

              // Correo
              _buildFieldLabel('CORREO ELECTRÓNICO CORPORATIVO'),
              ManiGap.vSm,
              RegistroCampoCorreo(
                controller: _emailController,
                hint: 'contacto@empresa.com',
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

        // Documentos KYC Corporativos
        RegistroTarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardTitle(
                Icons.file_copy_rounded,
                '3. Documentación Corporativa (KYC)',
              ),
              ManiGap.vSm,
              Text(
                'El Backoffice valida estos certificados legales para habilitar tu empresa en proyectos corporativos.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: ManiFontSize.caption,
                  color: ManiColors.inkMuted,
                ),
              ),
              ManiGap.vLg,

              // Uploader 1: Cámara de Comercio
              _buildWebFileUploader(
                title: 'Certificado de Cámara de Comercio (Obligatorio)',
                subtitle:
                    'Certificado de existencia y representación legal vigente (PDF)',
                file: _camaraComercioFile,
                onTap: () => _pickDocument(docType: 'camara'),
              ),
              ManiGap.vMd,

              // Uploader 2: RUT Empresarial
              _buildWebFileUploader(
                title: 'RUT de la Empresa (Obligatorio)',
                subtitle:
                    'RUT actualizado con NIT y actividad económica principal (PDF)',
                file: _rutEmpresaFile,
                onTap: () => _pickDocument(docType: 'rut'),
              ),
              ManiGap.vMd,

              // Uploader 3: Cédula Representante Legal
              _buildWebFileUploader(
                title: 'Cédula del Representante Legal (Recomendado)',
                subtitle:
                    'Documento de identidad legible del representante (PDF/IMG)',
                file: _cedulaRepFile,
                onTap: () => _pickDocument(docType: 'rep'),
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
      titulo: 'Registro con Respaldo Legal Empresarial',
      descripcion:
          'Los certificados quedan resguardados y auditados para contrataciones formales.',
      etiquetaBoton: 'ENVIAR REGISTRO DE EMPRESA A REVISIÓN',
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
