import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mani/core/widgets/mani_text_field.dart';
import 'package:mani/core/session/guardas_ruta.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/widgets/mani_mano.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_layout.dart';
import 'package:mani/core/widgets/mani_snackbar.dart';
import 'package:mani/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:mani/features/auth/presentation/widgets/auth_layout.dart';

/// Pantalla de inicio de sesión de MANI.
/// - Escritorio: panel de marca a la izquierda y formulario a la derecha
///   ([AuthSplitScaffold]); móvil: solo el formulario.
/// - Formulario: correo y contraseña con autocompletado, "INGRESAR A MANI",
///   recuperación de contraseña y las cuatro opciones de registro.
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

  void _showNotification(String message, {bool isError = true}) =>
      showManiSnackBar(context, message, esError: isError);

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
        return AuthSplitScaffold(
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLogoHeader(),
                  ManiGap.vXxxl,
                  _buildInputs(),
                  ManiGap.vXl,
                  ManiButton(
                    etiqueta: 'INGRESAR A MANI',
                    onPressed: _handleLogin,
                    cargando: isLoading,
                    expandir: true,
                  ),
                  ManiGap.vXxl,
                  _buildFooterLinks(),
                ],
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
        ManiGap.vLg,
        Semantics(
          header: true,
          child: Text('MANI', style: ManiText.h1.copyWith(letterSpacing: -0.5)),
        ),
        ManiGap.vXs,
        Text(
          'Plataforma Digital de Servicios',
          style: ManiText.body.copyWith(
            fontWeight: FontWeight.w600,
            color: ManiColors.inkMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ManiEtiquetaCampo('CORREO ELECTRÓNICO'),
        ManiTextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          style: ManiText.body.copyWith(fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            hintText: 'hola@mani.app',
            prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'El correo es requerido';
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
              return 'Ingresa un correo válido';
            }
            return null;
          },
        ),
        ManiGap.vLg,
        const ManiEtiquetaCampo('CONTRASEÑA'),
        ManiTextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: (_) => _handleLogin(),
          style: ManiText.body.copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: ManiSpace.xs),
              child: ManiButton(
                variante: ManiButtonVariante.enlace,
                etiqueta: _showPassword ? 'OCULTAR' : 'VER',
                etiquetaAccesible: _showPassword
                    ? 'Ocultar contraseña'
                    : 'Ver contraseña',
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'La contraseña es requerida';
            if (v.length < 6) return 'Mínimo 6 caracteres';
            return null;
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: ManiButton(
            variante: ManiButtonVariante.enlace,
            etiqueta: '¿Olvidaste tu contraseña?',
            onPressed: () => context.go('/forgot-password'),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLinks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ManiSpace.md),
              child: Text(
                '¿NO TIENES CUENTA?',
                style: ManiText.overline.copyWith(color: ManiColors.inkMuted),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        ManiGap.vLg,
        AuthOpcion(
          icono: Icons.home_outlined,
          texto: 'REGISTRARME COMO CLIENTE',
          destacada: true,
          onTap: () => context.go('/register-cliente'),
        ),
        ManiGap.vSm,
        // HU-M02-07
        AuthOpcion(
          icono: Icons.apartment_outlined,
          texto: 'REGISTRAR MI EMPRESA COMO CLIENTE',
          onTap: () => context.go('/register-cliente-empresa'),
        ),
        ManiGap.vSm,
        AuthOpcion(
          icono: Icons.handyman_outlined,
          texto: 'REGISTRARME COMO ALIADO TÉCNICO',
          destacada: true,
          onTap: () => context.go('/register-aliado'),
        ),
        ManiGap.vSm,
        // US-02.1.2
        AuthOpcion(
          icono: Icons.business_outlined,
          texto: 'REGISTRAR MI EMPRESA DE SERVICIOS',
          onTap: () => context.go('/register-empresa'),
        ),
      ],
    );
  }
}
