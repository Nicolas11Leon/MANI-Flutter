import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mani/core/widgets/mani_pulsable.dart';
import 'package:mani/core/config/tenant_config.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/features/auth/presentation/widgets/auth_layout.dart';
import 'package:mani/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:mani/features/auth/presentation/widgets/terminos_condiciones_section.dart';

/// Pantalla independiente de Registro para Clientes de MANI Web.
/// - Formulario enfocado y sin fricción para el hogar.
/// - Asignación automática de empresa (sin selector para el cliente).
/// - Enrutamiento independiente sin navegación cruzada con Aliado.
class RegistroClientePage extends StatelessWidget {
  const RegistroClientePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthCubit>(),
      child: const _RegistroClienteView(),
    );
  }
}

class _RegistroClienteView extends StatefulWidget {
  const _RegistroClienteView();

  @override
  State<_RegistroClienteView> createState() => _RegistroClienteViewState();
}

class _RegistroClienteViewState extends State<_RegistroClienteView> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de Cliente
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionHogarController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _aceptaTerminos = false;
  bool _mostrarErrorTerminos = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionHogarController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleRegistro() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_aceptaTerminos) {
      setState(() => _mostrarErrorTerminos = true);
      _showNotification(AuthCubit.mensajeTerminosObligatorios);
      return;
    }

    context.read<AuthCubit>().registerCliente(
      email: _emailController.text,
      password: _passwordController.text,
      nombreCompleto: _nombreController.text,
      // Slug (no UUID) del tenant asignado sin selector: va en X-Tenant-Slug.
      tenantId: tenantSlugRegistro(),
      telefono: _telefonoController.text,
      direccionHogar: _direccionHogarController.text,
      aceptaTerminos: _aceptaTerminos,
    );
  }

  void _mostrarExitoClienteDialog() {
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
                  Icons.home_repair_service_rounded,
                  color: ManiColors.ink,
                ),
              ),
              ManiGap.hMd,
              Expanded(
                child: Text(
                  '¡Cuenta de Cliente Creada!',
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
                  '¡Bienvenido a MANI! Tu cuenta ha sido creada y se encuentra ACTIVA.',
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
                        '🏠 Mantenimientos para tu Hogar:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: ManiFontSize.bodySm,
                          fontWeight: FontWeight.w800,
                          color: ManiColors.ink,
                        ),
                      ),
                      ManiGap.vSm,
                      Text(
                        'Ya puedes iniciar sesión para solicitar servicios de plomería, electricidad y cerrajería con técnicos aliados verificados.',
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
          _mostrarExitoClienteDialog();
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
                              // Banner Hero de Cliente
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
                    'Plataforma Digital de Servicios',
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

  // ── Hero Banner de Cliente ──────────────────────────────────────────────────
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
              Icons.home_repair_service_rounded,
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
                  'Registro de Cliente',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ManiFontSize.h3,
                    fontWeight: FontWeight.w900,
                    color: ManiColors.ink,
                    letterSpacing: -0.4,
                  ),
                ),
                ManiGap.vXs,
                Text(
                  'Crea tu cuenta para solicitar servicios de plomería, electricidad y cerrajería para tu hogar.',
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

  // ── Columna Izquierda: Datos Personales y del Hogar ─────────────────────────
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
          _buildCardTitle(Icons.person_outline, '1. Datos del Cliente y Hogar'),
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

          // Teléfono / WhatsApp
          _buildFieldLabel('TELÉFONO / WHATSAPP DE CONTACTO'),
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
              hint: '+57 300 123 4567',
              prefixIcon: Icons.phone_outlined,
            ),
          ),
          ManiGap.vLg,

          // Dirección del Hogar
          _buildFieldLabel('DIRECCIÓN O BARRIO DE TU HOGAR'),
          ManiGap.vSm,
          TextFormField(
            controller: _direccionHogarController,
            style: GoogleFonts.plusJakartaSans(
              fontSize: ManiFontSize.body,
              fontWeight: FontWeight.w600,
              color: ManiColors.ink,
            ),
            decoration: _inputDecoration(
              hint: 'Ej: Cra 15 # 85-30, Apto 402, Chapinero',
              prefixIcon: Icons.location_on_outlined,
            ),
          ),
        ],
      ),
    );
  }

  // ── Columna Derecha: Credenciales y Beneficios ──────────────────────────────
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
                  hint: 'cliente@ejemplo.com',
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

        // Beneficios para el Cliente
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
                Icons.verified_outlined,
                '3. Beneficios de tu Cuenta',
              ),
              ManiGap.vMd,
              _buildBenefitItem(
                Icons.flash_on_rounded,
                'Activación Inmediata',
                'Tu cuenta queda lista para solicitar servicios de plomería, electricidad y cerrajería.',
              ),
              ManiGap.vMd,
              _buildBenefitItem(
                Icons.shield_outlined,
                'Técnicos Verificados',
                'Todos los aliados que atienden tu hogar pasaron por el proceso de validación KYC.',
              ),
              ManiGap.vMd,
              _buildBenefitItem(
                Icons.price_check_rounded,
                'Cotizaciones Claras',
                'Recibe presupuestos transparentes sin cargos ocultos antes de iniciar el trabajo.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          child: Icon(icon, color: ManiColors.ink, size: 16),
        ),
        ManiGap.hMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: ManiFontSize.caption,
                  fontWeight: FontWeight.w800,
                  color: ManiColors.ink,
                ),
              ),
              Text(
                description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: ManiFontSize.micro,
                  color: ManiColors.inkMuted,
                ),
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
      titulo: 'Garantía de Servicio para Clientes',
      descripcion:
          'Tus datos de hogar quedan protegidos y sólo se comparten al confirmar un servicio.',
      etiquetaBoton: 'CREAR MI CUENTA DE CLIENTE',
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
