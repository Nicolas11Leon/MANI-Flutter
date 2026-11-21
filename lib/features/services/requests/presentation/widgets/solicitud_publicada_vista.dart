import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';

import '../../domain/entities/solicitud_publicada.dart';
import '../utils/estilo_solicitud.dart';

/// Confirmación: la solicitud quedó publicada y qué sigue.
class SolicitudPublicadaVista extends StatelessWidget {
  const SolicitudPublicadaVista({
    super.key,
    required this.solicitud,
    required this.onNueva,
    this.onIrAMisSolicitudes,
    this.onReintentarAviso,
    this.avisando = false,
  });

  final SolicitudPublicada solicitud;
  final VoidCallback onNueva;
  final VoidCallback? onIrAMisSolicitudes;

  /// Repite el aviso a los aliados si la publicación no lo logró (SCRUM-1402).
  final VoidCallback? onReintentarAviso;
  final bool avisando;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    final s = solicitud;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ManiSpace.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(ManiSpace.xl),
                decoration: BoxDecoration(
                  color: t.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.border, width: 3),
                  boxShadow: [t.shadow],
                ),
                child: Icon(Icons.campaign_rounded, size: 40, color: t.onBrand),
              ),
              ManiGap.vLg,
              Text(
                '¡Solicitud publicada!',
                key: const ValueKey('titulo-publicada'),
                style: TextStyle(
                  fontSize: ManiFontSize.h2,
                  fontWeight: FontWeight.w900,
                  color: t.ink,
                ),
              ),
              ManiGap.vSm,
              Text(
                s.aliadosAvisados
                    ? 'Los aliados de ${s.categoria} en ${s.zona} ya pueden verla. '
                          'Te avisaremos cuando uno la tome.'
                    : 'Tu solicitud quedó guardada, pero todavía no pudimos '
                          'avisarle a los aliados.',
                key: const ValueKey('texto-publicada'),
                textAlign: TextAlign.center,
                style: TextStyle(color: t.inkMuted),
              ),
              if (!s.aliadosAvisados) ...[
                ManiGap.vMd,
                ManiButton(
                  key: const ValueKey('btn-reintentar-aviso'),
                  etiqueta: avisando ? 'Avisando…' : 'Avisar a los aliados',
                  icono: Icons.refresh_rounded,
                  expandir: true,
                  onPressed: avisando ? null : onReintentarAviso,
                ),
              ],
              ManiGap.vXl,
              ManiCard(
                sombra: t.shadowSm,
                onTap: onIrAMisSolicitudes,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(iconoCategoria(s.categoria), color: t.ink),
                        ManiGap.hSm,
                        Expanded(
                          child: Text(
                            s.categoria,
                            style: TextStyle(
                              fontSize: ManiFontSize.bodyLg,
                              fontWeight: FontWeight.w900,
                              color: t.ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ManiSpace.sm,
                            vertical: ManiSpace.xs,
                          ),
                          decoration: BoxDecoration(
                            color: ManiColors.warningContainer,
                            borderRadius: ManiRadius.brPill,
                            border: Border.all(
                              color: t.border,
                              width: ManiBorder.thin,
                            ),
                          ),
                          child: Text(
                            s.aliadosAvisados
                                ? 'BUSCANDO ALIADO'
                                : 'SIN AVISAR',
                            style: const TextStyle(
                              fontSize: ManiFontSize.nano,
                              fontWeight: FontWeight.w900,
                              color: ManiColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ManiGap.vSm,
                    Text(
                      s.descripcion,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: t.ink),
                    ),
                    ManiGap.vSm,
                    _Dato(icono: Icons.place_outlined, texto: s.direccion),
                    _Dato(icono: Icons.map_outlined, texto: s.ubicacion),
                    _Dato(
                      icono: Icons.photo_library_outlined,
                      texto: switch (s.cantidadFotos) {
                        0 => 'Sin fotos',
                        1 => '1 foto adjunta',
                        final n => '$n fotos adjuntas',
                      },
                    ),
                    _Dato(
                      icono: Icons.request_quote_outlined,
                      texto: textoModalidad(s.modalidad),
                    ),
                  ],
                ),
              ),
              ManiGap.vXxl,
              ManiButton(
                key: const ValueKey('btn-mis-solicitudes'),
                etiqueta: 'Ir a Mis solicitudes',
                icono: Icons.list_alt_rounded,
                expandir: true,
                onPressed: onIrAMisSolicitudes,
              ),
              ManiGap.vMd,
              ManiButton(
                key: const ValueKey('btn-otra-solicitud'),
                etiqueta: 'Publicar otra solicitud',
                icono: Icons.add_rounded,
                variante: ManiButtonVariante.secundario,
                expandir: true,
                onPressed: onNueva,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return Padding(
      padding: const EdgeInsets.only(top: ManiSpace.xs),
      child: Row(
        children: [
          Icon(icono, size: 16, color: t.inkMuted),
          ManiGap.hSm,
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: ManiFontSize.bodySm,
                fontWeight: FontWeight.w600,
                color: t.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
