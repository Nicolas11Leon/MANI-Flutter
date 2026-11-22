import 'package:mani/core/widgets/mani_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mani/core/session/guardas_ruta.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_personaje.dart';
import 'package:mani/core/widgets/mani_trama.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/features/auth/presentation/bloc/auth_cubit.dart';

/// Desde este ancho el login se parte en dos columnas (panel de marca y formulario).
const double _anchoDosColumnas = 840;

/// Pantalla de inicio de sesión de MANI: muñequito, formulario en tarjeta protagonista y enlaces de registro. En
/// pantallas anchas lleva un panel de marca a la izquierda.
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

  /// Último error de credenciales; se muestra dentro de la tarjeta, sobre el botón.
  String? _error;

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

  void _showNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: ManiColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: ManiColors.brand,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ManiRadius.lg),
          side: const BorderSide(color: ManiColors.ink, width: 2),
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
          _showNotification(_bienvenida(widget.rolDeSesion()));
          // US-11.2.3 (SCRUM-1446): enrutamiento RBAC puro según el token.
          context.go(rutaInicio);
        } else if (state is AuthError) {
          setState(() => _error = state.message);
        } else if (state is AuthLoading && _error != null) {
          setState(() => _error = null);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        // Se lee aquí: el Scaffold le quita el teclado al MediaQuery de su cuerpo.
        final tecladoAbierto = MediaQuery.viewInsetsOf(context).bottom > 0;
        return Scaffold(
          backgroundColor: ManiColors.background,
          body: ManiTrama(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, caja) {
                  final dosColumnas = caja.maxWidth >= _anchoDosColumnas;
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: dosColumnas
                          ? ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 960),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Expanded(
                                    flex: 45,
                                    child: _PanelMarca(),
                                  ),
                                  const SizedBox(width: 32),
                                  Expanded(
                                    flex: 55,
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 420,
                                        ),
                                        child: _tarjeta(isLoading),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _Cabecera(tecladoAbierto: tecladoAbierto),
                                  const SizedBox(height: 24),
                                  _tarjeta(isLoading),
                                ],
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tarjeta(bool isLoading) {
    return Form(
      key: _formKey,
      child: ManiCard(
        enfasis: ManiEnfasis.protagonista,
        sombra: ManiShadow.md,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputs(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _FranjaError(texto: _error!),
            ],
            const SizedBox(height: 20),
            ManiButton(
              etiqueta: isLoading ? 'Ingresando…' : 'Ingresar',
              onPressed: isLoading ? null : _handleLogin,
              cargando: isLoading,
              expandir: true,
            ),
            const SizedBox(height: 24),
            _buildFooterLinks(),
          ],
        ),
      ),
    );
  }

  Widget _etiqueta(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: ManiColors.ink,
      ),
    ),
  );

  Widget _buildInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta('Correo electrónico'),
        ManiTextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ManiColors.ink,
          ),
          decoration: const InputDecoration(hintText: 'hola@mani.app'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'El correo es requerido';
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
              return 'Ingresa un correo válido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _etiqueta('Contraseña'),
        ManiTextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: (_) => _handleLogin(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ManiColors.ink,
          ),
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              tooltip: _showPassword
                  ? 'Ocultar contraseña'
                  : 'Mostrar contraseña',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 22,
                color: ManiColors.inkMuted,
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
            etiqueta: '¿Olvidaste tu contraseña?',
            variante: ManiButtonVariante.texto,
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
            const Expanded(
              child: Divider(color: ManiColors.borderSubtle, thickness: 1.5),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '¿Aún no tienes cuenta?',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const Expanded(
              child: Divider(color: ManiColors.borderSubtle, thickness: 1.5),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ManiButton(
                etiqueta: 'Soy cliente',
                icono: Icons.home_outlined,
                variante: ManiButtonVariante.secundario,
                expandir: true,
                onPressed: () => context.go('/register-cliente'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ManiButton(
                etiqueta: 'Soy aliado',
                icono: Icons.handyman_outlined,
                variante: ManiButtonVariante.secundario,
                expandir: true,
                onPressed: () => context.go('/register-aliado'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // HU-M02-07 y US-02.1.2: registros de empresa.
        ManiButton(
          etiqueta: 'Registrar mi empresa como cliente',
          variante: ManiButtonVariante.texto,
          expandir: true,
          onPressed: () => context.go('/register-cliente-empresa'),
        ),
        ManiButton(
          etiqueta: 'Registrar mi empresa de servicios',
          variante: ManiButtonVariante.texto,
          expandir: true,
          onPressed: () => context.go('/register-empresa'),
        ),
      ],
    );
  }
}

/// «MANI» en la fuente de títulos con el subrayado de marcador amarillo detrás.
class _Marca extends StatelessWidget {
  const _Marca();

  static const double tamano = 40;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          height: tamano * 0.2,
          width: tamano * 2.4,
          decoration: BoxDecoration(
            color: ManiColors.brand,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Text(
          'MANI',
          style: AppTheme.titulo(
            size: tamano,
            height: 1.1,
            color: ManiColors.ink,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Cabecera de celular: muñequito con sol, nombre y lema. Con el teclado abierto se reduce para dejar a la vista el
/// campo y el botón.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.tecladoAbierto});

  final bool tecladoAbierto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSize(
          duration: ManiMotion.fast,
          child: ManiPersonaje(
            alto: tecladoAbierto ? 72 : 168,
            conSol: !tecladoAbierto,
          ),
        ),
        SizedBox(height: tecladoAbierto ? 4 : 12),
        const _Marca(),
        const SizedBox(height: 4),
        const Text(
          'Al servicio',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ManiColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// Panel de marca de las pantallas anchas.
class _PanelMarca extends StatelessWidget {
  const _PanelMarca();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: ManiColors.brand,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: ManiColors.ink, width: ManiBorder.thick),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ManiPersonaje(alto: 260, conSol: true),
          const SizedBox(height: 24),
          Text(
            'Tu casa en buenas manos.',
            textAlign: TextAlign.center,
            style: AppTheme.titulo(
              size: 32,
              height: 1.2,
              color: ManiColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error de credenciales dentro de la tarjeta: sin borde y sin tapar el botón como lo hace un SnackBar.
class _FranjaError extends StatelessWidget {
  const _FranjaError({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ManiColors.dangerContainer,
          borderRadius: BorderRadius.circular(ManiRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: ManiColors.dangerText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: ManiColors.dangerText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
