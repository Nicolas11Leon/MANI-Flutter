import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mani/core/config/tenant_config.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:mani/features/auth/presentation/validators/cliente_empresa_validators.dart';
import 'package:mani/features/auth/presentation/widgets/terminos_condiciones_section.dart';
import 'package:mani/features/auth/domain/entities/registro_cliente_empresa.dart';

/// Registro de cliente empresa (HU-M02-07, RF-08): la empresa que contrata
/// servicios crea su cuenta con NIT y representante legal. Las sedes no se
/// piden aquí: se administran después, con sesión iniciada (M-03).
class RegistroClienteEmpresaPage extends StatelessWidget {
  const RegistroClienteEmpresaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthCubit>(),
      child: const RegistroClienteEmpresaView(),
    );
  }
}

/// Vista del formulario; recibe el [AuthCubit] del contexto (las pruebas
/// inyectan uno propio).
class RegistroClienteEmpresaView extends StatefulWidget {
  const RegistroClienteEmpresaView({super.key});

  @override
  State<RegistroClienteEmpresaView> createState() =>
      _RegistroClienteEmpresaViewState();
}

class _RegistroClienteEmpresaViewState
    extends State<RegistroClienteEmpresaView> {
  final _formKey = GlobalKey<FormState>();
  final _razonSocialController = TextEditingController();
  final _nitController = TextEditingController();
  final _representanteController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _aceptaTerminos = false;
  bool _mostrarErrorTerminos = false;

  @override
  void dispose() {
    _razonSocialController.dispose();
    _nitController.dispose();
    _representanteController.dispose();
    _telefonoController.dispose();
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

    context.read<AuthCubit>().registerClienteEmpresa(
      RegistroClienteEmpresa(
        email: _emailController.text,
        password: _passwordController.text,
        razonSocial: _razonSocialController.text,
        nit: ClienteEmpresaValidators.normalizarNit(_nitController.text),
        nombreRepresentante: _representanteController.text,
        tenantId: tenantSlugRegistro(),
        telefono: _telefonoController.text,
      ),
      aceptaTerminos: _aceptaTerminos,
    );
  }

  void _mostrarExito() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ManiColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: ManiRadius.brLg,
          side: const BorderSide(color: ManiColors.ink, width: 3),
        ),
        title: Text(
          '¡Cuenta de Empresa Creada!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: ManiFontSize.h3,
            fontWeight: FontWeight.w900,
            color: ManiColors.ink,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'Tu empresa ya puede iniciar sesión. Después podrás registrar sus sedes desde tu perfil.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: ManiFontSize.body,
              fontWeight: FontWeight.w600,
              color: ManiColors.ink,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/login');
            },
            child: Text(
              'IR AL INICIO DE SESIÓN',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: ManiColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: ManiColors.danger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(ManiSpace.lg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthRegistrationSuccess) {
          _mostrarExito();
        } else if (state is AuthError) {
          _showNotification(state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return Scaffold(
          backgroundColor: ManiColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: ManiColors.ink,
            title: Text(
              'Registro de Cliente Empresa',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
            ),
            leading: IconButton(
              tooltip: 'Iniciar sesión',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/login'),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: ManiSpace.xxl,
                vertical: ManiSpace.xxl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _seccion(
                          Icons.business_outlined,
                          '1. Datos de la empresa',
                          [
                            _campo(
                              key: const Key('razonSocial'),
                              label: 'RAZÓN SOCIAL',
                              controller: _razonSocialController,
                              hint: 'Ej: Constructora Andina SAS',
                              icon: Icons.apartment_outlined,
                              validator: (v) =>
                                  ClienteEmpresaValidators.obligatorio(
                                    v,
                                    'La razón social es obligatoria',
                                  ),
                            ),
                            _campo(
                              key: const Key('nit'),
                              label: 'NIT',
                              controller: _nitController,
                              hint: '900.123.456-7',
                              icon: Icons.badge_outlined,
                              validator: ClienteEmpresaValidators.nit,
                            ),
                            _campo(
                              key: const Key('nombreRepresentante'),
                              label: 'REPRESENTANTE LEGAL',
                              controller: _representanteController,
                              hint: 'Nombre completo del representante',
                              icon: Icons.person_outline,
                              validator: (v) =>
                                  ClienteEmpresaValidators.obligatorio(
                                    v,
                                    'El representante legal es obligatorio',
                                  ),
                            ),
                            _campo(
                              key: const Key('telefono'),
                              label: 'TELÉFONO DE CONTACTO (OPCIONAL)',
                              controller: _telefonoController,
                              hint: '+57 601 123 4567',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                        ManiGap.vXl,
                        _seccion(
                          Icons.lock_rounded,
                          '2. Credenciales de acceso',
                          [
                            _campo(
                              key: const Key('email'),
                              label: 'CORREO ELECTRÓNICO',
                              controller: _emailController,
                              hint: 'compras@empresa.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: ClienteEmpresaValidators.email,
                            ),
                            _campo(
                              key: const Key('password'),
                              label: 'CONTRASEÑA',
                              controller: _passwordController,
                              hint: '••••••••',
                              icon: Icons.key_outlined,
                              obscure: !_showPassword,
                              validator: ClienteEmpresaValidators.password,
                              suffix: TextButton(
                                onPressed: () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
                                child: Text(_showPassword ? 'OCULTAR' : 'VER'),
                              ),
                            ),
                          ],
                        ),
                        ManiGap.vXl,
                        TerminosCondicionesSection(
                          aceptaTerminos: _aceptaTerminos,
                          mostrarError: _mostrarErrorTerminos,
                          onChanged: (val) => setState(() {
                            _aceptaTerminos = val;
                            if (val) _mostrarErrorTerminos = false;
                          }),
                        ),
                        ManiGap.vXl,
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            key: const Key('crearCuentaEmpresa'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ManiColors.brand,
                              foregroundColor: ManiColors.ink,
                              shape: RoundedRectangleBorder(
                                borderRadius: ManiRadius.brMd,
                                side: ManiBorder.side,
                              ),
                            ),
                            onPressed: isLoading ? null : _handleRegistro,
                            child: isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: ManiColors.ink,
                                    ),
                                  )
                                : Text(
                                    'CREAR LA CUENTA DE MI EMPRESA',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                          ),
                        ),
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

  Widget _seccion(IconData icon, String titulo, List<Widget> campos) {
    return Container(
      padding: const EdgeInsets.all(ManiSpace.xxl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ManiRadius.brLg,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
        boxShadow: const [ManiShadow.md],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: ManiColors.ink, size: 20),
              ManiGap.hSm,
              Text(
                titulo,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: ManiFontSize.bodyLg,
                  fontWeight: FontWeight.w900,
                  color: ManiColors.ink,
                ),
              ),
            ],
          ),
          ManiGap.vLg,
          ...campos,
        ],
      ),
    );
  }

  Widget _campo({
    required Key key,
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ManiSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: ManiFontSize.micro,
              fontWeight: FontWeight.w800,
              color: ManiColors.ink,
              letterSpacing: 0.5,
            ),
          ),
          ManiGap.vSm,
          TextFormField(
            key: key,
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: ManiColors.ink, size: 18),
              suffixIcon: suffix,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: ManiRadius.brMd,
                borderSide: ManiBorder.side,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
