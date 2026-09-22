import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/features/auth/auth_repository.dart';

/// Pantalla independiente de Registro para Clientes de MANI Web.
/// - Formulario enfocado y sin fricción para el hogar.
/// - Asignación automática de empresa (sin selector para el cliente).
/// - Enrutamiento independiente sin navegación cruzada con Aliado.
class RegistroClientePage extends StatefulWidget {
  const RegistroClientePage({super.key});

  @override
  State<RegistroClientePage> createState() => _RegistroClientePageState();
}

class _RegistroClientePageState extends State<RegistroClientePage> {
  final _formKey = GlobalKey<FormState>();
  final _authRepo = AuthRepository();

  // Controladores de Cliente
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionHogarController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;

  // Tenant por defecto para el cliente (asignado internamente sin selector)
  static const String _defaultTenantId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionHogarController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegistro() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      await _authRepo.registrarClientePersonaNatural(
        email: _emailController.text,
        password: _passwordController.text,
        nombreCompleto: _nombreController.text,
        tenantId: _defaultTenantId,
        telefono: _telefonoController.text,
        direccionHogar: _direccionHogarController.text,
      );

      if (!mounted) return;
      _mostrarExitoClienteDialog();
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

  void _mostrarExitoClienteDialog() {
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
                child: const Icon(Icons.home_repair_service_rounded, color: AppTheme.dark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '¡Cuenta de Cliente Creada!',
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
                  '¡Bienvenido a MANI! Tu cuenta ha sido creada y se encuentra ACTIVA.',
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
                        '🏠 Mantenimientos para tu Hogar:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.dark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ya puedes iniciar sesión para solicitar servicios de plomería, electricidad y cerrajería con técnicos aliados verificados.',
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
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
                          const SizedBox(height: 28),

                          // Layout en 2 columnas Web
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isDesktop = constraints.maxWidth >= 850;
                              if (isDesktop) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 5, child: _buildLeftColumn()),
                                    const SizedBox(width: 28),
                                    Expanded(flex: 5, child: _buildRightColumn()),
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
                    'Plataforma Digital de Servicios',
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

  // ── Hero Banner de Cliente ──────────────────────────────────────────────────
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
              Icons.home_repair_service_rounded,
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
                  'Registro de Cliente',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.dark,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Crea tu cuenta para solicitar servicios de plomería, electricidad y cerrajería para tu hogar.',
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

  // ── Columna Izquierda: Datos Personales y del Hogar ─────────────────────────
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
          _buildCardTitle(Icons.person_outline, '1. Datos del Cliente y Hogar'),
          const SizedBox(height: 20),

          // Nombre Completo
          _buildFieldLabel('NOMBRE COMPLETO'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nombreController,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.dark,
            ),
            decoration: _inputDecoration(
              hint: 'Ej: Carlos Alberto Gómez Mendoza',
              prefixIcon: Icons.person_outline,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'El nombre completo es obligatorio'
                : null,
          ),
          const SizedBox(height: 18),

          // Teléfono / WhatsApp
          _buildFieldLabel('TELÉFONO / WHATSAPP DE CONTACTO'),
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
              hint: '+57 300 123 4567',
              prefixIcon: Icons.phone_outlined,
            ),
          ),
          const SizedBox(height: 18),

          // Dirección del Hogar
          _buildFieldLabel('DIRECCIÓN O BARRIO DE TU HOGAR'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _direccionHogarController,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.dark,
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
            borderRadius: BorderRadius.circular(AppTheme.radius2xl),
            border: Border.all(color: AppTheme.dark, width: 2),
            boxShadow: const [AppTheme.hardShadowMd],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardTitle(Icons.lock_rounded, '2. Credenciales de Acceso'),
              const SizedBox(height: 18),

              // Correo
              _buildFieldLabel('CORREO ELECTRÓNICO'),
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
                  hint: 'cliente@ejemplo.com',
                  prefixIcon: Icons.email_outlined,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'El correo es obligatorio';
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
                    onPressed: () => setState(() => _showPassword = !_showPassword),
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
                  if (v == null || v.isEmpty) return 'La contraseña es obligatoria';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Beneficios para el Cliente
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
              _buildCardTitle(Icons.verified_outlined, '3. Beneficios de tu Cuenta'),
              const SizedBox(height: 14),
              _buildBenefitItem(
                Icons.flash_on_rounded,
                'Activación Inmediata',
                'Tu cuenta queda lista para solicitar servicios de plomería, electricidad y cerrajería.',
              ),
              const SizedBox(height: 12),
              _buildBenefitItem(
                Icons.shield_outlined,
                'Técnicos Verificados',
                'Todos los aliados que atienden tu hogar pasaron por el proceso de validación KYC.',
              ),
              const SizedBox(height: 12),
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
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.dark, width: 1.5),
          ),
          child: Icon(icon, color: AppTheme.dark, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.dark,
                ),
              ),
              Text(
                description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
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
              const Icon(Icons.security_rounded, color: AppTheme.dark, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Garantía de Servicio para Clientes',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.dark,
                    ),
                  ),
                  Text(
                    'Tus datos de hogar quedan protegidos y sólo se comparten al confirmar un servicio.',
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
            width: 320,
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
                        'CREAR MI CUENTA DE CLIENTE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
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
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppTheme.dark, size: 18) : null,
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

