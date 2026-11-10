import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_pagina.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_snackbar.dart';

import '../../domain/entities/solicitud_aliado.dart';
import '../bloc/bandeja_verificacion_cubit.dart';
import '../widgets/detalle_aliado_panel.dart';
import '../widgets/filtro_estado_tabs.dart';
import '../widgets/solicitud_aliado_card.dart';
import 'detalle_aliado_page.dart';
import 'package:mani/core/widgets/mani_estado.dart';

/// US-02.1.3 — Bandeja de verificación de aliados del Administrador del Tenant.
///
/// En escritorio muestra la lista y el perfil lado a lado (maestro-detalle);
/// en móvil el perfil se abre en su propia pantalla. Requiere un
/// [BandejaVerificacionCubit] provisto por el contexto.
class BandejaVerificacionPage extends StatelessWidget {
  const BandejaVerificacionPage({super.key, this.onAbrirCategorias});

  /// Abre el catálogo de categorías del tenant. Lo inyecta quien compone la
  /// navegación (el router), para que esta feature no conozca otras rutas.
  final VoidCallback? onAbrirCategorias;

  static const double anchoEscritorio = 960;

  /// Los avisos flotan por encima de la barra Aprobar/Rechazar para no taparla
  /// mientras el administrador revisa en serie.
  static const EdgeInsets _margenAvisos = EdgeInsets.fromLTRB(
    ManiSpace.lg,
    0,
    ManiSpace.lg,
    104,
  );

  @override
  Widget build(BuildContext context) {
    return BlocListener<BandejaVerificacionCubit, BandejaVerificacionState>(
      listenWhen: (antes, ahora) =>
          ahora.aviso != null && antes.aviso != ahora.aviso,
      listener: (context, state) => showManiSnackBar(
        context,
        state.aviso!.mensaje,
        esError: state.aviso!.esError,
        margin: _margenAvisos,
      ),
      child: Scaffold(
        backgroundColor: ManiColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _BarraSuperior(onAbrirCategorias: onAbrirCategorias),
              Expanded(
                child:
                    BlocBuilder<
                      BandejaVerificacionCubit,
                      BandejaVerificacionState
                    >(
                      buildWhen: (a, b) => a.carga != b.carga,
                      builder: (context, state) => switch (state.carga) {
                        EstadoCarga.inicial ||
                        EstadoCarga.cargando => const ManiCargando(),
                        EstadoCarga.error => _ErrorCarga(
                          mensaje:
                              state.error?.mensajeUsuario ??
                              'No pudimos cargar la bandeja.',
                          onReintentar: () =>
                              context.read<BandejaVerificacionCubit>().cargar(),
                        ),
                        EstadoCarga.listo => const _Contenido(),
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

class _Contenido extends StatelessWidget {
  const _Contenido();

  void _abrirEnMovil(BuildContext context, String aliadoId) {
    final cubit = context.read<BandejaVerificacionCubit>()
      ..seleccionar(aliadoId);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: DetalleAliadoPage(aliadoId: aliadoId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cubit = context.read<BandejaVerificacionCubit>();
        if (constraints.maxWidth < BandejaVerificacionPage.anchoEscritorio) {
          return _Bandeja(
            resaltarSeleccion: false,
            onSeleccionar: (id) => _abrirEnMovil(context, id),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 440,
              child: _Bandeja(
                resaltarSeleccion: true,
                onSeleccionar: cubit.seleccionar,
              ),
            ),
            Container(width: 2, color: ManiColors.ink),
            Expanded(
              child:
                  BlocBuilder<
                    BandejaVerificacionCubit,
                    BandejaVerificacionState
                  >(
                    buildWhen: (a, b) => a.seleccionadaId != b.seleccionadaId,
                    builder: (context, state) {
                      final id = state.seleccionadaId;
                      if (id == null) return const _SinSeleccion();
                      return DetalleAliadoPanel(
                        key: ValueKey('panel-$id'),
                        aliadoId: id,
                        onCerrar: cubit.cerrarDetalle,
                      );
                    },
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _Bandeja extends StatelessWidget {
  const _Bandeja({
    required this.resaltarSeleccion,
    required this.onSeleccionar,
  });

  final bool resaltarSeleccion;
  final ValueChanged<String> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BandejaVerificacionCubit>();
    return BlocBuilder<BandejaVerificacionCubit, BandejaVerificacionState>(
      builder: (context, state) {
        final visibles = state.visibles;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ManiSpace.xl,
                ManiSpace.xl,
                ManiSpace.xl,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Solicitudes de aliados',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  ManiGap.vXs,
                  const Text(
                    'Revisa los documentos de cada candidato y decide quién entra a tu red de técnicos.',
                    style: TextStyle(
                      color: ManiColors.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  ManiGap.vLg,
                  FiltroEstadoTabs(
                    seleccionado: state.filtro,
                    conteo: state.conteo,
                    onCambiar: cubit.cambiarFiltro,
                  ),
                  ManiGap.vMd,
                  _CampoBusqueda(onCambio: cubit.buscar),
                  ManiGap.vMd,
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: ManiColors.ink,
                backgroundColor: ManiColors.brand,
                onRefresh: () => cubit.cargar(silencioso: true),
                child: visibles.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          _BandejaVacia(
                            filtro: state.filtro,
                            busqueda: state.busqueda,
                          ),
                        ],
                      )
                    : ListView.separated(
                        key: PageStorageKey('lista-${state.filtro.name}'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          ManiSpace.xl,
                          ManiSpace.xs,
                          ManiSpace.xxl,
                          ManiSpace.xxl,
                        ),
                        itemCount: visibles.length,
                        separatorBuilder: (_, _) => ManiGap.vMd,
                        itemBuilder: (_, i) {
                          final aliado = visibles[i];
                          return SolicitudAliadoCard(
                            aliado: aliado,
                            seleccionada:
                                resaltarSeleccion &&
                                aliado.id == state.seleccionadaId,
                            onTap: () => onSeleccionar(aliado.id),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CampoBusqueda extends StatefulWidget {
  const _CampoBusqueda({required this.onCambio});

  final ValueChanged<String> onCambio;

  @override
  State<_CampoBusqueda> createState() => _CampoBusquedaState();
}

class _CampoBusquedaState extends State<_CampoBusqueda> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borde = OutlineInputBorder(
      borderRadius: ManiRadius.brMd,
      borderSide: ManiBorder.side,
    );
    return TextField(
      key: const ValueKey('buscar-aliado'),
      controller: _controller,
      onChanged: (t) {
        setState(() {});
        widget.onCambio(t);
      },
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: ManiColors.surface,
        hintText: 'Buscar por nombre, correo o especialidad',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: ManiColors.inkMuted,
        ),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar búsqueda',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _controller.clear();
                  setState(() {});
                  widget.onCambio('');
                },
              ),
        enabledBorder: borde,
        focusedBorder: borde.copyWith(borderSide: ManiBorder.sideThick),
      ),
    );
  }
}

class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior({this.onAbrirCategorias});

  final VoidCallback? onAbrirCategorias;

  @override
  Widget build(BuildContext context) {
    return ManiEncabezadoPantalla(
      icono: Icons.verified_user_rounded,
      titulo: 'Verificación de aliados',
      descripcion: 'Panel del administrador',
      acciones: [
        if (onAbrirCategorias != null)
          IconButton(
            key: const ValueKey('btn-ir-categorias'),
            tooltip: 'Categorías de servicio',
            onPressed: onAbrirCategorias,
            icon: const Icon(Icons.category_outlined, color: ManiColors.ink),
          ),
        IconButton(
          key: const ValueKey('btn-actualizar'),
          tooltip: 'Actualizar bandeja',
          onPressed: () =>
              context.read<BandejaVerificacionCubit>().cargar(silencioso: true),
          icon: const Icon(Icons.refresh_rounded, color: ManiColors.ink),
        ),
      ],
    );
  }
}

class _BandejaVacia extends StatelessWidget {
  const _BandejaVacia({required this.filtro, required this.busqueda});

  final EstadoVerificacion filtro;
  final String busqueda;

  @override
  Widget build(BuildContext context) {
    final buscando = busqueda.trim().isNotEmpty;
    final (icono, titulo, texto) = buscando
        ? (
            Icons.search_off_rounded,
            'Sin resultados',
            'Ningún aliado coincide con "${busqueda.trim()}".',
          )
        : switch (filtro) {
            EstadoVerificacion.pendiente => (
              Icons.celebration_rounded,
              '¡Bandeja al día!',
              'No hay aliados esperando revisión. Los nuevos registros aparecerán aquí.',
            ),
            EstadoVerificacion.aprobado => (
              Icons.verified_outlined,
              'Aún no hay aliados aprobados',
              'Cuando apruebes un registro lo verás en esta pestaña.',
            ),
            EstadoVerificacion.rechazado => (
              Icons.inbox_outlined,
              'No hay aliados rechazados',
              'Los registros que rechaces quedarán aquí con su motivo.',
            ),
          };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ManiSpace.xl,
        ManiSpace.xxxl,
        ManiSpace.xl,
        ManiSpace.xxxl,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(ManiSpace.lg),
            decoration: BoxDecoration(
              color: ManiColors.brand,
              shape: BoxShape.circle,
              border: Border.all(
                color: ManiColors.border,
                width: ManiBorder.regular,
              ),
              boxShadow: const [ManiShadow.sm],
            ),
            child: Icon(icono, size: 32, color: ManiColors.ink),
          ),
          ManiGap.vLg,
          Text(
            titulo,
            style: const TextStyle(
              fontSize: ManiFontSize.bodyLg,
              fontWeight: FontWeight.w900,
            ),
          ),
          ManiGap.vSm,
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ManiColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _SinSeleccion extends StatelessWidget {
  const _SinSeleccion();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(ManiSpace.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 48,
              color: ManiColors.inkSubtle,
            ),
            ManiGap.vMd,
            Text(
              'Selecciona un aliado',
              style: TextStyle(
                fontSize: ManiFontSize.bodyLg,
                fontWeight: FontWeight.w900,
              ),
            ),
            ManiGap.vSm,
            Text(
              'Verás su perfil, sus documentos y las opciones para aprobarlo o rechazarlo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ManiColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ManiSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: ManiColors.ink,
            ),
            ManiGap.vMd,
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            ManiGap.vLg,
            ManiButton(
              key: const ValueKey('btn-reintentar'),
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
