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

  bool _showPassword = false;
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

  void _mostrarExitoAliadoDialog() {
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
                  Icons.check_circle_outline,
                  color: ManiColors.ink,
                ),
              ),
              ManiGap.hMd,
              Expanded(
                child: Text(
                  '¡Registro Enviado a Revisión!',
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
            constraints: const BoxConstraints(maxWidth: ManiAncho.estrecho),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu solicitud como Aliado Técnico ha sido enviada a validación.',
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
                        'El Backoffice validará tu cédula y certificaciones. Te notificaremos en cuanto tu cuenta sea habilitada para prestar servicios.',
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
          _mostrarExitoAliadoDialog();
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
                        constraints: const BoxConstraints(
                          maxWidth: ManiAncho.panel,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Banner Hero de Aliado
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
  Widget _buildTopNavBar() => const AuthBarraSuperior();

  // ── Hero Banner de Aliado ───────────────────────────────────────────────────
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
              Icons.handyman_rounded,
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
                  'Registro de Aliado Técnico',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ManiFontSize.h3,
                    fontWeight: FontWeight.w900,
                    color: ManiColors.ink,
                    letterSpacing: -0.4,
                  ),
                ),
                ManiGap.vXs,
                Text(
                  'Adjunta tus documentos de identidad para validación de Backoffice y empieza a recibir servicios.',
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

  // ── Columna Izquierda: Datos del Aliado ──────────────────────────────────────
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
          _buildCardTitle(Icons.badge_outlined, '1. Información del Aliado'),
          ManiGap.vXl,

          // Nombre Completo
          _buildFieldLabel('NOMBRE COMPLETO'),
          ManiGap.vSm,
          TextFormField(
            controller: _nombreController,
            style: GoogleFonts.plusJakartaSans(
              fontSize: ManiFontSize.body,
              fontWeight: FontWeight.w600,
              color: ManiColors.ink,
            ),
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
              _buildCardTitle(Icons.lock_rounded, '2. Credenciales de Acceso'),
              ManiGap.vLg,

              // Correo
              _buildFieldLabel('CORREO ELECTRÓNICO'),
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
                  hint: 'tecnico@ejemplo.com',
                  prefixIcon: Icons.email_outlined,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El correo es obligatorio';
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

        // Documentos KYC
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
  Widget _buildCardTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: ManiColors.ink, size: 20),
        ManiGap.hSm,
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: ManiFontSize.bodyLg,
              fontWeight: FontWeight.w900,
              color: ManiColors.ink,
            ),
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
