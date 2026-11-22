import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mani/core/config/tenant_config.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/features/auth/domain/entities/enlace_recuperacion.dart';
import 'package:mani/features/auth/presentation/bloc/recuperacion_contrasena_cubit.dart';
import 'package:mani/features/auth/presentation/validators/credenciales_validators.dart';
import 'package:mani/features/auth/presentation/widgets/recuperacion_layout.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Paso 2 de la recuperación (HU-M02-10): la persona llega desde el enlace del
/// correo y elige su contraseña nueva.
class RestablecerContrasenaPage extends StatelessWidget {
  const RestablecerContrasenaPage({super.key, required this.enlace});

  final EnlaceRecuperacion enlace;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RecuperacionContrasenaCubit>(),
      child: RestablecerContrasenaView(enlace: enlace),
    );
  }
}

class RestablecerContrasenaView extends StatefulWidget {
  const RestablecerContrasenaView({super.key, required this.enlace});

  final EnlaceRecuperacion enlace;

  static const mensajeEnlaceInvalido =
      'El enlace de recuperación no es válido o ya venció. Solicita uno nuevo.';

  @override
  State<RestablecerContrasenaView> createState() =>
      _RestablecerContrasenaViewState();
}

class _RestablecerContrasenaViewState extends State<RestablecerContrasenaView> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmacionController = TextEditingController();
  bool _mostrar = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmacionController.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<RecuperacionContrasenaCubit>().restablecer(
      accessToken: widget.enlace.accessToken!,
      newPassword: _passwordController.text,
      tenantSlug: tenantSlugRegistro(),
    );
  }

  void _mostrarExito() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Contraseña actualizada'),
        content: const Text(
          'Ya puedes iniciar sesión con tu contraseña nueva.',
        ),
        actions: [
          TextButton(
            key: const Key('irAlLogin'),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/login');
            },
            child: const Text('IR AL INICIO DE SESIÓN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enlace.esValido) {
      return RecuperacionLayout(
        titulo: 'Enlace no válido',
        descripcion: RestablecerContrasenaView.mensajeEnlaceInvalido,
        child: BotonRecuperacion(
          key: const Key('solicitarOtroEnlace'),
          texto: 'SOLICITAR OTRO ENLACE',
          cargando: false,
          onPressed: () => context.go('/forgot-password'),
        ),
      );
    }

    return BlocConsumer<
      RecuperacionContrasenaCubit,
      RecuperacionContrasenaState
    >(
      listener: (context, state) {
        if (state.estado == EstadoRecuperacion.restablecida) {
          _mostrarExito();
        } else if (state.estado == EstadoRecuperacion.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.mensaje ?? 'No se pudo actualizar la contraseña.',
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        return RecuperacionLayout(
          titulo: 'Crea tu contraseña nueva',
          descripcion:
              'Elige una contraseña de al menos ${CredencialesValidators.minPassword} caracteres.',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('password'),
                  controller: _passwordController,
                  obscureText: !_mostrar,
                  decoration: decoracionRecuperacion(
                    'Contraseña nueva',
                    Icons.key_outlined,
                  ),
                  validator: CredencialesValidators.password,
                ),
                ManiGap.vLg,
                TextFormField(
                  key: const Key('confirmacion'),
                  controller: _confirmacionController,
                  obscureText: !_mostrar,
                  decoration: decoracionRecuperacion(
                    'Confirmar contraseña',
                    Icons.key_outlined,
                  ),
                  validator: (v) => CredencialesValidators.confirmacion(
                    v,
                    _passwordController.text,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _mostrar = !_mostrar),
                    child: Text(_mostrar ? 'OCULTAR' : 'VER'),
                  ),
                ),
                ManiGap.vSm,
                BotonRecuperacion(
                  key: const Key('guardarContrasena'),
                  texto: 'GUARDAR CONTRASEÑA',
                  cargando: state.estado == EstadoRecuperacion.cargando,
                  onPressed: _guardar,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
