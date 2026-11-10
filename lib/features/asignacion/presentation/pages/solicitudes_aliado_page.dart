import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_pagina.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_snackbar.dart';
import 'package:mani/features/services/ratings/data/calificacion_cierre_datasource.dart';
import 'package:mani/features/services/ratings/presentation/calificacion_cierre_cubit.dart';
import 'package:mani/features/services/ratings/presentation/calificacion_cierre_widgets.dart';

import '../../domain/failures/asignacion_failure.dart';
import '../bloc/solicitudes_aliado_cubit.dart';
import '../widgets/dialogo_rechazo.dart';
import '../widgets/solicitud_card.dart';
import 'package:mani/core/widgets/mani_estado.dart';

/// US-04.1.4 — Bandeja de solicitudes del aliado: aceptar o rechazar sin
/// doble asignación. Requiere un [SolicitudesAliadoCubit] en el contexto.
///
/// Los accesos a cobertura y categorías los inyecta quien compone la
/// navegación (el router), para que esta feature no conozca otras rutas.
class SolicitudesAliadoPage extends StatefulWidget {
  const SolicitudesAliadoPage({
    super.key,
    this.onAbrirCobertura,
    this.onAbrirCategorias,
    this.onAbrirDisponibilidad,
    this.onCotizar,
    this.intervaloRefresco = const Duration(seconds: 30),
  });

  final VoidCallback? onAbrirCobertura;
  final VoidCallback? onAbrirCategorias;
  final VoidCallback? onAbrirDisponibilidad;

  /// Abre la cotización de una solicitud ya asignada al aliado (SCRUM-865).
  final void Function(String solicitudId)? onCotizar;

  /// Cada cuánto se refresca la bandeja para no ofrecer solicitudes que otro
  /// aliado ya tomó. `null` desactiva el refresco (tests).
  final Duration? intervaloRefresco;

  @override
  State<SolicitudesAliadoPage> createState() => _SolicitudesAliadoPageState();
}

class _SolicitudesAliadoPageState extends State<SolicitudesAliadoPage> {
  Timer? _refresco;

  @override
  void initState() {
    super.initState();
    final intervalo = widget.intervaloRefresco;
    if (intervalo != null) {
      _refresco = Timer.periodic(intervalo, (_) {
        final cubit = context.read<SolicitudesAliadoCubit>();
        if (!cubit.state.procesando) {
          cubit.cargar(silencioso: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _refresco?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SolicitudesAliadoCubit, SolicitudesAliadoState>(
      listenWhen: (antes, ahora) =>
          ahora.aviso != null && antes.aviso != ahora.aviso,
      listener: (context, state) => showManiSnackBar(
        context,
        state.aviso!.mensaje,
        esError: state.aviso!.tipo == TipoAviso.error,
      ),
      child: Scaffold(
        backgroundColor: ManiColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _BarraSuperior(
                onAbrirCobertura: widget.onAbrirCobertura,
                onAbrirCategorias: widget.onAbrirCategorias,
                onAbrirDisponibilidad: widget.onAbrirDisponibilidad,
              ),
              Expanded(
                child:
                    BlocBuilder<SolicitudesAliadoCubit, SolicitudesAliadoState>(
                      buildWhen: (a, b) => a.carga != b.carga,
                      // Esqueleto mientras carga y transición suave al
                      // contenido o al error (sin saltos de layout).
                      builder: (context, state) => ManiTransicionEstado(
                        child: switch (state.carga) {
                          CargaSolicitudes.inicial ||
                          CargaSolicitudes.cargando => const Padding(
                            key: ValueKey('carga'),
                            padding: EdgeInsets.all(ManiSpace.lg),
                            child: ManiSkeletonLista(),
                          ),
                          CargaSolicitudes.error => _ErrorCarga(
                            key: const ValueKey('error'),
                            falla: state.error,
                            onReintentar: () =>
                                context.read<SolicitudesAliadoCubit>().cargar(),
                          ),
                          CargaSolicitudes.listo => _Bandeja(
                            key: const ValueKey('listo'),
                            onAbrirCobertura: widget.onAbrirCobertura,
                            onAbrirCategorias: widget.onAbrirCategorias,
                            onCotizar: widget.onCotizar,
                          ),
                        },
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bandeja extends StatelessWidget {
  const _Bandeja({
    super.key,
    this.onAbrirCobertura,
    this.onAbrirCategorias,
    this.onCotizar,
  });

  final VoidCallback? onAbrirCobertura;
  final VoidCallback? onAbrirCategorias;
  final void Function(String solicitudId)? onCotizar;

  Future<void> _rechazar(BuildContext context, String id) async {
    final cubit = context.read<SolicitudesAliadoCubit>();
    final solicitud = cubit.state.bandeja.porId(id);
    if (solicitud == null) {
      return;
    }
    final confirmacion = await confirmarRechazo(context, solicitud);
    if (confirmacion != null) {
      await cubit.rechazar(
        id,
        motivo: confirmacion.motivo,
        detalle: confirmacion.detalle,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SolicitudesAliadoCubit>();
    return BlocBuilder<SolicitudesAliadoCubit, SolicitudesAliadoState>(
      builder: (context, state) {
        final visibles = state.visibles;
        final enDisponibles = state.pestana == PestanaSolicitudes.disponibles;
        return RefreshIndicator(
          color: ManiColors.ink,
          backgroundColor: ManiColors.brand,
          onRefresh: () => cubit.cargar(silencioso: true),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                key: PageStorageKey('solicitudes-${state.pestana.name}'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  ManiSpace.xl,
                  ManiSpace.xl,
                  ManiSpace.xl,
                  ManiSpace.xxxl,
                ),
                children: [
                  _Pestanas(
                    seleccionada: state.pestana,
                    disponibles: state.bandeja.disponibles.length,
                    misTrabajos: state.bandeja.misTrabajos.length,
                    onCambiar: cubit.cambiarPestana,
                  ),
                  ManiGap.vMd,
                  if (enDisponibles && visibles.isNotEmpty) ...[
                    const _ComoFunciona(),
                    ManiGap.vMd,
                  ],
                  if (visibles.isEmpty)
                    enDisponibles
                        ? _SinDisponibles(
                            onAbrirCobertura: onAbrirCobertura,
                            onAbrirCategorias: onAbrirCategorias,
                          )
                        : const _SinTrabajos()
                  else
                    for (final s in visibles) ...[
                      SolicitudCard(
                        solicitud: s,
                        recienAsignada: s.id == state.recienAsignadaId,
                        accionEnCurso: state.procesandoId == s.id
                            ? state.accion
                            : null,
                        bloqueada: state.procesando,
                        onAceptar: () => cubit.aceptar(s.id),
                        onRechazar: () => _rechazar(context, s.id),
                        onCotizar: onCotizar == null
                            ? null
                            : () => onCotizar!(s.id),
                      ),
                      ManiGap.vMd,
                    ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Pestanas extends StatelessWidget {
  const _Pestanas({
    required this.seleccionada,
    required this.disponibles,
    required this.misTrabajos,
    required this.onCambiar,
  });

  final PestanaSolicitudes seleccionada;
  final int disponibles;
  final int misTrabajos;
  final ValueChanged<PestanaSolicitudes> onCambiar;

  @override
  Widget build(BuildContext context) {
    Widget pestana(PestanaSolicitudes p, String etiqueta, int n) {
      final activa = p == seleccionada;
      return Expanded(
        child: Semantics(
          selected: activa,
          button: true,
          label: '$etiqueta: $n',
          excludeSemantics: true,
          child: InkWell(
            key: ValueKey('tab-${p.name}'),
            onTap: () => onCambiar(p),
            child: AnimatedContainer(
              duration: ManiMotion.fast,
              height: 50,
              color: activa ? ManiColors.brand : ManiColors.surface,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      etiqueta,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ManiFontSize.bodySm,
                        fontWeight: FontWeight.w800,
                        color: activa ? ManiColors.ink : ManiColors.inkMuted,
                      ),
                    ),
                  ),
                  ManiGap.hSm,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ManiSpace.sm,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: activa ? ManiColors.ink : ManiColors.background,
                      borderRadius: ManiRadius.brPill,
                    ),
                    child: Text(
                      '$n',
                      style: TextStyle(
                        fontSize: ManiFontSize.caption,
                        fontWeight: FontWeight.w900,
                        color: activa ? ManiColors.brand : ManiColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ManiColors.surface,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
        boxShadow: const [ManiShadow.sm],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          pestana(PestanaSolicitudes.disponibles, 'Disponibles', disponibles),
          Container(width: 2, height: 50, color: ManiColors.ink),
          pestana(PestanaSolicitudes.misTrabajos, 'Mis trabajos', misTrabajos),
        ],
      ),
    );
  }
}

/// Explica la regla de asignación para que un "ya no disponible" no sorprenda.
class _ComoFunciona extends StatelessWidget {
  const _ComoFunciona();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: ManiColors.brandSoft,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: ManiColors.border, width: ManiBorder.thin),
      ),
      child: const Row(
        children: [
          Icon(Icons.bolt_rounded, color: ManiColors.ink),
          ManiGap.hSm,
          Expanded(
            child: Text(
              'Estas solicitudes se ofrecen a varios aliados a la vez: '
              'el primero en aceptar se queda con el trabajo.',
              style: TextStyle(
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

class _SinDisponibles extends StatelessWidget {
  const _SinDisponibles({this.onAbrirCobertura, this.onAbrirCategorias});

  final VoidCallback? onAbrirCobertura;
  final VoidCallback? onAbrirCategorias;

  @override
  Widget build(BuildContext context) {
    return _Vacio(
      icono: Icons.inbox_outlined,
      titulo: 'No hay solicitudes nuevas',
      texto:
          'Aquí aparecerán las solicitudes de tus especialidades en tus zonas '
          'de cobertura. Revisa que estén al día para recibir más.',
      acciones: [
        if (onAbrirCobertura != null)
          ManiButton(
            key: const ValueKey('btn-vacio-cobertura'),
            etiqueta: 'Mis zonas',
            icono: Icons.map_outlined,
            variante: ManiButtonVariante.secundario,
            onPressed: onAbrirCobertura,
          ),
        if (onAbrirCategorias != null)
          ManiButton(
            key: const ValueKey('btn-vacio-categorias'),
            etiqueta: 'Mis especialidades',
            icono: Icons.handyman_outlined,
            variante: ManiButtonVariante.secundario,
            onPressed: onAbrirCategorias,
          ),
      ],
    );
  }
}

class _SinTrabajos extends StatelessWidget {
  const _SinTrabajos();

  @override
  Widget build(BuildContext context) => const _Vacio(
    icono: Icons.work_outline_rounded,
    titulo: 'Aún no tienes trabajos',
    texto: 'Cuando aceptes una solicitud aparecerá aquí con la dirección.',
  );
}

class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.icono,
    required this.titulo,
    required this.texto,
    this.acciones = const [],
  });

  final IconData icono;
  final String titulo;
  final String texto;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) => ManiEstadoVacio(
    icono: icono,
    titulo: titulo,
    texto: texto,
    acciones: acciones,
  );
}

class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior({
    this.onAbrirCobertura,
    this.onAbrirCategorias,
    this.onAbrirDisponibilidad,
  });

  final VoidCallback? onAbrirCobertura;
  final VoidCallback? onAbrirCategorias;
  final VoidCallback? onAbrirDisponibilidad;

  @override
  Widget build(BuildContext context) {
    return ManiBarraPagina(
      icono: Icons.handyman_rounded,
      titulo: 'Solicitudes de servicio',
      descripcion: 'Panel del aliado',
      acciones: [
        if (onAbrirCobertura != null)
          IconButton(
            key: const ValueKey('btn-ir-cobertura'),
            tooltip: 'Mis zonas de cobertura',
            onPressed: onAbrirCobertura,
            icon: const Icon(Icons.map_outlined, color: ManiColors.ink),
          ),
        if (onAbrirCategorias != null)
          IconButton(
            key: const ValueKey('btn-ir-especialidades'),
            tooltip: 'Mis especialidades',
            onPressed: onAbrirCategorias,
            icon: const Icon(Icons.handyman_outlined, color: ManiColors.ink),
          ),
        if (onAbrirDisponibilidad != null)
          IconButton(
            key: const ValueKey('btn-ir-disponibilidad'),
            tooltip: 'Mi disponibilidad',
            onPressed: onAbrirDisponibilidad,
            icon: const Icon(Icons.event_busy_outlined, color: ManiColors.ink),
          ),
        if (sl.isRegistered<FuenteModuloM08>())
          IconButton(
            key: const ValueKey('btn-ir-historial-aliado'),
            tooltip: 'Historial de trabajos',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 720,
                    maxHeight: 620,
                  ),
                  child: BlocProvider(
                    create: (_) => HistorialServiciosCubit(
                      sl<FuenteModuloM08>(),
                      esAliado: true,
                    )..cargar(),
                    child: const HistorialServiciosPage(),
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.history_rounded, color: ManiColors.ink),
          ),
        IconButton(
          key: const ValueKey('btn-actualizar-solicitudes'),
          tooltip: 'Actualizar',
          onPressed: () =>
              context.read<SolicitudesAliadoCubit>().cargar(silencioso: true),
          icon: const Icon(Icons.refresh_rounded, color: ManiColors.ink),
        ),
      ],
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({
    super.key,
    required this.falla,
    required this.onReintentar,
  });

  final AsignacionFailure? falla;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final enRevision = falla?.tipo == AsignacionErrorTipo.aliadoNoVerificado;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ManiSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enRevision
                  ? Icons.hourglass_top_rounded
                  : Icons.cloud_off_rounded,
              size: 48,
              color: ManiColors.ink,
            ),
            ManiGap.vMd,
            Text(
              falla?.mensajeUsuario ?? 'No pudimos cargar tus solicitudes.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            ManiGap.vLg,
            ManiButton(
              key: const ValueKey('btn-reintentar-solicitudes'),
              etiqueta: 'Reintentar',
              icono: Icons.refresh_rounded,
              onPressed: onReintentar,
            ),
          ],
        ),
      ),
    );
  }
}
