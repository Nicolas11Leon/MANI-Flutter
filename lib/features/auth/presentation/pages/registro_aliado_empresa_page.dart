import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:mani/core/di/injection_container.dart';

/// Pantalla independiente de Registro para Empresas de Servicios (Persona Jurídica).
/// US-02.1.2: Registro de empresa con Cámara de Comercio y datos del representante legal.
class RegistroAliadoEmpresaPage extends StatefulWidget {
  const RegistroAliadoEmpresaPage({super.key});

  @override
  State<RegistroAliadoEmpresaPage> createState() =>
      _RegistroAliadoEmpresaPageState();
}

class _RegistroAliadoEmpresaPageState extends State<RegistroAliadoEmpresaPage> {
  final _formKey = GlobalKey<FormState>();
  final _authRepo = sl<IAuthRepository>();

  // Controladores de Empresa y Representante Legal
  final _razonSocialController = TextEditingController();
  final _nitController = TextEditingController();
  final _nombreRepController = TextEditingController();
  final _docRepController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;

  // Tenant seleccionado
  String _selectedTenantId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
  final Map<String, String> _tenants = const {
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11': 'Plomería Express CDMX SA',
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22': 'Electricistas Pro Monterrey',
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33': 'Cerrajería Total GDL',
  };

  // Categoría de servicio seleccionada
  String _selectedCategoriaId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a18';
  final Map<String, String> _categorias = const {
    'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a18': 'Plomería y Redes Hidráulicas',
    'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a19':
        'Electricidad Residencial e Industrial',
    'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a20': 'Cerrajería y Seguridad',
  };

  // Documentos KYC corporativos adjuntos
  PlatformFile? _camaraComercioFile;
  PlatformFile? _rutEmpresaFile;
  PlatformFile? _cedulaRepFile;

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
        setState(() {
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

  Future<void> _handleRegistro() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

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

    setState(() => _isLoading = true);

    try {
      final documentos = <Map<String, String>>[
        {
          'tipo_documento': 'CAMARA_COMERCIO',
          'ruta_storage':
              'kyc/$_selectedTenantId/camara_${_camaraComercioFile!.name}',
        },
        {
          'tipo_documento': 'RUT_EMPRESA',
          'ruta_storage': 'kyc/$_selectedTenantId/rut_${_rutEmpresaFile!.name}',
        },
        if (_cedulaRepFile != null)
          {
            'tipo_documento': 'CEDULA_REPRESENTANTE',
            'ruta_storage':
                'kyc/$_selectedTenantId/rep_${_cedulaRepFile!.name}',
          },
      ];

      await _authRepo.registrarAliadoEmpresa(
        email: _emailController.text,
        password: _passwordController.text,
        razonSocial: _razonSocialController.text,
        nit: _nitController.text,
        tenantId: _selectedTenantId,
        nombreRepresentante: _nombreRepController.text,
        docRepresentante: _docRepController.text,
        telefonoContacto: _telefonoController.text,
        categoriaId: _selectedCategoriaId,
        documentosKYC: documentos,
      );

      if (!mounted) return;
      _mostrarExitoEmpresaDialog();
    } on AuthException catch (e) {
      if (!mounted) return;
      _showNotification('Error en autenticación: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showNotification('Error en registro: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarExitoEmpresaDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius2xl),
            side: const BorderSide(color: AppTheme.dark, width: 3),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.dark, width: 2),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: AppTheme.dark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '¡Registro Empresarial Enviado!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.dark,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dark,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(color: AppTheme.dark, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📋 Estado: PENDIENTE DE REVISIÓN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.dark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'El Backoffice revisará la Cámara de Comercio y el RUT. Recibirás una notificación en el correo corporativo cuando tu empresa esté habilitada para recibir solicitudes empresariales.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            GestureDetector(
              onTap: () {
                Navigator.of(ctx).pop();
                context.go('/login');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(color: AppTheme.dark, width: 2),
                  boxShadow: const [AppTheme.hardShadowSm],
                ),
                child: Text(
                  'IR AL INICIO DE SESIÓN',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.dark,
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
            color: isError ? Colors.white : AppTheme.dark,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          side: const BorderSide(color: AppTheme.dark, width: 2),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navigation Bar ─────────────────────────────────────────
            _buildTopNavBar(),

            // ── Contenido Principal ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 24,
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
                          const SizedBox(height: 28),

                          // Layout en 2 columnas Web
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isDesktop = constraints.maxWidth >= 850;
                              if (isDesktop) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: _buildLeftColumn(),
                                    ),
                                    const SizedBox(width: 28),
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
                                    const SizedBox(height: 24),
                                    _buildRightColumn(),
                                  ],
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 32),

                          // Barra de acción inferior
                          _buildBottomAction(),
                          const SizedBox(height: 40),
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
  }

  // ── Top Navigation Bar ───────────────────────────────────────────────────────
  Widget _buildTopNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.dark, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.dark, width: 2),
                  boxShadow: const [AppTheme.hardShadowSm],
                ),
                alignment: Alignment.center,
                child: Text(
                  'M',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.dark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MANI Services',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.dark,
                    ),
                  ),
                  Text(
                    'Plataforma Digital de Servicios Multi-tenant',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.arrow_back, color: AppTheme.dark, size: 16),
            label: Text(
              'Iniciar Sesión',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.dark,
                fontWeight: FontWeight.w800,
                fontSize: 13,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        border: Border.all(color: AppTheme.dark, width: 2),
        boxShadow: const [AppTheme.hardShadowMd],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(color: AppTheme.dark, width: 2),
            ),
            child: const Icon(
              Icons.domain_rounded,
              color: AppTheme.dark,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registro de Empresa de Servicios',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.dark,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Registra tu empresa para operar formalmente en la plataforma y recibir solicitudes de mantenimiento corporativo.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
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
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        border: Border.all(color: AppTheme.dark, width: 2),
        boxShadow: const [AppTheme.hardShadowMd],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            Icons.business_rounded,
            '1. Datos de la Empresa y Representante',
          ),
          const SizedBox(height: 20),

          // Selector de Empresa / Tenant Operador
          _buildFieldLabel('OPERADOR / TENANT DE AFILIACIÓN'),
          const SizedBox(height: 6),
          _buildTenantDropdown(),
          const SizedBox(height: 18),

          // Razón Social
          _buildFieldLabel('RAZÓN SOCIAL DE LA EMPRESA'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _razonSocialController,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.dark,
            ),
            decoration: _inputDecoration(
              hint: 'Ej: Redes y Mantenimientos Industriales S.A.S.',
              prefixIcon: Icons.apartment_rounded,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'La razón social es obligatoria'
                : null,
          ),
          const SizedBox(height: 18),

          // NIT
          _buildFieldLabel('NIT DE LA EMPRESA (CON DÍGITO DE VERIFICACIÓN)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nitController,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.dark,
            ),
            decoration: _inputDecoration(
              hint: 'Ej: 900.123.456-7',
              prefixIcon: Icons.pin_outlined,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'El NIT es obligatorio'
                : null,
          ),
          const SizedBox(height: 18),

          // Nombre del Representante Legal
          _buildFieldLabel('NOMBRE DEL REPRESENTANTE LEGAL'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nombreRepController,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.dark,
            ),
            decoration: _inputDecoration(
              hint: 'Ej: Claudia Marcela Restrepo López',
              prefixIcon: Icons.badge_outlined,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'El nombre del representante es obligatorio'
                : null,
          ),
          const SizedBox(height: 18),

          // Documento de Identidad del Representante Legal
          _buildFieldLabel('DOCUMENTO DE IDENTIDAD DEL REPRESENTANTE LEGAL'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _docRepController,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.dark,
            ),
            decoration: _inputDecoration(
              hint: 'Ej: C.C. 52.345.678',
              prefixIcon: Icons.credit_card_outlined,
            ),
          ),
          const SizedBox(height: 18),

          // Teléfono / PBX
          _buildFieldLabel('TELÉFONO O PBX DE CONTACTO'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _telefonoController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.dark,
            ),
            decoration: _inputDecoration(
              hint: '+57 (601) 745 0000 / +57 310 987 6543',
              prefixIcon: Icons.phone_outlined,
            ),
          ),
          const SizedBox(height: 18),

          // Especialidad Técnica Principal
          _buildFieldLabel('ESPECIALIDAD TÉCNICA PRINCIPAL'),
          const SizedBox(height: 6),
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
            borderRadius: BorderRadius.circular(AppTheme.radius2xl),
            border: Border.all(color: AppTheme.dark, width: 2),
            boxShadow: const [AppTheme.hardShadowMd],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardTitle(
                Icons.lock_rounded,
                '2. Credenciales de Acceso Corporativo',
              ),
              const SizedBox(height: 18),

              // Correo
              _buildFieldLabel('CORREO ELECTRÓNICO CORPORATIVO'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.dark,
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
              const SizedBox(height: 16),

              // Contraseña
              _buildFieldLabel('CONTRASEÑA'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: !_showPassword,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.dark,
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
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textSecondary,
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
        const SizedBox(height: 24),

        // Documentos KYC Corporativos
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius2xl),
            border: Border.all(color: AppTheme.dark, width: 2),
            boxShadow: const [AppTheme.hardShadowMd],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardTitle(
                Icons.file_copy_rounded,
                '3. Documentación Corporativa (KYC)',
              ),
              const SizedBox(height: 6),
              Text(
                'El Backoffice valida estos certificados legales para habilitar tu empresa en proyectos corporativos.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 18),

              // Uploader 1: Cámara de Comercio
              _buildWebFileUploader(
                title: 'Certificado de Cámara de Comercio (Obligatorio)',
                subtitle:
                    'Certificado de existencia y representación legal vigente (PDF)',
                file: _camaraComercioFile,
                onTap: () => _pickDocument(docType: 'camara'),
              ),
              const SizedBox(height: 14),

              // Uploader 2: RUT Empresarial
              _buildWebFileUploader(
                title: 'RUT de la Empresa (Obligatorio)',
                subtitle:
                    'RUT actualizado con NIT y actividad económica principal (PDF)',
                file: _rutEmpresaFile,
                onTap: () => _pickDocument(docType: 'rut'),
              ),
              const SizedBox(height: 14),

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
  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        border: Border.all(color: AppTheme.dark, width: 2),
        boxShadow: const [AppTheme.hardShadowMd],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: AppTheme.dark,
                size: 24,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registro con Respaldo Legal Empresarial',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.dark,
                    ),
                  ),
                  Text(
                    'Los certificados quedan resguardados y auditados para contrataciones formales.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(
            width: 350,
            height: 52,
            child: GestureDetector(
              onTap: _isLoading ? null : _handleRegistro,
              child: Container(
                decoration: BoxDecoration(
                  color: _isLoading ? AppTheme.textTertiary : AppTheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(color: AppTheme.dark, width: 2),
                  boxShadow: _isLoading ? [] : const [AppTheme.hardShadowSm],
                ),
                alignment: Alignment.center,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.dark,
                        ),
                      )
                    : Text(
                        'ENVIAR REGISTRO DE EMPRESA A REVISIÓN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: AppTheme.dark,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers de diseño ────────────────────────────────────────────────────────
  Widget _buildCardTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.dark, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppTheme.dark,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppTheme.dark,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTenantDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.dark, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTenantId,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.dark),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.dark,
          ),
          items: _tenants.entries.map((e) {
            return DropdownMenuItem<String>(value: e.key, child: Text(e.value));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedTenantId = val);
          },
        ),
      ),
    );
  }

  Widget _buildCategoriaDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.dark, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategoriaId,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.dark),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.dark,
          ),
          items: _categorias.entries.map((e) {
            return DropdownMenuItem<String>(value: e.key, child: Text(e.value));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedCategoriaId = val);
          },
        ),
      ),
    );
  }

  Widget _buildWebFileUploader({
    required String title,
    required String subtitle,
    required PlatformFile? file,
    required VoidCallback onTap,
  }) {
    final isSelected = file != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(
            color: isSelected ? AppTheme.success : AppTheme.dark,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFDCFCE7) : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: isSelected ? AppTheme.success : AppTheme.dark,
                  width: 1.5,
                ),
              ),
              child: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                color: isSelected ? AppTheme.success : AppTheme.dark,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isSelected
                        ? '${file.name}${file.lengthSync() != null ? " · ${(file.lengthSync()! / 1024).toStringAsFixed(1)} KB" : ""}'
                        : subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.success
                          : AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.success : AppTheme.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.dark, width: 1.5),
              ),
              child: Text(
                isSelected ? 'CAMBIAR' : 'SELECCIONAR',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : AppTheme.dark,
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
        color: AppTheme.textTertiary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: AppTheme.dark, size: 18)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        borderSide: const BorderSide(color: AppTheme.dark, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        borderSide: const BorderSide(color: AppTheme.dark, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        borderSide: const BorderSide(color: AppTheme.dark, width: 2.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        borderSide: const BorderSide(color: AppTheme.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        borderSide: const BorderSide(color: AppTheme.error, width: 2.5),
      ),
    );
  }
}
