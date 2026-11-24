import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';

import '../bloc/crear_solicitud_cubit.dart';
import '../utils/estilo_solicitud.dart';
import 'encabezado_paso.dart';

/// Paso 4: revisar antes de publicar, con acceso directo a editar cada parte.
class PasoRevision extends StatelessWidget {
  const PasoRevision({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CrearSolicitudCubit>().state;
    final cubit = context.read<CrearSolicitudCubit>();
    final categoria = state.categoria;
    final ubicacion = switch (state.modo) {
      ModoUbicacion.sitioGuardado => (
        state.sitio?.direccion ?? '',
        state.sitio?.ubicacion ?? '',
      ),
      ModoUbicacion.nuevaDireccion => (
        state.direccion.trim(),
        state.zona?.etiqueta ?? '',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EncabezadoPaso(
          titulo: 'Revisa y publica',
          subtitulo: 'Así verán tu solicitud los aliados de tu zona.',
        ),
        ManiGap.vLg,
        _Seccion(
          titulo: 'Servicio',
          onEditar: () => cubit.irA(PasoSolicitud.categoria),
          claveEditar: 'editar-categoria',
          child: Row(
            children: [
              Icon(
                iconoCategoria(categoria?.nombre ?? ''),
                color: context.mani.ink,
              ),
              ManiGap.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoria?.nombre ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (categoria != null)
                      Text(
                        textoModalidad(categoria.modalidad),
                        style: TextStyle(
                          fontSize: ManiFontSize.caption,
                          color: context.mani.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ManiGap.vMd,
        _Seccion(
          titulo: 'Problema',
          onEditar: () => cubit.irA(PasoSolicitud.detalle),
          claveEditar: 'editar-detalle',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.descripcion.trim()),
              ManiGap.vSm,
              Row(
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 16,
                    color: context.mani.inkMuted,
                  ),
                  ManiGap.hXs,
                  Text(
                    switch (state.fotos.length) {
                      0 => 'Sin fotos',
                      1 => '1 foto',
                      final n => '$n fotos',
                    },
                    style: TextStyle(
                      fontSize: ManiFontSize.caption,
                      fontWeight: FontWeight.w700,
                      color: context.mani.inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ManiGap.vMd,
        _Seccion(
          titulo: 'Ubicación',
          onEditar: () => cubit.irA(PasoSolicitud.ubicacion),
          claveEditar: 'editar-ubicacion',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ubicacion.$1,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                ubicacion.$2,
                style: TextStyle(
                  fontSize: ManiFontSize.caption,
                  color: context.mani.inkMuted,
                ),
              ),
            ],
          ),
        ),
        ManiGap.vLg,
        const _QuePasaDespues(),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.onEditar,
    required this.claveEditar,
    required this.child,
  });

  final String titulo;
  final VoidCallback onEditar;
  final String claveEditar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ManiSpace.lg,
        ManiSpace.sm,
        ManiSpace.sm,
        ManiSpace.md,
      ),
      decoration: BoxDecoration(
        color: context.mani.surface,
        borderRadius: ManiRadius.brMd,
        border: Border.all(
          color: context.mani.border,
          width: ManiBorder.regular,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo.toUpperCase(),
                  style: TextStyle(
                    fontSize: ManiFontSize.micro,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: context.mani.inkSubtle,
                  ),
                ),
              ),
              TextButton.icon(
                key: ValueKey(claveEditar),
                onPressed: onEditar,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
                style: TextButton.styleFrom(
                  foregroundColor: context.mani.ink,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: ManiSpace.sm),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _QuePasaDespues extends StatelessWidget {
  const _QuePasaDespues();

  static const _pasos = [
    'Los aliados verificados de este servicio en tu zona ven tu solicitud.',
    'El primero que la acepte se queda con el trabajo y te contactará.',
    'Recibirás su cotización antes de que empiece.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: context.mani.brandSoft,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: context.mani.border, width: ManiBorder.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Qué pasa después?',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          ManiGap.vSm,
          for (var i = 0; i < _pasos.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: ManiSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.mani.ink,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: ManiFontSize.micro,
                        fontWeight: FontWeight.w900,
                        color: context.mani.brand,
                      ),
                    ),
                  ),
                  ManiGap.hSm,
                  Expanded(
                    child: Text(
                      _pasos[i],
                      style: const TextStyle(fontSize: ManiFontSize.bodySm),
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
