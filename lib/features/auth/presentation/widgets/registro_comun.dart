import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_text_field.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_pulsable.dart';
import 'package:mani/features/auth/presentation/widgets/auth_layout.dart';

/// Piezas compartidas por los registros de cliente, aliado y empresa aliada.
///
/// Cada pantalla pone sus textos, campos y validaciones; aquí vive lo que es
/// igual en las tres (estructura, tarjetas, campos de acceso, avisos y el
/// diálogo de registro exitoso), para que un cambio de diseño se haga una vez.

/// Estilo del texto que el usuario escribe en los campos del registro.
final TextStyle estiloCampoRegistro = GoogleFonts.plusJakartaSans(
  fontSize: ManiFontSize.body,
  fontWeight: FontWeight.w600,
  color: ManiColors.ink,
);

/// Decoración de los campos de texto del registro.
InputDecoration decoracionCampoRegistro({
  required String hint,
  IconData? prefixIcon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder borde(BorderSide lado) =>
      OutlineInputBorder(borderRadius: ManiRadius.brMd, borderSide: lado);
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
    border: borde(ManiBorder.side),
    enabledBorder: borde(ManiBorder.side),
    focusedBorder: borde(ManiBorder.sideThick),
    errorBorder: borde(
      const BorderSide(color: ManiColors.danger, width: ManiBorder.regular),
    ),
    focusedErrorBorder: borde(
      const BorderSide(color: ManiColors.danger, width: ManiBorder.thick),
    ),
  );
}

/// Aviso flotante del registro: rojo para errores, de marca para el resto.
void mostrarAvisoRegistro(
  BuildContext context,
  String mensaje, {
  bool esError = true,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        mensaje,
        style: GoogleFonts.plusJakartaSans(
          color: esError ? Colors.white : ManiColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: esError ? ManiColors.danger : ManiColors.brand,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: ManiRadius.brMd,
        side: ManiBorder.side,
      ),
      margin: const EdgeInsets.all(ManiSpace.lg),
    ),
  );
}

/// Diálogo que confirma el registro y lleva al inicio de sesión.
void mostrarRegistroExitoso(
  BuildContext context, {
  required IconData icono,
  required String titulo,
  required String mensaje,
  required String tituloDetalle,
  required String detalle,
}) {
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
            _IconoMarca(icono: icono, radio: ManiRadius.brSm),
            ManiGap.hMd,
            Expanded(
              child: Text(
                titulo,
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
                mensaje,
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
                      tituloDetalle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: ManiFontSize.bodySm,
                        fontWeight: FontWeight.w800,
                        color: ManiColors.ink,
                      ),
                    ),
                    ManiGap.vSm,
                    Text(
                      detalle,
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

/// Estructura de las pantallas de registro: barra superior, banner, dos
/// columnas en escritorio (una en celular), términos y barra de envío.
class RegistroEstructura extends StatelessWidget {
  const RegistroEstructura({
    super.key,
    required this.formKey,
    required this.banner,
    required this.izquierda,
    required this.derecha,
    required this.terminos,
    required this.accion,
  });

  final GlobalKey<FormState> formKey;
  final Widget banner;
  final Widget izquierda;
  final Widget derecha;
  final Widget terminos;
  final Widget accion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ManiColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const AuthBarraSuperior(),
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
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          banner,
                          ManiGap.vXxl,
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth >= 850) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 5, child: izquierda),
                                    ManiGap.hXxl,
                                    Expanded(flex: 5, child: derecha),
                                  ],
                                );
                              }
                              return Column(
                                children: [izquierda, ManiGap.vXxl, derecha],
                              );
                            },
                          ),
                          ManiGap.vXxl,
                          terminos,
                          ManiGap.vXxl,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // La acción de envío queda fija al pie, fuera de la zona que se desplaza: con 2 o 3 secciones de
            // formulario el botón quedaba bajo el pliegue y no se reconocía la acción principal (SCRUM-1717, QAS-30).
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ManiSpace.paginaAncha,
                ManiSpace.md,
                ManiSpace.paginaAncha,
                ManiSpace.md,
              ),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: ManiAncho.panel),
                  child: accion,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner con el tipo de registro: icono de marca, título y descripción.
class RegistroBanner extends StatelessWidget {
  const RegistroBanner({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;

  @override
  Widget build(BuildContext context) {
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
          _IconoMarca(
            icono: icono,
            radio: ManiRadius.brMd,
            relleno: ManiSpace.md,
            tamano: 26,
          ),
          ManiGap.hLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ManiFontSize.h3,
                    fontWeight: FontWeight.w900,
                    color: ManiColors.ink,
                    letterSpacing: -0.4,
                  ),
                ),
                ManiGap.vXs,
                Text(
                  descripcion,
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
}

/// Tarjeta blanca de una sección del formulario de registro.
class RegistroTarjeta extends StatelessWidget {
  const RegistroTarjeta({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ManiRadius.brLg,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
        boxShadow: const [ManiShadow.md],
      ),
      padding: const EdgeInsets.all(ManiSpace.xxl),
      child: child,
    );
  }
}

/// Título de una tarjeta del registro, con su icono.
class RegistroTituloTarjeta extends StatelessWidget {
  const RegistroTituloTarjeta({
    super.key,
    required this.icono,
    required this.titulo,
  });

  final IconData icono;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, color: ManiColors.ink, size: 20),
        ManiGap.hSm,
        Expanded(
          child: Text(
            titulo,
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
}

/// Etiqueta en mayúsculas sobre un campo del registro.
class RegistroEtiquetaCampo extends StatelessWidget {
  const RegistroEtiquetaCampo(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: GoogleFonts.plusJakartaSans(
        fontSize: ManiFontSize.micro,
        fontWeight: FontWeight.w800,
        color: ManiColors.ink,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Campo de correo del registro, con su validación.
class RegistroCampoCorreo extends StatelessWidget {
  const RegistroCampoCorreo({
    super.key,
    required this.controller,
    required this.hint,
  });

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return ManiTextField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      style: estiloCampoRegistro,
      decoration: decoracionCampoRegistro(
        hint: hint,
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
    );
  }
}

/// Campo de contraseña del registro: mínimo 6 caracteres y botón VER/OCULTAR.
class RegistroCampoContrasena extends StatefulWidget {
  const RegistroCampoContrasena({super.key, required this.controller});

  final TextEditingController controller;

  @override
  State<RegistroCampoContrasena> createState() =>
      _RegistroCampoContrasenaState();
}

class _RegistroCampoContrasenaState extends State<RegistroCampoContrasena> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return ManiTextField(
      controller: widget.controller,
      obscureText: !_visible,
      style: estiloCampoRegistro,
      decoration: decoracionCampoRegistro(
        hint: '••••••••',
        prefixIcon: Icons.key_outlined,
        suffixIcon: ManiButton(
          variante: ManiButtonVariante.enlace,
          etiqueta: _visible ? 'OCULTAR' : 'VER',
          etiquetaAccesible: _visible ? 'Ocultar contraseña' : 'Ver contraseña',
          onPressed: () => setState(() => _visible = !_visible),
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
    );
  }
}

/// Selector de un documento para el registro (cédula, RUT, certificados…).
class RegistroCargadorArchivo extends StatelessWidget {
  const RegistroCargadorArchivo({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.archivo,
    required this.onTap,
  });

  final String titulo;
  final String subtitulo;
  final PlatformFile? archivo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final file = archivo;
    final elegido = file != null;
    final colorEstado = elegido ? ManiColors.success : ManiColors.ink;

    return ManiPulsable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(ManiSpace.md),
        decoration: BoxDecoration(
          color: elegido ? ManiColors.successContainer : ManiColors.background,
          borderRadius: ManiRadius.brMd,
          border: Border.all(color: colorEstado, width: elegido ? 2 : 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(ManiSpace.sm),
              decoration: BoxDecoration(
                color: elegido ? ManiColors.successContainer : Colors.white,
                borderRadius: ManiRadius.brSm,
                border: Border.all(color: colorEstado, width: ManiBorder.thin),
              ),
              child: Icon(
                elegido
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                color: colorEstado,
                size: 22,
              ),
            ),
            ManiGap.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: ManiFontSize.bodySm,
                      fontWeight: FontWeight.w800,
                      color: ManiColors.ink,
                    ),
                  ),
                  ManiGap.vXxs,
                  Text(
                    elegido ? _descripcionArchivo(file) : subtitulo,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: ManiFontSize.micro,
                      fontWeight: elegido ? FontWeight.w700 : FontWeight.w500,
                      color: elegido ? ManiColors.success : ManiColors.inkMuted,
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
                color: elegido ? ManiColors.success : ManiColors.brand,
                borderRadius: ManiRadius.brSm,
                border: Border.all(
                  color: ManiColors.border,
                  width: ManiBorder.thin,
                ),
              ),
              child: Text(
                elegido ? 'CAMBIAR' : 'SELECCIONAR',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: ManiFontSize.micro,
                  fontWeight: FontWeight.w900,
                  color: elegido ? Colors.white : ManiColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _descripcionArchivo(PlatformFile file) {
    final bytes = file.lengthSync();
    if (bytes == null) return file.name;
    return '${file.name} · ${(bytes / 1024).toStringAsFixed(1)} KB';
  }
}

/// Icono sobre un cuadro del color de marca, como en el banner y el diálogo.
class _IconoMarca extends StatelessWidget {
  const _IconoMarca({
    required this.icono,
    required this.radio,
    this.relleno = ManiSpace.sm,
    this.tamano,
  });

  final IconData icono;
  final BorderRadius radio;
  final double relleno;
  final double? tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(relleno),
      decoration: BoxDecoration(
        color: ManiColors.brand,
        borderRadius: radio,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
      ),
      child: Icon(icono, color: ManiColors.ink, size: tamano),
    );
  }
}
