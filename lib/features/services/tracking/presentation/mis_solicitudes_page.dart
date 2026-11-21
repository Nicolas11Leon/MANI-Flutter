import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';
import 'package:mani/features/services/ratings/data/calificacion_cierre_datasource.dart';
import 'package:mani/features/services/ratings/domain/calificacion_cierre_modelos.dart';
import 'package:mani/features/services/ratings/presentation/calificacion_cierre_cubit.dart';
import 'package:mani/features/services/ratings/presentation/calificacion_cierre_widgets.dart';

import '../domain/solicitud_seguimiento.dart';
import 'mis_solicitudes_cubit.dart';

/// Categorías de solicitudes mostradas en pestañas y secciones.
enum _CategoriaSolicitud {
  todas('Todas', Icons.apps_rounded),
  publicadas('Publicadas', Icons.campaign_outlined),
  enCurso('En curso', Icons.autorenew_rounded),
  finalizadas('Finalizadas', Icons.task_alt_rounded),
  canceladas('Canceladas', Icons.cancel_outlined);

  const _CategoriaSolicitud(this.etiqueta, this.icono);
  final String etiqueta;
  final IconData icono;
}

_CategoriaSolicitud _categoriaDe(EstadoSeguimiento estado) => switch (estado) {
  EstadoSeguimiento.pendiente => _CategoriaSolicitud.publicadas,
  EstadoSeguimiento.finalizada => _CategoriaSolicitud.finalizadas,
  EstadoSeguimiento.cancelada => _CategoriaSolicitud.canceladas,
  EstadoSeguimiento.asignada ||
  EstadoSeguimiento.cotizando ||
  EstadoSeguimiento.aceptada ||
  EstadoSeguimiento.rechazada ||
  EstadoSeguimiento.enEjecucion ||
  EstadoSeguimiento.otro => _CategoriaSolicitud.enCurso,
};

/// Mis solicitudes (HU-M07-04 / SCRUM-871) unificada con el Historial de
/// servicios (SCRUM-879):
/// - Divide las solicitudes por tipo (Publicadas, En curso, Finalizadas,
///   Canceladas) mediante pestañas y secciones.
/// - Pagina el listado en pestañas numéricas (`1, 2, ... >`) para evitar
///   listas infinitas.
/// - Integra el panel de Historial y permite acceder al detalle del servicio
///   desde cualquier solicitud.
class MisSolicitudesPage extends StatefulWidget {
  const MisSolicitudesPage({
    super.key,
    this.onNuevaSolicitud,
    this.onVerCotizacion,
    this.onVerAliados,
    this.onPresentarQueja,
    this.previsualizarCancelacion,
    this.fuenteHistorial,
    this.itemsPorPagina = 6,
  });

  final VoidCallback? onNuevaSolicitud;

  /// Presenta una queja sobre el servicio (HU-M12-01 / SCRUM-895). Solo se
  /// ofrece cuando la solicitud ya tuvo aliado; Core vuelve a validarlo.
  final void Function(String solicitudId)? onPresentarQueja;

  /// Consulta a Core la penalización que tendría cancelar (SCRUM-878) para
  /// mostrarla antes de confirmar. Sin ella el diálogo no muestra el resumen.
  final Future<VistaPreviaPenalizacion> Function(String solicitudId)?
  previsualizarCancelacion;

  /// Abre el detalle / cotización de la solicitud (`/cliente/solicitudes/:id/cotizacion`).
  final void Function(String solicitudId)? onVerCotizacion;

  /// Abre los aliados elegibles de una solicitud pendiente (SCRUM-1401).
  final void Function(String solicitudId)? onVerAliados;

  /// Fuente opcional para el historial unificado (si no se inyecta, usa `sl`
  /// cuando está registrado).
  final FuenteModuloM08? fuenteHistorial;

  /// Cantidad máxima de solicitudes por página antes de mostrar pestañas de
  /// paginación (`1, 2, ... >`).
  final int itemsPorPagina;

  @override
  State<MisSolicitudesPage> createState() => _MisSolicitudesPageState();
}

class _MisSolicitudesPageState extends State<MisSolicitudesPage> {
  _CategoriaSolicitud _filtro = _CategoriaSolicitud.todas;
  int _paginaActual = 1;
  HistorialServiciosCubit? _historialCubit;

  FuenteModuloM08? get _fuenteM08 =>
      widget.fuenteHistorial ??
      (sl.isRegistered<FuenteModuloM08>() ? sl<FuenteModuloM08>() : null);

  @override
  void initState() {
    super.initState();
    final fuente = _fuenteM08;
    if (fuente != null) {
      _historialCubit = HistorialServiciosCubit(fuente, esAliado: false)
        ..cargar();
    }
  }

  @override
  void dispose() {
    _historialCubit?.close();
    super.dispose();
  }

  Future<void> _actualizarTodo(MisSolicitudesCubit cubit) async {
    await Future.wait([
      cubit.cargar(),
      if (_historialCubit != null) _historialCubit!.cargar(),
    ]);
  }

  void _cambiarFiltro(_CategoriaSolicitud nuevo) {
    setState(() {
      _filtro = nuevo;
      _paginaActual = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return BlocBuilder<MisSolicitudesCubit, MisSolicitudesState>(
      builder: (context, state) {
        final cubit = context.read<MisSolicitudesCubit>();
        final todas = state.solicitudes;
        final filtradas = _filtro == _CategoriaSolicitud.todas
            ? todas
            : todas.where((s) => _categoriaDe(s.estado) == _filtro).toList();

        final totalPaginas = math.max(
          1,
          (filtradas.length / widget.itemsPorPagina).ceil(),
        );
        final paginaSegura = _paginaActual.clamp(1, totalPaginas);
        final inicio = (paginaSegura - 1) * widget.itemsPorPagina;
        final fin = math.min(inicio + widget.itemsPorPagina, filtradas.length);
        final enPagina = filtradas.isEmpty
            ? const <SolicitudSeguimiento>[]
            : filtradas.sublist(inicio, fin);

        return ColoredBox(
          color: t.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Encabezado(
                state: state,
                onActualizar: () => _actualizarTodo(cubit),
                onNuevaSolicitud: widget.onNuevaSolicitud,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: t.onBrand,
                  backgroundColor: t.brand,
                  onRefresh: () => _actualizarTodo(cubit),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final esAmplio =
                          constraints.maxWidth >= 980 &&
                          _historialCubit != null;
                      final columnaSolicitudes = _construirColumnaSolicitudes(
                        context,
                        cubit: cubit,
                        state: state,
                        todas: todas,
                        filtradas: filtradas,
                        enPagina: enPagina,
                        paginaActual: paginaSegura,
                        totalPaginas: totalPaginas,
                      );

                      if (!esAmplio) {
                        return ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ManiSpace.xxl,
                            vertical: ManiSpace.xl,
                          ),
                          children: [
                            ...columnaSolicitudes,
                            if (_historialCubit != null) ...[
                              ManiGap.vXxl,
                              BlocProvider.value(
                                value: _historialCubit!,
                                child: HistorialServiciosPage(
                                  embebido: true,
                                  onAbrirServicio: widget.onVerCotizacion,
                                ),
                              ),
                            ],
                          ],
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ManiSpace.xxl,
                          vertical: ManiSpace.xl,
                        ),
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: columnaSolicitudes,
                                ),
                              ),
                              ManiGap.hXxl,
                              Expanded(
                                flex: 4,
                                child: BlocProvider.value(
                                  value: _historialCubit!,
                                  child: HistorialServiciosPage(
                                    embebido: true,
                                    onAbrirServicio: widget.onVerCotizacion,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _construirColumnaSolicitudes(
    BuildContext context, {
    required MisSolicitudesCubit cubit,
    required MisSolicitudesState state,
    required List<SolicitudSeguimiento> todas,
    required List<SolicitudSeguimiento> filtradas,
    required List<SolicitudSeguimiento> enPagina,
    required int paginaActual,
    required int totalPaginas,
  }) {
    final t = context.mani;
    return [
      const _AvisoZona(),
      ManiGap.vLg,
      if (state.error != null) ...[
        _Error(mensaje: state.error!, onReintentar: cubit.cargar),
        ManiGap.vLg,
      ],
      if (state.cargando && todas.isEmpty)
        const Padding(
          padding: EdgeInsets.all(ManiSpace.xxxl),
          child: ManiCargando(),
        )
      else if (todas.isEmpty && state.error == null)
        _Vacio(onNuevaSolicitud: widget.onNuevaSolicitud)
      else ...[
        _BarraPestanasCategoria(
          activa: _filtro,
          solicitudes: todas,
          onSeleccionar: _cambiarFiltro,
        ),
        ManiGap.vLg,
        if (enPagina.isEmpty)
          ManiCard(
            color: t.surfaceMuted,
            sombra: t.shadowSm,
            padding: const EdgeInsets.all(ManiSpace.xxl),
            child: Text(
              'No tienes solicitudes en la sección «${_filtro.etiqueta}».',
              key: const Key('seguimiento-seccion-vacia'),
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, color: t.inkMuted),
            ),
          )
        else if (_filtro == _CategoriaSolicitud.todas)
          ..._construirSeccionesAgrupadas(context, cubit, state, enPagina)
        else
          _construirSeccionUnica(context, cubit, state, _filtro, enPagina),
        ManiGap.vXl,
        _BarraPaginacion(
          paginaActual: paginaActual,
          totalPaginas: totalPaginas,
          totalItems: filtradas.length,
          onCambiarPagina: (p) => setState(() => _paginaActual = p),
        ),
      ],
    ];
  }

  List<Widget> _construirSeccionesAgrupadas(
    BuildContext context,
    MisSolicitudesCubit cubit,
    MisSolicitudesState state,
    List<SolicitudSeguimiento> items,
  ) {
    const orden = [
      _CategoriaSolicitud.publicadas,
      _CategoriaSolicitud.enCurso,
      _CategoriaSolicitud.finalizadas,
      _CategoriaSolicitud.canceladas,
    ];
    final widgets = <Widget>[];
    for (final cat in orden) {
      final grupo = items.where((s) => _categoriaDe(s.estado) == cat).toList();
      if (grupo.isEmpty) continue;
      if (widgets.isNotEmpty) widgets.add(ManiGap.vXl);
      widgets.add(_construirSeccionUnica(context, cubit, state, cat, grupo));
    }
    return widgets;
  }

  Widget _construirSeccionUnica(
    BuildContext context,
    MisSolicitudesCubit cubit,
    MisSolicitudesState state,
    _CategoriaSolicitud categoria,
    List<SolicitudSeguimiento> items,
  ) {
    final tituloSeccion = switch (categoria) {
      _CategoriaSolicitud.publicadas => 'Solicitudes publicadas',
      _CategoriaSolicitud.enCurso => 'Solicitudes en curso',
      _CategoriaSolicitud.finalizadas => 'Solicitudes finalizadas',
      _CategoriaSolicitud.canceladas => 'Solicitudes canceladas',
      _CategoriaSolicitud.todas => 'Todas las solicitudes',
    };
    return Column(
      key: Key('seccion-solicitudes-${categoria.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ManiTituloSeccion(icono: categoria.icono, titulo: tituloSeccion),
        ManiGap.vMd,
        ManiRejilla(
          anchoMinimo: 300,
          maxColumnas: 2,
          espacio: ManiSpace.md,
          children: [
            for (final s in items) _construirTarjeta(context, cubit, state, s),
          ],
        ),
      ],
    );
  }

  Widget _construirTarjeta(
    BuildContext context,
    MisSolicitudesCubit cubit,
    MisSolicitudesState state,
    SolicitudSeguimiento s,
  ) {
    return _TarjetaSolicitud(
      s,
      onAbrirDetalle: widget.onVerCotizacion == null
          ? null
          : () => widget.onVerCotizacion!(s.id),
      onVerCotizacion: widget.onVerCotizacion == null || !s.tieneCotizacion
          ? null
          : () => widget.onVerCotizacion!(s.id),
      onVerAliados:
          widget.onVerAliados == null || s.estado != EstadoSeguimiento.pendiente
          ? null
          : () => widget.onVerAliados!(s.id),
      onPresentarQueja:
          widget.onPresentarQueja == null ||
              s.estado == EstadoSeguimiento.pendiente ||
              s.estado == EstadoSeguimiento.otro
          ? null
          : () => widget.onPresentarQueja!(s.id),
      cancelando: state.cancelandoId == s.id,
      onCancelar: !s.puedeCancelar || state.cancelandoId != null
          ? null
          : () => _confirmarCancelacion(
              context,
              cubit,
              s,
              widget.previsualizarCancelacion,
            ),
    );
  }
}

class _BarraPestanasCategoria extends StatelessWidget {
  const _BarraPestanasCategoria({
    required this.activa,
    required this.solicitudes,
    required this.onSeleccionar,
  });

  final _CategoriaSolicitud activa;
  final List<SolicitudSeguimiento> solicitudes;
  final ValueChanged<_CategoriaSolicitud> onSeleccionar;

  int _contar(_CategoriaSolicitud cat) {
    if (cat == _CategoriaSolicitud.todas) return solicitudes.length;
    return solicitudes.where((s) => _categoriaDe(s.estado) == cat).length;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final cat in _CategoriaSolicitud.values) ...[
            Padding(
              padding: const EdgeInsets.only(right: ManiSpace.sm),
              child: _PestanaFiltro(
                key: Key('tab-solicitudes-${cat.name}'),
                etiqueta: cat.etiqueta,
                icono: cat.icono,
                cantidad: _contar(cat),
                seleccionada: activa == cat,
                onTap: () => onSeleccionar(cat),
                t: t,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PestanaFiltro extends StatelessWidget {
  const _PestanaFiltro({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.cantidad,
    required this.seleccionada,
    required this.onTap,
    required this.t,
  });

  final String etiqueta;
  final IconData icono;
  final int cantidad;
  final bool seleccionada;
  final VoidCallback onTap;
  final ManiTokens t;

  @override
  Widget build(BuildContext context) {
    final fg = seleccionada ? t.onBrand : t.ink;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: seleccionada ? t.brand : t.surface,
        borderRadius: ManiRadius.brMd,
        border: Border.all(
          color: seleccionada ? t.border : t.borderSubtle,
          width: seleccionada ? ManiBorder.regular : ManiBorder.thin,
        ),
        boxShadow: seleccionada ? [t.shadowSm] : const [],
      ),
      child: InkWell(
        borderRadius: ManiRadius.brMd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ManiSpace.md,
            vertical: ManiSpace.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 16, color: fg),
              ManiGap.hXs,
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: ManiFontSize.bodySm,
                  fontWeight: seleccionada ? FontWeight.w900 : FontWeight.w700,
                  color: fg,
                ),
              ),
              ManiGap.hXs,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ManiSpace.xs,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: seleccionada ? t.surface : t.surfaceMuted,
                  borderRadius: ManiRadius.brPill,
                  border: Border.all(color: t.border, width: ManiBorder.thin),
                ),
                child: Text(
                  '$cantidad',
                  style: TextStyle(
                    fontSize: ManiFontSize.nano,
                    fontWeight: FontWeight.w900,
                    color: t.ink,
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

class _BarraPaginacion extends StatelessWidget {
  const _BarraPaginacion({
    required this.paginaActual,
    required this.totalPaginas,
    required this.totalItems,
    required this.onCambiarPagina,
  });

  final int paginaActual;
  final int totalPaginas;
  final int totalItems;
  final ValueChanged<int> onCambiarPagina;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return Row(
      key: const Key('paginacion-solicitudes'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _BotonPagina(
          key: const Key('pagina-solicitudes-anterior'),
          etiqueta: '‹',
          habilitado: paginaActual > 1,
          activo: false,
          onTap: () => onCambiarPagina(paginaActual - 1),
          t: t,
        ),
        ManiGap.hXs,
        for (var p = 1; p <= totalPaginas; p++) ...[
          _BotonPagina(
            key: Key('pagina-solicitudes-$p'),
            etiqueta: '$p',
            habilitado: true,
            activo: p == paginaActual,
            onTap: () => onCambiarPagina(p),
            t: t,
          ),
          ManiGap.hXs,
        ],
        _BotonPagina(
          key: const Key('pagina-solicitudes-siguiente'),
          etiqueta: '›',
          habilitado: paginaActual < totalPaginas,
          activo: false,
          onTap: () => onCambiarPagina(paginaActual + 1),
          t: t,
        ),
      ],
    );
  }
}

class _BotonPagina extends StatelessWidget {
  const _BotonPagina({
    super.key,
    required this.etiqueta,
    required this.habilitado,
    required this.activo,
    required this.onTap,
    required this.t,
  });

  final String etiqueta;
  final bool habilitado;
  final bool activo;
  final VoidCallback onTap;
  final ManiTokens t;

  @override
  Widget build(BuildContext context) {
    final fg = activo
        ? t.onBrand
        : habilitado
        ? t.ink
        : t.inkSubtle;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: activo ? t.brand : t.surface,
        borderRadius: ManiRadius.brSm,
        border: Border.all(
          color: activo ? t.border : t.borderSubtle,
          width: activo ? ManiBorder.regular : ManiBorder.thin,
        ),
        boxShadow: activo ? [t.shadowSm] : const [],
      ),
      child: InkWell(
        borderRadius: ManiRadius.brSm,
        onTap: habilitado ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: ManiSpace.sm),
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: ManiFontSize.body,
              fontWeight: FontWeight.w900,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

/// QAS-08: cancelar es irreversible, así que se confirma antes y se ofrece
/// dejar un motivo opcional (queda en la línea de tiempo del servicio).
Future<void> _confirmarCancelacion(
  BuildContext context,
  MisSolicitudesCubit cubit,
  SolicitudSeguimiento solicitud,
  Future<VistaPreviaPenalizacion> Function(String)? previsualizar,
) async {
  final motivo = await showDialog<String>(
    context: context,
    builder: (_) => _DialogoCancelar(
      solicitud: solicitud,
      vistaPrevia: previsualizar?.call(solicitud.id),
    ),
  );
  if (motivo == null) return;
  final ok = await cubit.cancelar(solicitud.id, motivo: motivo);
  if (ok && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        key: Key('cancelacion-ok'),
        content: Text('Cancelaste la solicitud.'),
      ),
    );
  }
}

class _DialogoCancelar extends StatefulWidget {
  const _DialogoCancelar({required this.solicitud, this.vistaPrevia});

  final SolicitudSeguimiento solicitud;

  /// Penalización que tendría cancelar ahora (SCRUM-878), calculada por Core.
  final Future<VistaPreviaPenalizacion>? vistaPrevia;

  @override
  State<_DialogoCancelar> createState() => _DialogoCancelarState();
}

class _DialogoCancelarState extends State<_DialogoCancelar> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asignada = widget.solicitud.estado != EstadoSeguimiento.pendiente;
    return AlertDialog(
      key: const Key('dialogo-cancelar'),
      title: const Text('¿Cancelar la solicitud?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vas a cancelar «${widget.solicitud.categoria}». '
            'Esta acción no se puede deshacer.'
            '${asignada ? ' Le avisaremos al aliado asignado.' : ''}',
          ),
          if (widget.vistaPrevia != null) ...[
            ManiGap.vMd,
            FutureBuilder<VistaPreviaPenalizacion>(
              future: widget.vistaPrevia,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator(
                    key: Key('cancelar-penalizacion-cargando'),
                  );
                }
                if (snap.hasError || snap.data == null) {
                  return const Text(
                    'No pudimos calcular la penalización. Si cancelas, '
                    'se aplicará la política vigente de tu empresa.',
                    key: Key('cancelar-penalizacion-error'),
                  );
                }
                return ResumenPenalizacionCancelacionBanner(
                  preview: snap.data!,
                );
              },
            ),
          ],
          ManiGap.vMd,
          TextField(
            key: const Key('cancelar-motivo'),
            controller: _motivo,
            maxLength: 200,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('cancelar-volver'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
        FilledButton(
          key: const Key('cancelar-confirmar'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(_motivo.text.trim()),
          child: const Text('Sí, cancelar'),
        ),
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.state,
    required this.onActualizar,
    this.onNuevaSolicitud,
  });

  final MisSolicitudesState state;
  final Future<void> Function() onActualizar;
  final VoidCallback? onNuevaSolicitud;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    final consultado = state.consultadoEn;
    return ManiEncabezadoPantalla(
      ancho: ManiAncho.panel,
      icono: Icons.list_alt_rounded,
      titulo: 'Mis solicitudes',
      descripcion: consultado == null
          ? null
          : 'Consultado: ${formatearFecha(consultado)}',
      descripcionKey: const Key('seguimiento-consultado'),
      acciones: [
        if (onNuevaSolicitud != null)
          DecoratedBox(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: ManiRadius.brMd,
              border: Border.all(color: t.border, width: ManiBorder.regular),
              boxShadow: [t.shadowSm],
            ),
            child: TextButton.icon(
              key: const Key('seguimiento-publicar-header'),
              onPressed: onNuevaSolicitud,
              icon: Icon(Icons.add_rounded, size: 18, color: t.ink),
              label: Text(
                'Nueva solicitud',
                style: TextStyle(color: t.ink, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: t.brand,
            borderRadius: ManiRadius.brMd,
            border: Border.all(color: t.border, width: ManiBorder.regular),
            boxShadow: [t.shadowSm],
          ),
          child: TextButton.icon(
            key: const Key('seguimiento-actualizar'),
            onPressed: state.cargando ? null : onActualizar,
            icon: Icon(Icons.refresh, size: 18, color: t.onBrand),
            label: Text(
              'Actualizar',
              style: TextStyle(color: t.onBrand, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvisoZona extends StatelessWidget {
  const _AvisoZona();

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return Container(
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: t.surfaceWarm,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: t.border, width: ManiBorder.regular),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: t.ink),
          ManiGap.hSm,
          Expanded(
            child: Text(
              'La zona es la que indicaste al publicar la solicitud. '
              'No es la ubicación del aliado: MANI no rastrea su posición.',
              key: const Key('seguimiento-aviso-zona'),
              style: TextStyle(
                fontSize: ManiFontSize.bodySm,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaSolicitud extends StatelessWidget {
  const _TarjetaSolicitud(
    this.solicitud, {
    this.onAbrirDetalle,
    this.onVerCotizacion,
    this.onVerAliados,
    this.onPresentarQueja,
    this.onCancelar,
    this.cancelando = false,
  });

  final SolicitudSeguimiento solicitud;
  final VoidCallback? onAbrirDetalle;
  final VoidCallback? onVerCotizacion;

  /// Solo para solicitudes pendientes (SCRUM-1401).
  final VoidCallback? onVerAliados;

  /// Solo para solicitudes que ya tuvieron aliado (SCRUM-895).
  final VoidCallback? onPresentarQueja;

  /// Cancela antes de la ejecución (SCRUM-877); `null` si no se puede.
  final VoidCallback? onCancelar;
  final bool cancelando;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    final zona = solicitud.zonaCompleta;
    final mostrarVerDetalle = onAbrirDetalle != null && onVerCotizacion == null;
    return ManiCard(
      key: Key('seguimiento-${solicitud.id}'),
      padding: const EdgeInsets.all(ManiSpace.xl),
      onTap: onAbrirDetalle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  solicitud.categoria,
                  style: TextStyle(
                    fontSize: ManiFontSize.bodyLg,
                    fontWeight: FontWeight.w900,
                    color: t.ink,
                  ),
                ),
              ),
              Chip(label: Text(solicitud.etiquetaEstado)),
            ],
          ),
          ManiGap.vSm,
          Text(
            zona.isEmpty
                ? 'Zona declarada: sin información'
                : 'Zona declarada: $zona',
            style: TextStyle(
              fontSize: ManiFontSize.body,
              fontWeight: FontWeight.w600,
              color: t.ink,
            ),
          ),
          ManiGap.vXs,
          Text(
            'Estado actualizado: ${formatearFecha(solicitud.actualizadaEn)}',
            style: TextStyle(
              fontSize: ManiFontSize.caption,
              fontWeight: FontWeight.w600,
              color: t.inkMuted,
            ),
          ),
          if (onVerCotizacion != null ||
              mostrarVerDetalle ||
              onVerAliados != null ||
              onPresentarQueja != null ||
              onCancelar != null ||
              cancelando) ...[
            ManiGap.vMd,
            Wrap(
              alignment: WrapAlignment.end,
              spacing: ManiSpace.sm,
              runSpacing: ManiSpace.sm,
              children: [
                if (cancelando)
                  Padding(
                    padding: const EdgeInsets.all(ManiSpace.md),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.ink,
                      ),
                    ),
                  )
                else if (onCancelar != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: ManiRadius.brMd,
                      border: Border.all(
                        color: ManiColors.danger,
                        width: ManiBorder.regular,
                      ),
                    ),
                    child: TextButton.icon(
                      key: Key('cancelar-solicitud-${solicitud.id}'),
                      style: TextButton.styleFrom(
                        foregroundColor: ManiColors.danger,
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancelar solicitud'),
                      onPressed: onCancelar,
                    ),
                  ),
                if (onVerAliados != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: ManiRadius.brMd,
                      border: Border.all(
                        color: t.border,
                        width: ManiBorder.regular,
                      ),
                      boxShadow: [t.shadowSm],
                    ),
                    child: TextButton.icon(
                      key: Key('ver-aliados-${solicitud.id}'),
                      icon: Icon(Icons.groups_outlined, size: 18, color: t.ink),
                      label: Text(
                        'Ver aliados',
                        style: TextStyle(color: t.ink),
                      ),
                      onPressed: onVerAliados,
                    ),
                  ),
                if (onPresentarQueja != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: ManiRadius.brMd,
                      border: Border.all(
                        color: t.border,
                        width: ManiBorder.regular,
                      ),
                      boxShadow: [t.shadowSm],
                    ),
                    child: TextButton.icon(
                      key: Key('presentar-queja-${solicitud.id}'),
                      icon: Icon(
                        Icons.feedback_outlined,
                        size: 18,
                        color: t.ink,
                      ),
                      label: Text(
                        'Presentar queja',
                        style: TextStyle(color: t.ink),
                      ),
                      onPressed: onPresentarQueja,
                    ),
                  ),
                if (mostrarVerDetalle)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: ManiRadius.brMd,
                      border: Border.all(
                        color: t.border,
                        width: ManiBorder.regular,
                      ),
                      boxShadow: [t.shadowSm],
                    ),
                    child: TextButton.icon(
                      key: Key('ver-detalle-${solicitud.id}'),
                      icon: Icon(Icons.open_in_new, size: 18, color: t.ink),
                      label: Text(
                        'Ver detalle',
                        style: TextStyle(
                          color: t.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: onAbrirDetalle,
                    ),
                  ),
                if (onVerCotizacion != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.brand,
                      borderRadius: ManiRadius.brMd,
                      border: Border.all(
                        color: t.border,
                        width: ManiBorder.regular,
                      ),
                      boxShadow: [t.shadowSm],
                    ),
                    child: TextButton.icon(
                      key: Key('ver-cotizacion-${solicitud.id}'),
                      icon: Icon(
                        Icons.request_quote_outlined,
                        size: 18,
                        color: t.onBrand,
                      ),
                      label: Text(
                        'Ver cotización',
                        style: TextStyle(
                          color: t.onBrand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: onVerCotizacion,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({this.onNuevaSolicitud});

  final VoidCallback? onNuevaSolicitud;

  @override
  Widget build(BuildContext context) => ManiEstadoVacio(
    icono: Icons.assignment_outlined,
    titulo: 'Aún no has publicado solicitudes.',
    texto: 'Cuando publiques una, aquí verás su estado y cotizaciones.',
    acciones: [
      if (onNuevaSolicitud != null)
        FilledButton.icon(
          key: const Key('seguimiento-nueva'),
          onPressed: onNuevaSolicitud,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Publicar una solicitud'),
        ),
    ],
  );
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) => ManiEstadoError(
    key: const Key('seguimiento-error'),
    mensaje: mensaje,
    onReintentar: onReintentar,
  );
}

const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// "26 oct 2026, 16:05" en hora local.
String formatearFecha(DateTime fecha) {
  final f = fecha.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${f.day} ${_meses[f.month - 1]} ${f.year}, ${dos(f.hour)}:${dos(f.minute)}';
}
