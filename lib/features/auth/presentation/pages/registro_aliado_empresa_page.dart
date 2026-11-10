import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:mani/core/widgets/mani_pulsable.dart';
import 'package:mani/core/config/tenant_config.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/features/auth/presentation/widgets/auth_layout.dart';
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

  bool _showPassword = false;
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

  void _mostrarExitoEmpresaDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: ManiColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: ManiRadius.brLg,
            side: const BorderSide(color: ManiColors.ink, width: 3),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ManiSpace.sm),
                decoration: BoxDecoration(
                  color: ManiColors.brand,
                  borderRadius: ManiRadius.brSm,
                  border: Border.all(
                    color: ManiColors.border,
                    width: ManiBorder.regular,
                  ),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: ManiColors.ink,
                ),
              ),
              ManiGap.hMd,
              Expanded(
                child: Text(
                  '¡Registro Empresarial Enviado!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ManiFontSize.h3,
                    fontWeight: FontWeight.w900,
                    color: ManiColors.ink,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu solicitud para operar como Empresa Aliada ha sido enviada a validación de Backoffice.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ManiFontSize.body,
                    fontWeight: FontWeight.w600,
                    color: ManiColors.ink,
                  ),
                ),
                ManiGap.vMd,
                Container(
                  padding: const EdgeInsets.all(ManiSpace.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: ManiRadius.brMd,
                    border: Border.all(
                      color: ManiColors.border,
                      width: ManiBorder.thin,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📋 Estado: PENDIENTE DE REVISIÓN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: ManiFontSize.bodySm,
                          fontWeight: FontWeight.w800,
                          color: ManiColors.ink,
                        ),
                      ),
                      ManiGap.vSm,
                      Text(
                        'El Backoffice revisará la Cámara de Comercio y el RUT. Recibirás una notificación en el correo corporativo cuando tu empresa esté habilitada para recibir solicitudes empresariales.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: ManiFontSize.caption,
                          color: ManiColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ManiPulsable(
              onTap: () {
                Navigator.of(ctx).pop();
                context.go('/login');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ManiSpace.xxl,
                  vertical: ManiSpace.md,
                ),
                decoration: BoxDecoration(
                  color: ManiColors.brand,
                  borderRadius: ManiRadius.brMd,
                  border: Border.all(
                    color: ManiColors.border,
                    width: ManiBorder.regular,
                  ),
                  boxShadow: const [ManiShadow.sm],
                ),
                child: Text(
                  'IR AL INICIO DE SESIÓN',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ManiFontSize.bodySm,
                    fontWeight: FontWeight.w900,
                    color: ManiColors.ink,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNotification(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            color: isError ? Colors.white : ManiColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: isError ? ManiColors.danger : ManiColors.brand,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: ManiRadius.brMd,
          side: ManiBorder.side,
        ),
        margin: const EdgeInsets.all(ManiSpace.lg),
      ),
    );
  }

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
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return Scaffold(
          backgroundColor: ManiColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Navigation Bar ─────────────────────────────────────
                _buildTopNavBar(),

                // ── Contenido Principal ──────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: ManiSpace.xxl,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Banner Hero de Empresa
                              _buildHeroBanner(),
                              ManiGap.vXxl,

                              // Layout en 2 columnas Web
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isDesktop = constraints.maxWidth >= 850;
                                  if (isDesktop) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: _buildLeftColumn(),
                                        ),
                                        ManiGap.hXxl,
                                        Expanded(
                                          flex: 5,
                                          child: _buildRightColumn(),
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      children: [
                                        _buildLeftColumn(),
                                        ManiGap.vXxl,
                                        _buildRightColumn(),
                                      ],
                                    );
                                  }
                                },
                              ),
                              ManiGap.vXxl,

                              // Sección obligatoria de Términos y Condiciones (SCRUM-856)
                              TerminosCondicionesSection(
                                aceptaTerminos: _aceptaTerminos,
                                mostrarError: _mostrarErrorTerminos,
                                onChanged: (val) => setState(() {
                                  _aceptaTerminos = val;
                                  if (val) _mostrarErrorTerminos = false;
                                }),
                              ),
                              ManiGap.vXxl,

                              // Barra de acción inferior
                              _buildBottomAction(isLoading),
                              ManiGap.vHuge,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Top Navigation Bar ───────────────────────────────────────────────────────
  Widget _buildTopNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: ManiBorder.side),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.xxxl,
        vertical: ManiSpace.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ManiColors.brand,
                  borderRadius: ManiRadius.brSm,
                  border: Border.all(
                    color: ManiColors.border,
                    width: ManiBorder.regular,
                  ),
                  boxShadow: const [ManiShadow.sm],
                ),
                alignment: Alignment.center,
                child: Text(
                  'M',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ManiFontSize.h3,
                    fontWeight: FontWeight.w900,
                    color: ManiColors.ink,
                  ),
                ),
              ),
              ManiGap.hMd,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MANI Services',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: ManiFontSize.bodyLg,
                      fontWeight: FontWeight.w900,
                      color: ManiColors.ink,
                    ),
                  ),
                  Text(
                    'Plataforma Digital de Servicios Multi-tenant',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: ManiFontSize.micro,
                      fontWeight: FontWeight.w600,
                      color: ManiColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.arrow_back, color: ManiColors.ink, size: 16),
            label: Text(
              'Iniciar Sesión',
              style: GoogleFonts.plusJakartaSans(
                color: ManiColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: ManiFontSize.bodySm,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Banner de Empresa ──────────────────────────────────────────────────
  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.xxl,
        vertical: ManiSpace.lg,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ManiRadius.brLg,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
        boxShadow: const [ManiShadow.md],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(ManiSpace.md),
            decoration: BoxDecoration(
              color: ManiColors.brand,
              borderRadius: ManiRadius.brMd,
              border: Border.all(
                color: ManiColors.border,
                width: ManiBorder.regular,
              ),
            ),
            child: const Icon(
              Icons.domain_rounded,
              color: ManiColors.ink,
              size: 26,
            ),
          ),
          ManiGap.hLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registro de Empresa de Servicios',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ManiFontSize.h3,
                    fontWeight: FontWeight.w900,
                    color: ManiColors.ink,
                    letterSpacing: -0.4,
                  ),
                ),
                ManiGap.vXs,
                Text(
                  'Registra tu empresa para operar formalmente en la plataforma y recibir solicitudes de mantenimiento corporativo.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ManiFontSize.bodySm,
                    color: ManiColors.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Columna Izquierda: Información Legal de la Empresa ─────────────────────
  Widget _buildLeftColumn() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ManiRadius.brLg,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
        boxShadow: const [ManiShadow.md],
      ),
      padding: const EdgeInsets.all(ManiSpace.xxl),
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: ManiFontSize.body,
              fontWeight: FontWeight.w600,
              color: ManiColors.ink,
            ),
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: ManiFontSize.body,
              fontWeight: FontWeight.w600,
              color: ManiColors.ink,
            ),
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: ManiFontSize.body,
              fontWeight: FontWeight.w600,
              color: ManiColors.ink,
            ),
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: ManiFontSize.body,
              fontWeight: FontWeight.w600,
              color: ManiColors.ink,
            ),
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: ManiFontSize.body,
              fontWeight: FontWeight.w600,
              color: ManiColors.ink,
            ),
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
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: ManiRadius.brLg,
            border: Border.all(
              color: ManiColors.border,
              width: ManiBorder.regular,
            ),
            boxShadow: const [ManiShadow.md],
          ),
          padding: const EdgeInsets.all(ManiSpace.xxl),
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
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: ManiFontSize.body,
                  fontWeight: FontWeight.w600,
                  color: ManiColors.ink,
                ),
                decoration: _inputDecoration(
                  hint: 'contacto@empresa.com',
                  prefixIcon: Icons.email_outlined,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El correo corporativo es obligatorio';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                    return 'Ingresa un correo electrónico válido';
                  }
                  return null;
                },
              ),
              ManiGap.vLg,

              // Contraseña
              _buildFieldLabel('CONTRASEÑA'),
              ManiGap.vSm,
              TextFormField(
                controller: _passwordController,
                obscureText: !_showPassword,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: ManiFontSize.body,
                  fontWeight: FontWeight.w600,
                  color: ManiColors.ink,
                ),
                decoration: _inputDecoration(
                  hint: '••••••••',
                  prefixIcon: Icons.key_outlined,
                  suffixIcon: TextButton(
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    child: Text(
                      _showPassword ? 'OCULTAR' : 'VER',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: ManiFontSize.micro,
                        fontWeight: FontWeight.w800,
                        color: ManiColors.inkMuted,
                      ),
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'La contraseña es obligatoria';
                  }
                  if (v.length < 6) {
                    return 'Mínimo 6 caracteres';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        ManiGap.vXxl,

        // Documentos KYC Corporativos
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: ManiRadius.brLg,
            border: Border.all(
              color: ManiColors.border,
              width: ManiBorder.regular,
            ),
            boxShadow: const [ManiShadow.md],
          ),
          padding: const EdgeInsets.all(ManiSpace.xxl),
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
  Widget _buildCardTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: ManiColors.ink, size: 20),
        ManiGap.hSm,
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: ManiFontSize.bodyLg,
            fontWeight: FontWeight.w900,
            color: ManiColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: ManiFontSize.micro,
        fontWeight: FontWeight.w800,
        color: ManiColors.ink,
        letterSpacing: 0.5,
      ),
    );
  }

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
  }) {
    final isSelected = file != null;

    return ManiPulsable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(ManiSpace.md),
        decoration: BoxDecoration(
          color: isSelected
              ? ManiColors.successContainer
              : ManiColors.background,
          borderRadius: ManiRadius.brMd,
          border: Border.all(
            color: isSelected ? ManiColors.success : ManiColors.ink,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(ManiSpace.sm),
              decoration: BoxDecoration(
                color: isSelected ? ManiColors.successContainer : Colors.white,
                borderRadius: ManiRadius.brSm,
                border: Border.all(
                  color: isSelected ? ManiColors.success : ManiColors.ink,
                  width: ManiBorder.thin,
                ),
              ),
              child: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                color: isSelected ? ManiColors.success : ManiColors.ink,
                size: 22,
              ),
            ),
            ManiGap.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: ManiFontSize.bodySm,
                      fontWeight: FontWeight.w800,
                      color: ManiColors.ink,
                    ),
                  ),
                  ManiGap.vXxs,
                  Text(
                    isSelected
                        ? '${file.name}${file.lengthSync() != null ? " · ${(file.lengthSync()! / 1024).toStringAsFixed(1)} KB" : ""}'
                        : subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: ManiFontSize.micro,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? ManiColors.success
                          : ManiColors.inkMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ManiSpace.md,
                vertical: ManiSpace.sm,
              ),
              decoration: BoxDecoration(
                color: isSelected ? ManiColors.success : ManiColors.brand,
                borderRadius: ManiRadius.brSm,
                border: Border.all(
                  color: ManiColors.border,
                  width: ManiBorder.thin,
                ),
              ),
              child: Text(
                isSelected ? 'CAMBIAR' : 'SELECCIONAR',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: ManiFontSize.micro,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : ManiColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: ManiColors.inkSubtle,
        fontSize: ManiFontSize.body,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: ManiColors.ink, size: 18)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.lg,
        vertical: ManiSpace.md,
      ),
      border: OutlineInputBorder(
        borderRadius: ManiRadius.brMd,
        borderSide: ManiBorder.side,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: ManiRadius.brMd,
        borderSide: ManiBorder.side,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: ManiRadius.brMd,
        borderSide: ManiBorder.sideThick,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: ManiRadius.brMd,
        borderSide: const BorderSide(
          color: ManiColors.danger,
          width: ManiBorder.regular,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: ManiRadius.brMd,
        borderSide: const BorderSide(
          color: ManiColors.danger,
          width: ManiBorder.thick,
        ),
      ),
    );
  }
}
