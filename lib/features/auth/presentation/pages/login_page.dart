import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mani/core/session/guardas_ruta.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/widgets/mani_mano.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/features/auth/presentation/bloc/auth_cubit.dart';

/// Pantalla de inicio de sesión de MANI.
/// Replicada con diseño limpio y robusto (RBAC Puro):
/// - Fondo crema: #FDFBF7
/// - Logo amarillo con M gruesa y hard-shadow
/// - Título MANI con tracking tight
/// - Inputs con bordes negros 2px, fondo blanco y placeholder gris
/// - Botón "INGRESAR A MANI" amarillo con sombra dura de 4px
/// - Enlaces inferiores: "¿Olvidaste tu contraseña?" • Registros independientes
///
/// HU-M02-01 / RF-03: Autenticación por RBAC (Role-Based Access Control).
/// El usuario ingresa credenciales directas (correo y contraseña); el rol y
/// el tenant son derivados criptográficamente desde los claims verificados del
/// token JWT ES256 (T4), garantizando aislamiento y enrutamiento seguro.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.rolDeSesion = rolDeSesionActual});

  /// Rol de la sesión recién abierta, leído del access token. Se inyecta para
  /// probar la pantalla sin Supabase.
  final RolUsuario Function() rolDeSesion;

  /// Lee el rol del access token de la sesión abierta (no de la pestaña).
  static RolUsuario rolDeSesionActual() => rolDesdeAccessToken(
    Supabase.instance.client.auth.currentSession?.accessToken,
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthCubit>(),
      child: _LoginView(rolDeSesion: rolDeSesion),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView({required this.rolDeSesion});

  final RolUsuario Function() rolDeSesion;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthCubit>().login(
      _emailController.text,
      _passwordController.text,
    );
  }

  /// Saludo tras iniciar sesión (RBAC).
  String _bienvenida(RolUsuario rolDelToken) => '¡Bienvenido a MANI!';

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
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          _showNotification(_bienvenida(widget.rolDeSesion()), isError: false);
          // US-11.2.3 (SCRUM-1446): enrutamiento RBAC puro según el token.
          context.go(rutaInicio);
        } else if (state is AuthError) {
          _showNotification(state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Header (Logo + Títulos) ───────────────────────
                        _buildLogoHeader(),
                        const SizedBox(height: 28),

                        // ── Inputs (Email y Contraseña) ───────────────────
                        _buildInputs(),
                        const SizedBox(height: 24),

                        // ── Botón INGRESAR A MANI ──────────────────────────
                        _buildSubmitButton(isLoading),
                        const SizedBox(height: 20),

                        // ── Enlaces inferiores ─────────────────────────────
                        _buildFooterLinks(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoHeader() {
    return Column(
      children: [
        // El muñequito de MANI, grande y sin círculo ni letras; el nombre va en el título de abajo.
        const ManiMano(alto: 140),
        const SizedBox(height: 12),
        Text(
          'MANI',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: AppTheme.dark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Plataforma Digital de Servicios',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Correo electrónico
        Text(
          'CORREO ELECTRÓNICO',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.dark,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.dark,
          ),
          decoration: InputDecoration(
            hintText: 'hola@mani.app',
            hintStyle: GoogleFonts.plusJakartaSans(
              color: AppTheme.textTertiary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'El correo es requerido';
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
              return 'Ingresa un correo válido';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        // Contraseña
        Text(
          'CONTRASEÑA',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.dark,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _passwordController,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleLogin(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.dark,
          ),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: GoogleFonts.plusJakartaSans(
              color: AppTheme.textTertiary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: TextButton(
              onPressed: () => setState(() => _showPassword = !_showPassword),
              child: Text(
                _showPassword ? 'OCULTAR' : 'VER',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
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
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'La contraseña es requerida';
            if (v.length < 6) return 'Mínimo 6 caracteres';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : _handleLogin,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: isLoading ? AppTheme.textTertiary : AppTheme.primary,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppTheme.dark, width: 2),
          boxShadow: isLoading ? [] : const [AppTheme.hardShadowMd],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.dark,
                ),
              )
            : Text(
                'INGRESAR A MANI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: AppTheme.dark,
                ),
              ),
      ),
    );
  }

  Widget _buildFooterLinks() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => context.go('/forgot-password'),
          child: Text(
            '¿Olvidaste tu contraseña?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Divisor "¿NO TIENES CUENTA?"
        Row(
          children: [
            const Expanded(
              child: Divider(color: AppTheme.dark, thickness: 1.5),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '¿NO TIENES CUENTA?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const Expanded(
              child: Divider(color: AppTheme.dark, thickness: 1.5),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Botón 1: Registrarme como Cliente
        GestureDetector(
          onTap: () => context.go('/register-cliente'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(color: AppTheme.dark, width: 2),
              boxShadow: const [AppTheme.hardShadowSm],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.home_outlined, color: AppTheme.dark, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'REGISTRARME COMO CLIENTE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: AppTheme.dark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Botón 1b: Registrar mi empresa como cliente (HU-M02-07)
        _botonRegistroSecundario(
          icono: Icons.apartment_outlined,
          texto: 'REGISTRAR MI EMPRESA COMO CLIENTE',
          ruta: '/register-cliente-empresa',
        ),
        const SizedBox(height: 10),

        // Botón 2: Registrarme como Aliado Técnico
        GestureDetector(
          onTap: () => context.go('/register-aliado'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(color: AppTheme.dark, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.handyman_outlined,
                  color: AppTheme.dark,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'REGISTRARME COMO ALIADO TÉCNICO',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: AppTheme.dark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Botón 3: Registrar Empresa de Servicios (US-02.1.2)
        _botonRegistroSecundario(
          icono: Icons.business_outlined,
          texto: 'REGISTRAR MI EMPRESA DE SERVICIOS',
          ruta: '/register-empresa',
        ),
      ],
    );
  }

  /// Botón de registro sin resaltar (empresa cliente y empresa de servicios).
  Widget _botonRegistroSecundario({
    required IconData icono,
    required String texto,
    required String ruta,
  }) {
    return GestureDetector(
      onTap: () => context.go(ruta),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppTheme.dark, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: AppTheme.dark, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                texto,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: AppTheme.dark,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
