import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';

import '../../domain/entities/modalidad_servicio.dart';
import '../../domain/entities/regla_sitio.dart';
import '../../domain/entities/solicitud_entity.dart';
import '../bloc/solicitudes_aliado_cubit.dart';
import '../utils/formato_solicitud.dart';
import 'fotos_adjuntas_viewer.dart';

/// Tarjeta de una solicitud. Si está disponible muestra Rechazar / Aceptar;
/// si ya es del aliado muestra la dirección y cuándo la ganó.
class SolicitudCard extends StatelessWidget {
  const SolicitudCard({
    super.key,
    required this.solicitud,
    this.onAceptar,
    this.onRechazar,
    this.onCotizar,
    this.accionEnCurso,
    this.bloqueada = false,
    this.recienAsignada = false,
    this.ahora,
  });

  final SolicitudEntity solicitud;
  final VoidCallback? onAceptar;
  final VoidCallback? onRechazar;

  /// Abre la cotización; solo se ofrece en las solicitudes asignadas al aliado
  /// (SCRUM-865). Core valida que sea el aliado asignado.
  final VoidCallback? onCotizar;

  /// Acción que se está enviando para ESTA solicitud.
  final AccionSolicitud? accionEnCurso;

  /// Otra solicitud se está procesando: se deshabilitan las acciones.
  final bool bloqueada;
  final bool recienAsignada;
  final DateTime? ahora;

  /// A partir de estos minutos de espera la solicitud se marca como urgente.
  static const int minutosUrgencia = 30;

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    final hoy = ahora ?? DateTime.now();
    final urgente =
        s.estaDisponible && s.minutosEsperando(hoy) >= minutosUrgencia;

    return ManiCard(
      key: ValueKey('card-solicitud-${s.id}'),
      seleccionada: recienAsignada,
      sombra: ManiShadow.sm,
      padding: const EdgeInsets.all(ManiSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.esMia
                      ? ManiColors.successContainer
                      : ManiColors.brand,
                  borderRadius: ManiRadius.brMd,
                  border: Border.all(
                    color: ManiColors.border,
                    width: ManiBorder.regular,
                  ),
                ),
                child: Icon(
                  s.esMia
                      ? Icons.assignment_turned_in_outlined
                      : Icons.home_repair_service_rounded,
                  color: ManiColors.ink,
                ),
              ),
              ManiGap.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.categoria,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: ManiFontSize.bodyLg,
                        fontWeight: FontWeight.w900,
                        color: ManiColors.ink,
                      ),
                    ),
                    ManiGap.vXs,
                    _Dato(
                      icono: Icons.place_outlined,
                      texto: s.ubicacion.isEmpty
                          ? 'Zona sin nombre'
                          : s.ubicacion,
                    ),
                    ManiGap.vXxs,
                    _Dato(
                      icono: urgente
                          ? Icons.priority_high_rounded
                          : Icons.schedule_rounded,
                      texto: s.esMia
                          ? 'Asignada ${haceCuanto(s.fechaAsignacion ?? s.fechaCreacion, hoy).toLowerCase()}'
                          : 'Solicitada ${haceCuanto(s.fechaCreacion, hoy).toLowerCase()}',
                      color: urgente ? ManiColors.danger : null,
                      negrita: urgente,
                    ),
                  ],
                ),
              ),
              if (s.cancelada)
                const _Etiqueta(
                  'CANCELADA',
                  key: ValueKey('etiqueta-cancelada'),
                )
              else if (recienAsignada)
                const _Etiqueta('NUEVA'),
            ],
          ),
          if ((s.descripcion ?? '').trim().isNotEmpty) ...[
            ManiGap.vMd,
            _Problema(
              texto: s.descripcion!.trim(),
              fotos: s.cantidadFotos,
              fotosRutas: s.fotosRutas,
              solicitudId: s.id,
            ),
          ],
          ManiGap.vMd,
          _ModalidadBadge(modalidad: s.modalidad),
          ManiGap.vMd,
          _ReglasSitio(
            reglas: reglasParaMostrar(s.reglasSitio, asignado: s.esMia),
          ),
          if (s.esMia) ...[
            ManiGap.vMd,
            _Direccion(direccion: s.direccion),
            if (s.cancelada) ...[
              ManiGap.vMd,
              const Text(
                'El cliente canceló esta solicitud antes de la ejecución.',
                key: ValueKey('aviso-cancelada'),
                style: TextStyle(
                  color: ManiColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else if (onCotizar != null) ...[
              ManiGap.vMd,
              ManiButton(
                key: ValueKey('btn-cotizar-${s.id}'),
                etiqueta: 'Cotización',
                icono: Icons.request_quote_outlined,
                variante: ManiButtonVariante.secundario,
                expandir: true,
                onPressed: onCotizar,
              ),
            ],
          ],
          if (s.estaDisponible) ...[
            ManiGap.vLg,
            _Acciones(
              solicitudId: s.id,
              accionEnCurso: accionEnCurso,
              bloqueada: bloqueada,
              onAceptar: onAceptar,
              onRechazar: onRechazar,
            ),
          ],
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.texto,
    this.color,
    this.negrita = false,
  });

  final IconData icono;
  final String texto;
  final Color? color;
  final bool negrita;

  @override
  Widget build(BuildContext context) {
    final c = color ?? ManiColors.inkMuted;
    return Row(
      children: [
        Icon(icono, size: 15, color: c),
        ManiGap.hXs,
        Flexible(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ManiFontSize.bodySm,
              color: c,
              fontWeight: negrita ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Problema descrito por el cliente (US-04.1.1): base para decidir y cotizar.
class _Problema extends StatelessWidget {
  const _Problema({
    required this.texto,
    required this.fotos,
    this.fotosRutas = const [],
    this.solicitudId,
  });

  final String texto;
  final int fotos;
  final List<String> fotosRutas;
  final String? solicitudId;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('problema-solicitud'),
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: ManiColors.background,
        borderRadius: ManiRadius.brSm,
        border: Border.all(
          color: ManiColors.borderSubtle,
          width: ManiBorder.thin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texto,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: ManiFontSize.bodySm, height: 1.35),
          ),
          if (fotosRutas.isNotEmpty)
            FotosAdjuntasPreview(
              fotosRutas: fotosRutas,
              solicitudId: solicitudId,
            )
          else if (fotos > 0) ...[
            ManiGap.vSm,
            _Dato(
              icono: Icons.photo_library_outlined,
              texto: fotos == 1 ? '1 foto adjunta' : '$fotos fotos adjuntas',
            ),
          ],
        ],
      ),
    );
  }
}

class _ModalidadBadge extends StatelessWidget {
  const _ModalidadBadge({required this.modalidad});

  final ModalidadServicio modalidad;

  @override
  Widget build(BuildContext context) {
    final (icono, texto, tono) = switch (modalidad) {
      ModalidadServicio.cotizacionPrevia => (
        Icons.request_quote_outlined,
        'Requiere cotización antes de empezar',
        ManiTono.acento,
      ),
      ModalidadServicio.tarifaEstandar => (
        Icons.sell_outlined,
        'Tarifa estándar del tenant',
        ManiTono.exito,
      ),
      ModalidadServicio.desconocida => (
        Icons.help_outline,
        'Modalidad de cobro por confirmar',
        ManiTono.neutro,
      ),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: ManiStatusBadge(
        etiqueta: texto,
        tono: tono,
        icono: icono,
        mayusculas: false,
      ),
    );
  }
}

/// Reglas del sitio del cliente (RF-09, SCRUM-1388): en la oferta, los
/// requisitos; ya asignada, también el contacto y las instrucciones de ingreso.
class _ReglasSitio extends StatelessWidget {
  const _ReglasSitio({required this.reglas});

  final List<ReglaSitio> reglas;

  @override
  Widget build(BuildContext context) {
    if (reglas.isEmpty) {
      return const _Dato(
        icono: Icons.check_circle_outline,
        texto: 'Sin reglas especiales en el sitio',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REGLAS DEL SITIO',
          style: TextStyle(
            fontSize: ManiFontSize.nano,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            color: ManiColors.inkSubtle,
          ),
        ),
        ManiGap.vSm,
        Wrap(
          spacing: ManiSpace.sm,
          runSpacing: ManiSpace.sm,
          children: [
            for (final r in reglas)
              Builder(
                builder: (_) {
                  final d = describirRegla(r);
                  return Container(
                    key: ValueKey('regla-${r.clave}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: ManiSpace.sm,
                      vertical: ManiSpace.xs,
                    ),
                    decoration: BoxDecoration(
                      color: d.advertencia
                          ? ManiColors.warningContainer
                          : ManiColors.background,
                      borderRadius: ManiRadius.brXs,
                      border: Border.all(
                        color: d.advertencia
                            ? ManiColors.warning
                            : ManiColors.borderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(d.icono, size: 13, color: ManiColors.ink),
                        ManiGap.hXs,
                        // Flexible: los textos largos (horario, contacto,
                        // instrucciones) saltan de línea en vez de desbordar.
                        Flexible(
                          child: Text(
                            d.texto,
                            style: const TextStyle(
                              fontSize: ManiFontSize.micro,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _Direccion extends StatelessWidget {
  const _Direccion({required this.direccion});

  final String? direccion;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('direccion-solicitud'),
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: ManiColors.successContainer,
        borderRadius: ManiRadius.brSm,
        border: Border.all(color: ManiColors.border, width: ManiBorder.thin),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: ManiColors.ink),
          ManiGap.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DIRECCIÓN DEL SERVICIO',
                  style: TextStyle(
                    fontSize: ManiFontSize.nano,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: ManiColors.success,
                  ),
                ),
                ManiGap.vXxs,
                Text(
                  direccion ?? 'El cliente aún no registró la dirección.',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Acciones extends StatelessWidget {
  const _Acciones({
    required this.solicitudId,
    required this.accionEnCurso,
    required this.bloqueada,
    required this.onAceptar,
    required this.onRechazar,
  });

  final String solicitudId;
  final AccionSolicitud? accionEnCurso;
  final bool bloqueada;
  final VoidCallback? onAceptar;
  final VoidCallback? onRechazar;

  @override
  Widget build(BuildContext context) {
    final habilitada = !bloqueada && accionEnCurso == null;
    return Row(
      children: [
        Expanded(
          child: ManiButton(
            key: ValueKey('btn-rechazar-$solicitudId'),
            etiqueta: accionEnCurso == AccionSolicitud.rechazando
                ? 'Descartando…'
                : 'Rechazar',
            icono: Icons.close_rounded,
            variante: ManiButtonVariante.secundario,
            expandir: true,
            cargando: accionEnCurso == AccionSolicitud.rechazando,
            onPressed: habilitada ? onRechazar : null,
          ),
        ),
        ManiGap.hMd,
        Expanded(
          flex: 2,
          child: ManiButton(
            key: ValueKey('btn-aceptar-$solicitudId'),
            etiqueta: accionEnCurso == AccionSolicitud.aceptando
                ? 'Asegurando…'
                : 'Aceptar',
            icono: Icons.check_rounded,
            expandir: true,
            cargando: accionEnCurso == AccionSolicitud.aceptando,
            onPressed: habilitada ? onAceptar : null,
          ),
        ),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.sm,
        vertical: ManiSpace.xs,
      ),
      decoration: BoxDecoration(
        color: ManiColors.ink,
        borderRadius: ManiRadius.brXs,
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: ManiFontSize.nano,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: ManiColors.brand,
        ),
      ),
    );
  }
}
