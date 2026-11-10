import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/config/tenant_config.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/features/auth/presentation/bloc/recuperacion_contrasena_cubit.dart';
import 'package:mani/features/auth/presentation/validators/credenciales_validators.dart';
import 'package:mani/features/auth/presentation/widgets/recuperacion_layout.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Paso 1 de la recuperación (HU-M02-10): la persona escribe su correo y
/// recibe el enlace. La respuesta es la misma exista o no la cuenta.
class OlvideContrasenaPage extends StatelessWidget {
  const OlvideContrasenaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RecuperacionContrasenaCubit>(),
      child: const OlvideContrasenaView(),
    );
  }
}

class OlvideContrasenaView extends StatefulWidget {
  const OlvideContrasenaView({super.key});

  static const mensajeEnviado =
      'Si el correo está registrado, recibirás un enlace para restablecer tu contraseña. '
      'Revisa también la carpeta de spam.';

  @override
  State<OlvideContrasenaView> createState() => _OlvideContrasenaViewState();
}

class _OlvideContrasenaViewState extends State<OlvideContrasenaView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<RecuperacionContrasenaCubit>().solicitarEnlace(
      email: _emailController.text,
      tenantSlug: tenantSlugRegistro(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<
      RecuperacionContrasenaCubit,
      RecuperacionContrasenaState
    >(
      listener: (context, state) {
        if (state.estado == EstadoRecuperacion.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.mensaje ?? 'No se pudo completar la solicitud.',
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final enviado = state.estado == EstadoRecuperacion.enlaceSolicitado;
        return RecuperacionLayout(
          titulo: '¿Olvidaste tu contraseña?',
          descripcion:
              'Escribe el correo de tu cuenta y te enviaremos un enlace para crear una nueva.',
          child: enviado
              ? const Text(
                  OlvideContrasenaView.mensajeEnviado,
                  key: Key('mensajeEnlaceEnviado'),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const Key('email'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: decoracionRecuperacion(
                          'Correo electrónico',
                          Icons.email_outlined,
                        ),
                        validator: CredencialesValidators.email,
                      ),
                      ManiGap.vXl,
                      BotonRecuperacion(
                        key: const Key('enviarEnlace'),
                        texto: 'ENVIAR ENLACE',
                        cargando: state.estado == EstadoRecuperacion.cargando,
                        onPressed: _enviar,
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
