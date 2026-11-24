import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mani/core/config/tenant_config.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/features/auth/presentation/widgets/auth_layout.dart';
import 'package:mani/features/auth/presentation/widgets/registro_comun.dart';
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

  void _mostrarExitoClienteDialog() => mostrarRegistroExitoso(
    context,
    icono: Icons.home_repair_service_rounded,
    titulo: '¡Cuenta de Cliente Creada!',
    mensaje:
        '¡Bienvenido a MANI! Tu cuenta ha sido creada y se encuentra ACTIVA.',
    tituloDetalle: '🏠 Mantenimientos para tu Hogar:',
    detalle:
        'Ya puedes iniciar sesión para solicitar servicios de plomería, electricidad y cerrajería con técnicos aliados verificados.',
  );

  void _showNotification(String message, {bool isError = true}) =>
      mostrarAvisoRegistro(context, message, esError: isError);

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
      builder: (context, state) => RegistroEstructura(
        formKey: _formKey,
        banner: _buildHeroBanner(),
        izquierda: _buildLeftColumn(),
        derecha: _buildRightColumn(),
        // Sección obligatoria de Términos y Condiciones (SCRUM-856)
        terminos: TerminosCondicionesSection(
          aceptaTerminos: _aceptaTerminos,
          mostrarError: _mostrarErrorTerminos,
          onChanged: (val) => setState(() {
            _aceptaTerminos = val;
            if (val) _mostrarErrorTerminos = false;
          }),
        ),
        accion: _buildBottomAction(state is AuthLoading),
      ),
    );
  }

  // ── Hero Banner de Cliente ──────────────────────────────────────────────────
  Widget _buildHeroBanner() => RegistroBanner(
    icono: Icons.home_repair_service_rounded,
    titulo: 'Registro de Cliente',
    descripcion:
        'Crea tu cuenta para solicitar servicios de plomería, electricidad y cerrajería para tu hogar.',
  );

  // ── Columna Izquierda: Datos Personales y del Hogar ─────────────────────────
  Widget _buildLeftColumn() {
    return RegistroTarjeta(
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
            style: estiloCampoRegistro,
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
            style: estiloCampoRegistro,
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
            style: estiloCampoRegistro,
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
        RegistroTarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardTitle(Icons.lock_rounded, '2. Credenciales de Acceso'),
              ManiGap.vLg,

              // Correo
              _buildFieldLabel('CORREO ELECTRÓNICO'),
              ManiGap.vSm,
              RegistroCampoCorreo(
                controller: _emailController,
                hint: 'cliente@ejemplo.com',
              ),
              ManiGap.vLg,

              // Contraseña
              _buildFieldLabel('CONTRASEÑA'),
              ManiGap.vSm,
              RegistroCampoContrasena(controller: _passwordController),
            ],
          ),
        ),
        ManiGap.vXxl,

        // Beneficios para el Cliente
        RegistroTarjeta(
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
  Widget _buildCardTitle(IconData icon, String title) =>
      RegistroTituloTarjeta(icono: icon, titulo: title);

  Widget _buildFieldLabel(String text) => RegistroEtiquetaCampo(text);

  InputDecoration _inputDecoration({
    required String hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) => decoracionCampoRegistro(
    hint: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
  );
}
