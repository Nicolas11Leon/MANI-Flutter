import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_layout.dart';

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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ManiIconoCaja(
                icono: s.esMia
                    ? Icons.assignment_turned_in_outlined
                    : Icons.home_repair_service_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.categoria,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ManiColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _Dato(
                      icono: Icons.place_outlined,
                      texto: s.ubicacion.isEmpty
                          ? 'Zona sin nombre'
                          : s.ubicacion,
                    ),
                    const SizedBox(height: 2),
                    _Dato(
                      icono: urgente
                          ? Icons.priority_high_rounded
                          : Icons.schedule_rounded,
                      texto: s.esMia
                          ? 'Asignada ${haceCuanto(s.fechaAsignacion ?? s.fechaCreacion, hoy).toLowerCase()}'
                          : 'Solicitada ${haceCuanto(s.fechaCreacion, hoy).toLowerCase()}',
                      color: urgente ? ManiColors.dangerText : null,
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
            const SizedBox(height: 12),
            _Problema(
              texto: s.descripcion!.trim(),
              fotos: s.cantidadFotos,
              fotosRutas: s.fotosRutas,
              solicitudId: s.id,
            ),
          ],
          const SizedBox(height: 12),
          _ModalidadBadge(modalidad: s.modalidad),
          const SizedBox(height: 12),
          _ReglasSitio(
            reglas: reglasParaMostrar(s.reglasSitio, asignado: s.esMia),
          ),
          if (s.esMia) ...[
            const SizedBox(height: 12),
            _Direccion(direccion: s.direccion),
            if (s.cancelada) ...[
              const SizedBox(height: 12),
              const Text(
                'El cliente canceló esta solicitud antes de la ejecución.',
                key: ValueKey('aviso-cancelada'),
                style: TextStyle(
                  color: ManiColors.dangerText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else if (onCotizar != null) ...[
              const SizedBox(height: 12),
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
            const SizedBox(height: 16),
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
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ManiColors.brandSoft,
        borderRadius: BorderRadius.circular(ManiRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texto,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
          if (fotosRutas.isNotEmpty)
            FotosAdjuntasPreview(
              fotosRutas: fotosRutas,
              solicitudId: solicitudId,
            )
          else if (fotos > 0) ...[
            const SizedBox(height: 8),
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
    final (icono, texto, fondo) = switch (modalidad) {
      ModalidadServicio.cotizacionPrevia => (
        Icons.request_quote_outlined,
        'Requiere cotización antes de empezar',
        ManiColors.brandSoft,
      ),
      ModalidadServicio.tarifaEstandar => (
        Icons.sell_outlined,
        'Tarifa estándar del tenant',
        ManiColors.successContainer,
      ),
      ModalidadServicio.desconocida => (
        Icons.help_outline,
        'Modalidad de cobro por confirmar',
        ManiColors.surfaceMuted,
      ),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: ManiColors.ink),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                texto,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ManiColors.ink,
                ),
              ),
            ),
          ],
        ),
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
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: ManiColors.inkMuted,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in reglas)
              Builder(
                builder: (_) {
                  final d = describirRegla(r);
                  return Container(
                    key: ValueKey('regla-${r.clave}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: d.advertencia
                          ? ManiColors.warningContainer
                          : ManiColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(ManiRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(d.icono, size: 13, color: ManiColors.ink),
                        const SizedBox(width: 4),
                        // Flexible: los textos largos (horario, contacto,
                        // instrucciones) saltan de línea en vez de desbordar.
                        Flexible(
                          child: Text(
                            d.texto,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: d.advertencia
                                  ? ManiColors.warningText
                                  : ManiColors.ink,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ManiColors.successContainer,
        borderRadius: BorderRadius.circular(ManiRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: ManiColors.ink),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DIRECCIÓN DEL SERVICIO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: ManiColors.successText,
                  ),
                ),
                const SizedBox(height: 2),
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
        const SizedBox(width: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ManiColors.ink,
        borderRadius: BorderRadius.circular(ManiRadius.sm),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: ManiColors.brand,
        ),
      ),
    );
  }
}
