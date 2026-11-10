import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_card.dart';

import '../../domain/entities/solicitud_aliado.dart';
import '../utils/formato_fecha.dart';
import 'aliado_avatar.dart';
import 'estado_verificacion_badge.dart';

/// Tarjeta de un aliado en la bandeja.
class SolicitudAliadoCard extends StatelessWidget {
  const SolicitudAliadoCard({
    super.key,
    required this.aliado,
    required this.onTap,
    this.seleccionada = false,
    this.ahora,
  });

  final SolicitudAliado aliado;
  final VoidCallback onTap;
  final bool seleccionada;
  final DateTime? ahora;

  /// A partir de estos días de espera la tarjeta marca la solicitud como urgente.
  static const int diasUrgencia = 3;

  @override
  Widget build(BuildContext context) {
    final hoy = ahora ?? DateTime.now();
    final urgente =
        aliado.estaPendiente && aliado.diasEnEspera(hoy) >= diasUrgencia;
    final tema = Theme.of(context).textTheme;

    return Semantics(
      selected: seleccionada,
      child: ManiCard(
        key: ValueKey('card-aliado-${aliado.id}'),
        seleccionada: seleccionada,
        onTap: onTap,
        sombra: ManiShadow.sm,
        padding: const EdgeInsets.all(ManiSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AliadoAvatar(aliado: aliado, tamano: 44),
            ManiGap.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          aliado.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (!aliado.estaPendiente)
                        EstadoVerificacionBadge(
                          estado: aliado.estado,
                          compacto: true,
                        ),
                    ],
                  ),
                  ManiGap.vXxs,
                  Text(
                    aliado.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tema.bodySmall?.copyWith(color: ManiColors.inkMuted),
                  ),
                  ManiGap.vSm,
                  Wrap(
                    spacing: ManiSpace.sm,
                    runSpacing: ManiSpace.sm,
                    children: [
                      _Etiqueta(
                        icono: Icons.badge_outlined,
                        texto: aliado.tipo.etiqueta,
                      ),
                      if (aliado.categorias.isNotEmpty)
                        _Etiqueta(
                          icono: Icons.handyman_outlined,
                          texto: aliado.categorias.first,
                        ),
                      _Etiqueta(
                        icono: aliado.tieneDocumentos
                            ? Icons.description_outlined
                            : Icons.report_gmailerrorred,
                        texto: aliado.tieneDocumentos
                            ? '${aliado.documentos.length} ${aliado.documentos.length == 1 ? 'documento' : 'documentos'}'
                            : 'Sin documentos',
                        alerta: !aliado.tieneDocumentos,
                      ),
                    ],
                  ),
                  ManiGap.vSm,
                  Row(
                    children: [
                      Icon(
                        urgente
                            ? Icons.priority_high_rounded
                            : Icons.schedule_rounded,
                        size: 14,
                        color: urgente
                            ? ManiColors.danger
                            : ManiColors.inkSubtle,
                      ),
                      ManiGap.hXs,
                      Flexible(
                        child: Text(
                          aliado.estaPendiente
                              ? 'Registrado ${haceCuanto(aliado.fechaRegistro, hoy).toLowerCase()}'
                              : 'Resuelto el ${fechaCorta(aliado.fechaVerificacion ?? aliado.fechaRegistro)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.labelSmall?.copyWith(
                            color: urgente
                                ? ManiColors.danger
                                : ManiColors.inkSubtle,
                            fontWeight: urgente
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ManiGap.hXs,
            const Icon(
              Icons.chevron_right_rounded,
              color: ManiColors.inkSubtle,
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({
    required this.icono,
    required this.texto,
    this.alerta = false,
  });

  final IconData icono;
  final String texto;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final color = alerta ? ManiColors.danger : ManiColors.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.sm,
        vertical: ManiSpace.xs,
      ),
      decoration: BoxDecoration(
        color: alerta ? ManiColors.dangerContainer : ManiColors.background,
        borderRadius: ManiRadius.brXs,
        border: Border.all(
          color: alerta ? ManiColors.danger : ManiColors.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          ManiGap.hXs,
          Text(
            texto,
            style: TextStyle(
              fontSize: ManiFontSize.micro,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
