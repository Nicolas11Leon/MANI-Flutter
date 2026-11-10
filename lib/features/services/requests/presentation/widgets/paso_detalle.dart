import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';

import '../../domain/entities/nueva_solicitud.dart';
import '../bloc/crear_solicitud_cubit.dart';
import 'encabezado_paso.dart';

/// Paso 2: describe el problema y adjunta fotos.
class PasoDetalle extends StatelessWidget {
  const PasoDetalle({
    super.key,
    required this.descripcion,
    required this.onAgregarFotos,
  });

  final TextEditingController descripcion;
  final VoidCallback onAgregarFotos;

  static const _consejos = [
    '¿Qué está pasando? (ej. gotea la llave del lavamanos)',
    '¿Desde cuándo ocurre?',
    '¿Dónde exactamente? (baño, cocina, fachada…)',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CrearSolicitudCubit>().state;
    final cubit = context.read<CrearSolicitudCubit>();
    final largo = state.descripcion.trim().length;
    final falta = NuevaSolicitud.descripcionMinima - largo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoPaso(
          titulo: 'Cuéntanos el problema',
          subtitulo: state.categoria == null
              ? 'Entre más detalle, mejores cotizaciones recibirás.'
              : '${state.categoria!.nombre}: entre más detalle, mejores '
                    'cotizaciones recibirás.',
        ),
        ManiGap.vLg,
        Container(
          padding: const EdgeInsets.all(ManiSpace.md),
          decoration: BoxDecoration(
            color: ManiColors.brandSoft,
            borderRadius: ManiRadius.brMd,
            border: Border.all(
              color: ManiColors.border,
              width: ManiBorder.thin,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Una buena descripción responde:',
                style: TextStyle(
                  fontSize: ManiFontSize.caption,
                  fontWeight: FontWeight.w900,
                ),
              ),
              ManiGap.vSm,
              for (final c in _consejos)
                Padding(
                  padding: const EdgeInsets.only(bottom: ManiSpace.xxs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '•  ',
                        style: TextStyle(fontSize: ManiFontSize.caption),
                      ),
                      Expanded(
                        child: Text(
                          c,
                          style: const TextStyle(
                            fontSize: ManiFontSize.caption,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        ManiGap.vMd,
        TextField(
          key: const ValueKey('campo-descripcion'),
          controller: descripcion,
          onChanged: cubit.actualizarDescripcion,
          minLines: 5,
          maxLines: 8,
          maxLength: NuevaSolicitud.descripcionMaxima,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText:
                'Ej: La tubería debajo del lavaplatos gotea desde ayer y el '
                'piso de la cocina se está mojando.',
            helperText: falta > 0
                ? 'Escribe al menos $falta caracteres más.'
                : '¡Bien! Tu descripción está completa.',
            helperStyle: TextStyle(
              color: falta > 0 ? ManiColors.inkMuted : ManiColors.success,
              fontWeight: FontWeight.w700,
            ),
            filled: true,
            fillColor: ManiColors.surface,
            enabledBorder: _borde(2),
            focusedBorder: _borde(2.5),
          ),
        ),
        ManiGap.vXl,
        Row(
          children: [
            const Expanded(
              child: Text(
                'Fotos del problema (opcional)',
                style: TextStyle(
                  fontSize: ManiFontSize.body,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${state.fotos.length}/${NuevaSolicitud.maxFotos}',
              key: const ValueKey('contador-fotos'),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: ManiColors.inkMuted,
              ),
            ),
          ],
        ),
        ManiGap.vXs,
        const Text(
          'Ayudan a que el aliado cotice sin visitar primero. JPG, PNG o WEBP '
          'de hasta 5 MB.',
          style: TextStyle(
            fontSize: ManiFontSize.caption,
            color: ManiColors.inkMuted,
          ),
        ),
        ManiGap.vSm,
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < state.fotos.length; i++)
              _Miniatura(
                key: ValueKey('foto-$i'),
                indice: i,
                bytes: state.fotos[i].bytes,
                onQuitar: () => cubit.quitarFoto(i),
              ),
            if (!state.fotosCompletas) _AgregarFoto(onTap: onAgregarFotos),
          ],
        ),
      ],
    );
  }

  static OutlineInputBorder _borde(double ancho) => OutlineInputBorder(
    borderRadius: ManiRadius.brMd,
    borderSide: BorderSide(color: ManiColors.ink, width: ancho),
  );
}

class _AgregarFoto extends StatelessWidget {
  const _AgregarFoto({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Agregar fotos',
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('btn-agregar-fotos'),
        onTap: onTap,
        borderRadius: ManiRadius.brMd,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: ManiColors.surface,
            borderRadius: ManiRadius.brMd,
            border: Border.all(
              color: ManiColors.border,
              width: ManiBorder.regular,
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, color: ManiColors.ink),
              ManiGap.vXs,
              Text(
                'Agregar',
                style: TextStyle(
                  fontSize: ManiFontSize.caption,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({
    super.key,
    required this.indice,
    required this.bytes,
    required this.onQuitar,
  });

  final int indice;
  final Uint8List bytes;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: ManiColors.background,
                borderRadius: ManiRadius.brMd,
                border: Border.all(
                  color: ManiColors.border,
                  width: ManiBorder.regular,
                ),
              ),
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.image_outlined, color: ManiColors.inkMuted),
                ),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              button: true,
              label: 'Quitar foto ${indice + 1}',
              excludeSemantics: true,
              child: InkWell(
                key: ValueKey('quitar-foto-$indice'),
                onTap: onQuitar,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: ManiColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ManiColors.border,
                      width: ManiBorder.regular,
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
