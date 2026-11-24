import 'package:mani/core/widgets/mani_text_field.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_layout.dart';
import 'package:mani/core/widgets/mani_pagina.dart';
import 'package:mani/features/profiles/own_profile/data/datasources/perfil_propio_remote_datasource.dart';
import 'package:mani/features/profiles/own_profile/domain/entities/perfil_propio.dart';
import 'package:mani/features/profiles/own_profile/presentation/widgets/foto_perfil_selector_widget.dart';
import 'package:mani/core/widgets/mani_pagina.dart' show ManiEncabezadoPantalla;

/// US-02.3.1 (SCRUM-854 / SCRUM-1029 / SCRUM-1030):
/// Formulario donde el usuario (Cliente o Aliado) ve sus datos actuales y puede
/// modificar su nombre, teléfono, dirección y foto de perfil, manteniendo rol y
/// estado como atributos protegidos de solo lectura.
class EditarPerfilPage extends StatefulWidget {
  const EditarPerfilPage({
    super.key,
    required this.dataSource,
    this.selectorImagen,
  });

  final PerfilPropioRemoteDataSource dataSource;
  final SelectorArchivoImagen? selectorImagen;

  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  static final _phoneRegex = RegExp(r'^\+?[0-9\s()-]{7,20}$');

  PerfilPropio? _perfil;
  bool _cargando = true;
  bool _guardando = false;
  bool _subiendoFoto = false;
  String? _mensajeError;
  String? _mensajeExito;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    setState(() {
      _cargando = true;
      _mensajeError = null;
    });
    try {
      final perfil = await widget.dataSource.obtenerPerfilPropio();
      _aplicarPerfilEnFormulario(perfil);
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensajeError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  void _aplicarPerfilEnFormulario(PerfilPropio perfil) {
    _perfil = perfil;
    _nombreController.text = perfil.fullName;
    _telefonoController.text = perfil.phone ?? '';
    _direccionController.text = perfil.address ?? '';
  }

  Future<void> _subirFoto(String nombreArchivo, Uint8List bytes) async {
    setState(() {
      _subiendoFoto = true;
      _mensajeError = null;
      _mensajeExito = null;
    });
    try {
      final actualizado = await widget.dataSource.subirFotoPerfil(
        nombreArchivo: nombreArchivo,
        bytes: bytes,
      );
      if (mounted) {
        setState(() {
          _perfil = actualizado;
          _mensajeExito = 'Foto de perfil actualizada correctamente';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensajeError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _subiendoFoto = false;
        });
      }
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _mensajeError = null;
      _mensajeExito = null;
    });
    try {
      final actualizado = await widget.dataSource.actualizarPerfilPropio(
        fullName: _nombreController.text,
        phone: _telefonoController.text,
        address: _direccionController.text,
      );
      if (mounted) {
        setState(() {
          _aplicarPerfilEnFormulario(actualizado);
          _mensajeExito = 'Perfil actualizado exitosamente';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensajeError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ManiEncabezadoPantalla(
            ancho: ManiAncho.panel,
            icono: Icons.manage_accounts_outlined,
            titulo: 'Editar mi perfil',
            descripcion:
                'Actualiza tus datos de contacto y tu foto. El rol y el estado de la cuenta no se pueden cambiar.',
          ),
          Expanded(
            child: _cargando
                ? const ManiCargando()
                : LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      padding: ManiContenido.margenes(c.maxWidth),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_mensajeError != null)
                              _Aviso(
                                texto: _mensajeError!,
                                textoKey: const Key('banner-error-perfil'),
                                error: true,
                              ),
                            if (_mensajeExito != null)
                              _Aviso(
                                texto: _mensajeExito!,
                                textoKey: const Key('banner-exito-perfil'),
                              ),
                            if (c.maxWidth >= anchoEscritorio)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 4, child: _tarjetaCuenta()),
                                  ManiGap.hXxl,
                                  Expanded(flex: 6, child: _tarjetaDatos()),
                                ],
                              )
                            else ...[
                              _tarjetaCuenta(),
                              ManiGap.vXxl,
                              _tarjetaDatos(),
                            ],
                            ManiGap.vXxl,
                            _barraAccion(c.maxWidth),
                            ManiGap.vHuge,
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCuenta() {
    return Container(
      decoration: maniCaja(),
      padding: const EdgeInsets.all(ManiSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ManiTituloTarjeta(
            icono: Icons.badge_outlined,
            texto: '1. Tu cuenta',
          ),
          ManiGap.vXl,
          if (_perfil != null) ...[
            FotoPerfilSelectorWidget(
              fullName: _perfil!.fullName,
              photoUrl: _perfil!.photoUrl,
              subiendo: _subiendoFoto,
              onFotoSeleccionada: _subirFoto,
              selectorImagen: widget.selectorImagen,
            ),
            ManiGap.vLg,
            Wrap(
              alignment: WrapAlignment.center,
              spacing: ManiSpace.sm,
              runSpacing: ManiSpace.sm,
              children: [
                ManiEstado(
                  key: const Key('chip-rol-solo-lectura'),
                  texto: _textoRol(_perfil!.role),
                ),
                ManiEstado(
                  key: const Key('chip-estado-solo-lectura'),
                  texto: _estado(_perfil!.status).$1,
                  tono: _estado(_perfil!.status).$2,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaDatos() {
    return Container(
      decoration: maniCaja(),
      padding: const EdgeInsets.all(ManiSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ManiTituloTarjeta(
            icono: Icons.person_outline,
            texto: '2. Datos de contacto',
          ),
          ManiGap.vXl,
          const ManiEtiquetaCampo('Nombre completo o razón social'),
          ManiTextField(
            key: const Key('input-nombre-perfil'),
            controller: _nombreController,
            decoration: const InputDecoration(
              hintText: 'Ej: Carlos Alberto Gómez Mendoza',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) {
              final clean = v?.trim() ?? '';
              if (clean.length < 2) {
                return 'El nombre debe tener al menos 2 caracteres';
              }
              return null;
            },
          ),
          ManiGap.vLg,
          const ManiEtiquetaCampo('Teléfono de contacto'),
          ManiTextField(
            key: const Key('input-telefono-perfil'),
            controller: _telefonoController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: '+57 300 123 4567',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) {
              final clean = v?.trim() ?? '';
              if (clean.isEmpty || !_phoneRegex.hasMatch(clean)) {
                return 'Ingresa un teléfono válido';
              }
              return null;
            },
          ),
          ManiGap.vLg,
          const ManiEtiquetaCampo('Dirección principal'),
          ManiTextField(
            key: const Key('input-direccion-perfil'),
            controller: _direccionController,
            decoration: const InputDecoration(
              hintText: 'Ej: Cra 15 # 85-30, Apto 402, Chapinero',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (v) {
              final clean = v?.trim() ?? '';
              if (clean.length < 5) {
                return 'La dirección no puede estar vacía (mínimo 5 caracteres)';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  /// Barra inferior con el botón principal, como "Crear mi cuenta" del
  /// registro: texto a la izquierda y botón de 320 px a la derecha.
  Widget _barraAccion(double ancho) {
    final boton = ManiButton(
      key: const Key('btn-guardar-perfil'),
      etiqueta: _guardando ? 'GUARDANDO...' : 'GUARDAR CAMBIOS',
      icono: Icons.save_outlined,
      cargando: _guardando,
      expandir: true,
      onPressed: _guardando ? null : _guardarCambios,
    );
    final texto = Row(
      children: [
        Icon(Icons.lock_outline, color: context.mani.ink),
        ManiGap.hMd,
        Expanded(
          child: Text(
            'Tus datos solo se comparten con el aliado al confirmar un servicio.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: ManiFontSize.caption,
              color: context.mani.inkMuted,
            ),
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(ManiSpace.xxl),
      decoration: maniCaja(),
      child: ancho >= 600
          ? Row(
              children: [
                Expanded(child: texto),
                ManiGap.hXxl,
                SizedBox(width: 320, child: boton),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [texto, ManiGap.vLg, boton],
            ),
    );
  }
}

/// Mensaje de error o de éxito con el estilo de tarjeta del registro.
class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.texto,
    required this.textoKey,
    this.error = false,
  });

  final String texto;
  final Key textoKey;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? ManiColors.danger : ManiColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: ManiSpace.xl),
      padding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.lg,
        vertical: ManiSpace.md,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: color, width: ManiBorder.regular),
      ),
      child: Row(
        children: [
          Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
          ),
          ManiGap.hSm,
          Expanded(
            child: Text(
              texto,
              key: textoKey,
              style: GoogleFonts.plusJakartaSans(
                fontSize: ManiFontSize.bodySm,
                fontWeight: FontWeight.w700,
                color: context.mani.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El rol en palabras de persona; un valor desconocido se muestra tal cual.
String _textoRol(String rol) => switch (rol.toUpperCase()) {
  'ALLY' || 'ALIADO' => 'Aliado',
  'CLIENT' || 'CLIENTE' => 'Cliente',
  'ADMIN_TENANT' || 'ADMIN_PLATAFORMA' || 'ADMIN' => 'Administrador',
  _ => rol,
};

/// El estado de la cuenta como texto de persona y su tono; un valor desconocido se muestra tal cual.
(String, ManiTono) _estado(String estado) => switch (estado.toUpperCase()) {
  'VERIFIED' || 'VERIFICADO' => ('Verificado', ManiTono.listo),
  'ACTIVE' || 'ACTIVO' => ('Cuenta activa', ManiTono.listo),
  'PENDING' ||
  'PENDING_VERIFICATION' ||
  'IN_REVIEW' => ('En verificación', ManiTono.atencion),
  'SUSPENDED' || 'REJECTED' || 'SUSPENDIDO' => ('Suspendida', ManiTono.mal),
  _ => (estado, ManiTono.neutro),
};
