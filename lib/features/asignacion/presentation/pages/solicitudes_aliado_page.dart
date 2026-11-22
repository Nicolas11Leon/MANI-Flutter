import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/shell/al_cambiar_visibilidad.dart';
import 'package:mani/core/shell/app_shell.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_esqueleto.dart';
import 'package:mani/core/widgets/mani_estados.dart';
import 'package:mani/core/widgets/mani_personaje.dart';
import 'package:mani/core/widgets/mani_snackbar.dart';
import 'package:mani/features/services/ratings/data/calificacion_cierre_datasource.dart';
import 'package:mani/features/services/ratings/presentation/calificacion_cierre_cubit.dart';
import 'package:mani/features/services/ratings/presentation/calificacion_cierre_widgets.dart';

import '../../domain/failures/asignacion_failure.dart';
import '../bloc/solicitudes_aliado_cubit.dart';
import '../widgets/dialogo_rechazo.dart';
import '../widgets/solicitud_card.dart';

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
    _programarRefresco();
  }

  void _refrescar() {
    final cubit = context.read<SolicitudesAliadoCubit>();
    if (!cubit.state.procesando) {
      cubit.cargar(silencioso: true);
    }
  }

  void _programarRefresco() {
    _refresco?.cancel();
    final intervalo = widget.intervaloRefresco;
    _refresco = intervalo == null
        ? null
        : Timer.periodic(intervalo, (_) => _refrescar());
  }

  /// Con la bandeja oculta (otra pestaña, otra pantalla encima o la app en segundo plano) no se consulta. Al volver se
  /// pone al día de una vez, sin esperar al siguiente ciclo.
  void _alCambiarVisibilidad(bool visible) {
    if (widget.intervaloRefresco == null) return;
    if (visible) {
      _refrescar();
      _programarRefresco();
    } else {
      _refresco?.cancel();
      _refresco = null;
    }
  }

  @override
  void dispose() {
    _refresco?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlCambiarVisibilidad(
      alCambiar: _alCambiarVisibilidad,
      child: _contenido(context),
    );
  }

  Widget _contenido(BuildContext context) {
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
                      builder: (context, state) => switch (state.carga) {
                        CargaSolicitudes.inicial ||
                        CargaSolicitudes.cargando => Padding(
                          padding: const EdgeInsets.all(16),
                          child: ManiEsqueleto.tarjetas(),
                        ),
                        CargaSolicitudes.error => _ErrorCarga(
                          falla: state.error,
                          onReintentar: () =>
                              context.read<SolicitudesAliadoCubit>().cargar(),
                        ),
                        CargaSolicitudes.listo => _Bandeja(
                          onAbrirCobertura: widget.onAbrirCobertura,
                          onAbrirCategorias: widget.onAbrirCategorias,
                          onCotizar: widget.onCotizar,
                        ),
                      },
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _Pestanas(
                    seleccionada: state.pestana,
                    disponibles: state.bandeja.disponibles.length,
                    misTrabajos: state.bandeja.misTrabajos.length,
                    onCambiar: cubit.cambiarPestana,
                  ),
                  const SizedBox(height: 14),
                  if (enDisponibles && visibles.isNotEmpty) ...[
                    const _ComoFunciona(),
                    const SizedBox(height: 14),
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
                      const SizedBox(height: 14),
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
            customBorder: const StadiumBorder(),
            onTap: () => onCambiar(p),
            child: AnimatedContainer(
              duration: ManiMotion.fast,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activa ? ManiColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(ManiRadius.pill),
                border: activa
                    ? Border.all(color: ManiColors.ink, width: ManiBorder.thin)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      etiqueta,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: activa ? FontWeight.w800 : FontWeight.w600,
                        color: activa ? ManiColors.ink : ManiColors.inkMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$n',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: activa ? ManiColors.ink : ManiColors.inkMuted,
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
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ManiColors.surfaceMuted,
        borderRadius: BorderRadius.circular(ManiRadius.pill),
      ),
      child: Row(
        children: [
          pestana(PestanaSolicitudes.disponibles, 'Disponibles', disponibles),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ManiColors.warningContainer,
        borderRadius: BorderRadius.circular(ManiRadius.md),
      ),
      child: const Row(
        children: [
          Icon(Icons.bolt_rounded, color: ManiColors.warningText),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Estas solicitudes se ofrecen a varios aliados a la vez: '
              'el primero en aceptar se queda con el trabajo.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ManiColors.warningText,
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
      pose: PoseMani.descansando,
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
    pose: PoseMani.buscando,
    titulo: 'Aún no tienes trabajos',
    texto: 'Cuando aceptes una solicitud aparecerá aquí con la dirección.',
  );
}

class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.pose,
    required this.titulo,
    required this.texto,
    this.acciones = const [],
  });

  final PoseMani pose;
  final String titulo;
  final String texto;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return ManiEstadoVacio(
      pose: pose,
      titulo: titulo,
      texto: texto,
      accion: acciones.isEmpty
          ? null
          : Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: acciones,
            ),
    );
  }
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

  void _abrirHistorial(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
          child: BlocProvider(
            create: (_) =>
                HistorialServiciosCubit(sl<FuenteModuloM08>(), esAliado: true)
                  ..cargar(),
            child: const HistorialServiciosPage(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // En celular el nombre de la pantalla y sus accesos viven en la barra del armazón (menú «⋮»).
    if (MediaQuery.sizeOf(context).width < anchoMenuExpandido) {
      return TituloDePantalla(
        titulo: 'Solicitudes',
        acciones: [
          if (onAbrirCobertura != null)
            AccionDePantalla(
              clave: const ValueKey('btn-ir-cobertura'),
              icono: Icons.map_outlined,
              etiqueta: 'Mis zonas',
              alTocar: onAbrirCobertura!,
            ),
          if (onAbrirCategorias != null)
            AccionDePantalla(
              clave: const ValueKey('btn-ir-especialidades'),
              icono: Icons.handyman_outlined,
              etiqueta: 'Mis especialidades',
              alTocar: onAbrirCategorias!,
            ),
          if (onAbrirDisponibilidad != null)
            AccionDePantalla(
              clave: const ValueKey('btn-ir-disponibilidad'),
              icono: Icons.event_busy_outlined,
              etiqueta: 'Mi disponibilidad',
              alTocar: onAbrirDisponibilidad!,
            ),
          if (sl.isRegistered<FuenteModuloM08>())
            AccionDePantalla(
              clave: const ValueKey('btn-ir-historial-aliado'),
              icono: Icons.history_rounded,
              etiqueta: 'Historial',
              alTocar: () => _abrirHistorial(context),
            ),
        ],
      );
    }
    final puedeVolver = Navigator.of(context).canPop();
    return Container(
      decoration: const BoxDecoration(
        color: ManiColors.surface,
        border: Border(bottom: BorderSide(color: ManiColors.ink, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (puedeVolver) ...[
            IconButton(
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, color: ManiColors.ink),
            ),
            const SizedBox(width: 4),
          ],
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ManiColors.brand,
              borderRadius: BorderRadius.circular(ManiRadius.lg),
              border: Border.all(color: ManiColors.ink, width: 2),
              boxShadow: const [ManiShadow.sm],
            ),
            child: const Icon(
              Icons.handyman_rounded,
              color: ManiColors.ink,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Solicitudes',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ManiColors.ink,
                  ),
                ),
                Text(
                  'Panel del aliado',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ManiColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
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
              icon: const Icon(
                Icons.event_busy_outlined,
                color: ManiColors.ink,
              ),
            ),
          if (sl.isRegistered<FuenteModuloM08>())
            IconButton(
              key: const ValueKey('btn-ir-historial-aliado'),
              tooltip: 'Historial de trabajos',
              onPressed: () => _abrirHistorial(context),
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
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.falla, required this.onReintentar});

  final AsignacionFailure? falla;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final enRevision = falla?.tipo == AsignacionErrorTipo.aliadoNoVerificado;
    return Center(
      child: SingleChildScrollView(
        child: ManiEstadoVacio(
          pose: enRevision ? PoseMani.trabajando : PoseMani.ups,
          titulo: enRevision
              ? 'Estamos revisando tu cuenta'
              : 'Algo no salió bien',
          texto: falla?.mensajeUsuario ?? 'No pudimos cargar tus solicitudes.',
          accion: ManiButton(
            key: const ValueKey('btn-reintentar-solicitudes'),
            etiqueta: 'Reintentar',
            icono: Icons.refresh_rounded,
            onPressed: onReintentar,
          ),
        ),
      ),
    );
  }
}
