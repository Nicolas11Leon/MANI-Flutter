import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

import '../../domain/entities/documento_kyc.dart';
import '../utils/formato_fecha.dart';

/// Fila de un documento KYC con acción para abrirlo en un visor.
class DocumentoKycTile extends StatelessWidget {
  const DocumentoKycTile({
    super.key,
    required this.documento,
    required this.onVer,
  });

  final DocumentoKyc documento;
  final VoidCallback onVer;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final (colorEstado, textoEstado) = switch (documento.estado) {
      EstadoDocumentoKyc.pendiente => (ManiColors.warning, 'Por revisar'),
      EstadoDocumentoKyc.verificado => (ManiColors.success, 'Verificado'),
      EstadoDocumentoKyc.rechazado => (ManiColors.dangerText, 'Rechazado'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: ManiSpace.sm),
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: context.mani.surface,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: context.mani.border, width: ManiBorder.thin),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: documento.esImagen
                  ? ManiColors.accentContainer
                  : ManiColors.dangerContainer,
              borderRadius: ManiRadius.brSm,
              border: Border.all(
                color: context.mani.border,
                width: ManiBorder.thin,
              ),
            ),
            child: Icon(
              documento.esImagen
                  ? Icons.image_outlined
                  : Icons.picture_as_pdf_outlined,
              color: context.mani.ink,
              size: 20,
            ),
          ),
          ManiGap.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  documento.tipo.etiqueta,
                  style: tema.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                ManiGap.vXxs,
                Text(
                  [
                    documento.nombreArchivo,
                    if (documento.fechaCarga != null)
                      fechaCorta(documento.fechaCarga!),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.bodySmall?.copyWith(color: context.mani.inkMuted),
                ),
                ManiGap.vXxs,
                Text(
                  textoEstado,
                  style: tema.labelSmall?.copyWith(
                    color: colorEstado,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          ManiGap.hSm,
          OutlinedButton.icon(
            key: ValueKey('ver-doc-${documento.id}'),
            onPressed: onVer,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Ver'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.mani.ink,
              side: ManiBorder.sideThin,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(borderRadius: ManiRadius.brSm),
            ),
          ),
        ],
      ),
    );
  }
}
