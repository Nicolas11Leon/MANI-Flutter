import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_pagina.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_snackbar.dart';
import 'package:mani/features/availability/domain/entities/ausencia.dart';
import 'package:mani/features/availability/presentation/bloc/disponibilidad_cubit.dart';
import 'package:mani/features/availability/presentation/widgets/formulario_ausencia.dart';
import 'package:mani/core/widgets/mani_estado.dart';

/// Pantalla "Mi disponibilidad" del aliado (US-02.1.6).
class DisponibilidadPage extends StatelessWidget {
  const DisponibilidadPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<DisponibilidadCubit>()..cargar(),
    child: const DisponibilidadView(),
  );
}

/// Vista de la pantalla; recibe el cubit del árbol (así la prueban los tests).
class DisponibilidadView extends StatelessWidget {
  const DisponibilidadView({super.key});

  Future<void> _abrirFormulario(BuildContext context, {Ausencia? ausencia}) {
    final cubit = context.read<DisponibilidadCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ManiColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ManiRadius.lg),
        ),
        side: ManiBorder.side,
      ),
      builder: (_) => FormularioAusencia(
        ahora: cubit.ahora(),
        titulo: ausencia == null ? 'Marcar no disponible' : 'Editar ausencia',
        inicial: ausencia == null
            ? null
            : BorradorAusencia(
                inicio: ausencia.inicio,
                fin: ausencia.fin,
                motivo: ausencia.motivo,
                nota: ausencia.nota,
              ),
        onGuardar: (borrador) => ausencia == null
            ? cubit.crear(borrador)
            : cubit.editar(ausencia.id, borrador),
      ),
    );
  }

  Future<void> _confirmarEliminar(
    BuildContext context,
    Ausencia ausencia,
  ) async {
    final cubit = context.read<DisponibilidadCubit>();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Eliminar esta ausencia?'),
        content: Text(
          'Volverás a recibir solicitudes entre ${formatearFechaHora(ausencia.inicio)} '
          'y ${formatearFechaHora(ausencia.fin)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const ValueKey('confirmar-eliminar'),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: ManiColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmado == true) await cubit.eliminar(ausencia.id);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DisponibilidadCubit, DisponibilidadState>(
      listenWhen: (antes, ahora) =>
          ahora.aviso != null && antes.aviso != ahora.aviso,
      listener: (context, state) => showManiSnackBar(
        context,
        state.aviso!.mensaje,
        esError: state.aviso!.esError,
      ),
      child: Scaffold(
        backgroundColor: ManiColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const _BarraSuperior(),
              Expanded(
                child: ManiAnchoContenido(
                  ancho: ManiAncho.formulario,
                  child: BlocBuilder<DisponibilidadCubit, DisponibilidadState>(
                    builder: (context, state) => switch (state.carga) {
                      CargaDisponibilidad.inicial ||
                      CargaDisponibilidad.cargando => const ManiCargando(),
                      CargaDisponibilidad.error => _ErrorCarga(
                        mensaje:
                            state.falla?.mensajeUsuario ??
                            'No pudimos cargar tu disponibilidad.',
                        onReintentar: () =>
                            context.read<DisponibilidadCubit>().cargar(),
                      ),
                      CargaDisponibilidad.listo => _Contenido(
                        state: state,
                        onEditar: (a) => _abrirFormulario(context, ausencia: a),
                        onEliminar: (a) => _confirmarEliminar(context, a),
                      ),
                    },
                  ),
                ),
              ),
              BlocBuilder<DisponibilidadCubit, DisponibilidadState>(
                buildWhen: (a, b) =>
                    a.carga != b.carga || a.guardando != b.guardando,
                builder: (context, state) =>
                    state.carga != CargaDisponibilidad.listo
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.all(ManiSpace.xl),
                        child: ManiButton(
                          key: const ValueKey('btn-nueva-ausencia'),
                          etiqueta: 'Marcar no disponible',
                          icono: Icons.event_busy_rounded,
                          expandir: true,
                          onPressed: state.guardando
                              ? null
                              : () => _abrirFormulario(context),
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

class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior();

  @override
  Widget build(BuildContext context) {
    return ManiEncabezadoPantalla(
      ancho: ManiAncho.formulario,
      icono: Icons.event_available_rounded,
      titulo: 'Mi disponibilidad',
      descripcion: 'Vacaciones, enfermedad y otras ausencias',
      acciones: [
        IconButton(
          key: const ValueKey('btn-actualizar-disponibilidad'),
          tooltip: 'Actualizar',
          onPressed: () =>
              context.read<DisponibilidadCubit>().cargar(silencioso: true),
          icon: const Icon(Icons.refresh_rounded, color: ManiColors.ink),
        ),
      ],
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.state,
    required this.onEditar,
    required this.onEliminar,
  });

  final DisponibilidadState state;
  final ValueChanged<Ausencia> onEditar;
  final ValueChanged<Ausencia> onEliminar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ManiSpace.xl,
        ManiSpace.xl,
        ManiSpace.xl,
        0,
      ),
      children: [
        _EstadoActual(disponible: state.disponibleAhora),
        ManiGap.vXl,
        const Text(
          'Ausencias programadas',
          style: TextStyle(
            fontSize: ManiFontSize.body,
            fontWeight: FontWeight.w900,
            color: ManiColors.ink,
          ),
        ),
        ManiGap.vSm,
        if (state.ausencias.isEmpty)
          const Padding(
            key: ValueKey('sin-ausencias'),
            padding: EdgeInsets.symmetric(vertical: ManiSpace.xxl),
            child: Text(
              'No tienes ausencias programadas. Recibes solicitudes con normalidad.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ManiColors.inkMuted),
            ),
          )
        else
          for (final a in state.ausencias)
            Padding(
              padding: const EdgeInsets.only(bottom: ManiSpace.md),
              child: _TarjetaAusencia(
                ausencia: a,
                habilitada: !state.guardando,
                onEditar: () => onEditar(a),
                onEliminar: () => onEliminar(a),
              ),
            ),
      ],
    );
  }
}

class _EstadoActual extends StatelessWidget {
  const _EstadoActual({required this.disponible});

  final bool disponible;

  @override
  Widget build(BuildContext context) {
    return ManiCard(
      key: ValueKey(disponible ? 'estado-disponible' : 'estado-no-disponible'),
      color: disponible
          ? ManiColors.successContainer
          : ManiColors.dangerContainer,
      child: Row(
        children: [
          Icon(
            disponible
                ? Icons.check_circle_rounded
                : Icons.do_not_disturb_on_rounded,
            color: disponible ? ManiColors.success : ManiColors.danger,
            size: 32,
          ),
          ManiGap.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disponible ? 'Disponible' : 'No disponible',
                  style: const TextStyle(
                    fontSize: ManiFontSize.title,
                    fontWeight: FontWeight.w900,
                    color: ManiColors.ink,
                  ),
                ),
                Text(
                  disponible
                      ? 'Estás recibiendo solicitudes nuevas.'
                      : 'Tienes una ausencia en curso: no recibes solicitudes nuevas.',
                  style: const TextStyle(
                    fontSize: ManiFontSize.bodySm,
                    color: ManiColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAusencia extends StatelessWidget {
  const _TarjetaAusencia({
    required this.ausencia,
    required this.habilitada,
    required this.onEditar,
    required this.onEliminar,
  });

  final Ausencia ausencia;
  final bool habilitada;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return ManiCard(
      key: ValueKey('ausencia-${ausencia.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ausencia.motivo.etiqueta,
                      style: const TextStyle(
                        fontSize: ManiFontSize.body,
                        fontWeight: FontWeight.w900,
                        color: ManiColors.ink,
                      ),
                    ),
                    if (ausencia.activa) ...[
                      ManiGap.hSm,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ManiSpace.sm,
                          vertical: ManiSpace.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: ManiColors.brand,
                          borderRadius: ManiRadius.brXs,
                          border: Border.all(color: ManiColors.border),
                        ),
                        child: const Text(
                          'En curso',
                          style: TextStyle(
                            fontSize: ManiFontSize.micro,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                ManiGap.vXs,
                Text(
                  'Desde ${formatearFechaHora(ausencia.inicio)}\nHasta ${formatearFechaHora(ausencia.fin)}',
                  style: const TextStyle(
                    fontSize: ManiFontSize.bodySm,
                    color: ManiColors.ink,
                  ),
                ),
                if (ausencia.nota != null) ...[
                  ManiGap.vXs,
                  Text(
                    ausencia.nota!,
                    style: const TextStyle(
                      fontSize: ManiFontSize.caption,
                      color: ManiColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: ValueKey('editar-${ausencia.id}'),
            tooltip: 'Editar',
            onPressed: habilitada ? onEditar : null,
            icon: const Icon(Icons.edit_outlined, color: ManiColors.ink),
          ),
          IconButton(
            key: ValueKey('eliminar-${ausencia.id}'),
            tooltip: 'Eliminar',
            onPressed: habilitada ? onEliminar : null,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: ManiColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(ManiSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ManiColors.ink),
          ),
          ManiGap.vLg,
          ManiButton(
            key: const ValueKey('btn-reintentar-disponibilidad'),
            etiqueta: 'Reintentar',
            icono: Icons.refresh_rounded,
            onPressed: onReintentar,
          ),
        ],
      ),
    ),
  );
}
