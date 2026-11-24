import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';

import '../../domain/entities/solicitud_aliado.dart';
import '../bloc/bandeja_verificacion_cubit.dart';
import '../utils/formato_fecha.dart';
import 'aliado_avatar.dart';
import 'dialogos_verificacion.dart';
import 'documento_kyc_tile.dart';
import 'estado_verificacion_badge.dart';

/// Perfil completo del aliado candidato con sus documentos y las acciones
/// Aprobar / Rechazar. Se usa como panel derecho (escritorio) y como cuerpo
/// de la página de detalle (móvil).
class DetalleAliadoPanel extends StatelessWidget {
  const DetalleAliadoPanel({
    super.key,
    required this.aliadoId,
    this.onCerrar,
    this.onResuelto,
  });

  final String aliadoId;

  /// Si se provee, muestra un botón para cerrar el panel.
  final VoidCallback? onCerrar;

  /// Se invoca tras aprobar o rechazar con éxito.
  final VoidCallback? onResuelto;

  Future<void> _aprobar(BuildContext context, SolicitudAliado aliado) async {
    final cubit = context.read<BandejaVerificacionCubit>();
    if (!await confirmarAprobacion(context, aliado)) return;
    if (await cubit.aprobar(aliado.id)) onResuelto?.call();
  }

  Future<void> _rechazar(BuildContext context, SolicitudAliado aliado) async {
    final cubit = context.read<BandejaVerificacionCubit>();
    final motivo = await pedirMotivoRechazo(context, aliado);
    if (motivo == null) return;
    if (await cubit.rechazar(aliado.id, motivo)) onResuelto?.call();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BandejaVerificacionCubit, BandejaVerificacionState>(
      builder: (context, state) {
        final aliado = state.porId(aliadoId);
        if (aliado == null) {
          return const Center(
            child: Text('Este aliado ya no está en la bandeja.'),
          );
        }
        final procesando = state.procesandoId == aliadoId;
        final bloqueado = state.procesando;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.cargandoDetalleId == aliadoId)
              LinearProgressIndicator(
                minHeight: 3,
                color: context.mani.ink,
                backgroundColor: context.mani.brand,
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(ManiSpace.xxl),
                children: [
                  _Encabezado(aliado: aliado, onCerrar: onCerrar),
                  ManiGap.vXl,
                  _Seccion(
                    titulo: 'Datos del registro',
                    icono: Icons.person_search_outlined,
                    child: _DatosRegistro(aliado: aliado),
                  ),
                  ManiGap.vXl,
                  _Seccion(
                    titulo: 'Documentos KYC (${aliado.documentos.length})',
                    icono: Icons.folder_open_rounded,
                    child: aliado.tieneDocumentos
                        ? Column(
                            children: [
                              for (final d in aliado.documentos)
                                DocumentoKycTile(
                                  documento: d,
                                  onVer: () => context
                                      .read<BandejaVerificacionCubit>()
                                      .abrirDocumento(d),
                                ),
                            ],
                          )
                        : const _Aviso(
                            icono: Icons.report_gmailerrorred,
                            color: ManiColors.danger,
                            texto:
                                'Este aliado no adjuntó documentos. No puedes aprobarlo; '
                                'recházalo indicando qué debe cargar.',
                          ),
                  ),
                  ManiGap.vXl,
                  if (aliado.estaPendiente)
                    const _Aviso(
                      icono: Icons.lightbulb_outline_rounded,
                      color: ManiColors.warning,
                      texto:
                          'Antes de decidir, verifica que los documentos sean legibles, '
                          'estén vigentes y que el nombre coincida con el registro.',
                    )
                  else
                    _Resultado(aliado: aliado),
                ],
              ),
            ),
            if (aliado.estaPendiente)
              _BarraAcciones(
                procesando: procesando,
                puedeAprobar: aliado.tieneDocumentos && !bloqueado,
                puedeRechazar: !bloqueado,
                onAprobar: () => _aprobar(context, aliado),
                onRechazar: () => _rechazar(context, aliado),
              ),
          ],
        );
      },
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.aliado, this.onCerrar});

  final SolicitudAliado aliado;
  final VoidCallback? onCerrar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return ManiCard(
      padding: const EdgeInsets.all(ManiSpace.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AliadoAvatar(aliado: aliado, tamano: 64),
          ManiGap.hLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aliado.nombre,
                  style: tema.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                ManiGap.vXs,
                Text(
                  aliado.email,
                  style: tema.bodyMedium?.copyWith(
                    color: context.mani.inkMuted,
                  ),
                ),
                ManiGap.vSm,
                EstadoVerificacionBadge(estado: aliado.estado),
              ],
            ),
          ),
          if (onCerrar != null)
            IconButton(
              tooltip: 'Cerrar detalle',
              onPressed: onCerrar,
              icon: Icon(Icons.close_rounded, color: context.mani.ink),
            ),
        ],
      ),
    );
  }
}

class _DatosRegistro extends StatelessWidget {
  const _DatosRegistro({required this.aliado});

  final SolicitudAliado aliado;

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    return Column(
      children: [
        _Dato(etiqueta: 'Tipo de aliado', valor: aliado.tipo.etiqueta),
        _Dato(
          etiqueta: 'Fecha de registro',
          valor:
              '${fechaCorta(aliado.fechaRegistro)} · ${haceCuanto(aliado.fechaRegistro, ahora)}',
        ),
        _Dato(
          etiqueta: 'Especialidades',
          child: aliado.categorias.isEmpty
              ? Text(
                  'Sin especialidad declarada',
                  style: TextStyle(color: context.mani.inkMuted),
                )
              : Wrap(
                  spacing: ManiSpace.sm,
                  runSpacing: ManiSpace.sm,
                  children: [
                    for (final c in aliado.categorias)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ManiSpace.sm,
                          vertical: ManiSpace.xs,
                        ),
                        decoration: BoxDecoration(
                          color: context.mani.brand,
                          borderRadius: ManiRadius.brPill,
                          border: Border.all(
                            color: context.mani.border,
                            width: ManiBorder.thin,
                          ),
                        ),
                        child: Text(
                          c,
                          style: const TextStyle(
                            fontSize: ManiFontSize.caption,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, this.valor, this.child});

  final String etiqueta;
  final String? valor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ManiSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta.toUpperCase(),
            style: TextStyle(
              fontSize: ManiFontSize.micro,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: context.mani.inkSubtle,
            ),
          ),
          ManiGap.vXs,
          child ??
              Text(
                valor ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.mani.ink,
                ),
              ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.icono,
    required this.child,
  });

  final String titulo;
  final IconData icono;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icono, size: 18, color: context.mani.ink),
            ManiGap.hSm,
            Text(
              titulo,
              style: const TextStyle(
                fontSize: ManiFontSize.body,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        ManiGap.vSm,
        child,
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.color, required this.texto});

  final IconData icono;
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: color, width: ManiBorder.thin),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 20),
          ManiGap.hSm,
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: ManiFontSize.bodySm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado({required this.aliado});

  final SolicitudAliado aliado;

  @override
  Widget build(BuildContext context) {
    final estado = aliado.estado;
    final fecha = aliado.fechaVerificacion;
    final aprobado = estado == EstadoVerificacion.aprobado;
    return Container(
      key: const ValueKey('resultado-verificacion'),
      padding: const EdgeInsets.all(ManiSpace.lg),
      decoration: BoxDecoration(
        color: estado.fondo,
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
              Icon(estado.icono, color: estado.acento),
              ManiGap.hSm,
              Expanded(
                child: Text(
                  [
                    aprobado ? 'Aliado aprobado' : 'Aliado rechazado',
                    if (fecha != null) 'el ${fechaCorta(fecha)}',
                  ].join(' '),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: estado.acento,
                  ),
                ),
              ),
            ],
          ),
          if (!aprobado && (aliado.motivoRechazo ?? '').isNotEmpty) ...[
            ManiGap.vSm,
            const Text(
              'Motivo enviado al aliado:',
              style: TextStyle(
                fontSize: ManiFontSize.caption,
                fontWeight: FontWeight.w800,
              ),
            ),
            ManiGap.vXs,
            Text(aliado.motivoRechazo!),
          ],
        ],
      ),
    );
  }
}

class _BarraAcciones extends StatelessWidget {
  const _BarraAcciones({
    required this.procesando,
    required this.puedeAprobar,
    required this.puedeRechazar,
    required this.onAprobar,
    required this.onRechazar,
  });

  final bool procesando;
  final bool puedeAprobar;
  final bool puedeRechazar;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ManiSpace.xxl,
        ManiSpace.lg,
        ManiSpace.xxl,
        ManiSpace.lg,
      ),
      decoration: BoxDecoration(
        color: context.mani.surface,
        border: Border(top: ManiBorder.side),
      ),
      child: SafeArea(
        top: false,
        child: procesando
            ? SizedBox(
                height: 48,
                child: Row(
                  key: ValueKey('guardando-decision'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: context.mani.ink,
                      ),
                    ),
                    ManiGap.hMd,
                    Text(
                      'Guardando decisión…',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: ManiButton(
                      key: const ValueKey('btn-rechazar'),
                      etiqueta: 'Rechazar',
                      icono: Icons.close_rounded,
                      variante: ManiButtonVariante.peligro,
                      expandir: true,
                      onPressed: puedeRechazar ? onRechazar : null,
                    ),
                  ),
                  ManiGap.hMd,
                  Expanded(
                    child: ManiButton(
                      key: const ValueKey('btn-aprobar'),
                      etiqueta: 'Aprobar',
                      icono: Icons.check_rounded,
                      expandir: true,
                      onPressed: puedeAprobar ? onAprobar : null,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
