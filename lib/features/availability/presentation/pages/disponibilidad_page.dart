import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_esqueleto.dart';
import 'package:mani/core/widgets/mani_snackbar.dart';
import 'package:mani/features/availability/domain/entities/ausencia.dart';
import 'package:mani/features/availability/presentation/bloc/disponibilidad_cubit.dart';
import 'package:mani/features/availability/presentation/widgets/formulario_ausencia.dart';

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
      backgroundColor: context.mani.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
        side: BorderSide(color: context.mani.ink, width: 2),
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
          ManiButton(
            variante: ManiButtonVariante.enlace,
            etiqueta: 'Cancelar',
            onPressed: () => Navigator.of(dialogo).pop(false),
          ),
          ManiButton(
            key: const ValueKey('confirmar-eliminar'),
            variante: ManiButtonVariante.enlace,
            etiqueta: 'Eliminar',
            onPressed: () => Navigator.of(dialogo).pop(true),
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
        backgroundColor: context.mani.background,
        body: SafeArea(
          child: Column(
            children: [
              const _BarraSuperior(),
              Expanded(
                child: BlocBuilder<DisponibilidadCubit, DisponibilidadState>(
                  builder: (context, state) => switch (state.carga) {
                    CargaDisponibilidad.inicial ||
                    CargaDisponibilidad.cargando => Padding(
                      padding: const EdgeInsets.all(16),
                      child: ManiEsqueleto.tarjetas(),
                    ),
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
              BlocBuilder<DisponibilidadCubit, DisponibilidadState>(
                buildWhen: (a, b) =>
                    a.carga != b.carga || a.guardando != b.guardando,
                builder: (context, state) =>
                    state.carga != CargaDisponibilidad.listo
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.all(20),
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
    final puedeVolver = Navigator.of(context).canPop();
    return Container(
      decoration: BoxDecoration(
        color: context.mani.surface,
        border: Border(bottom: BorderSide(color: context.mani.ink, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (puedeVolver) ...[
            IconButton(
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back_rounded, color: context.mani.ink),
            ),
            const SizedBox(width: 4),
          ],
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.mani.brand,
              borderRadius: BorderRadius.circular(ManiRadius.lg),
              border: Border.all(color: context.mani.ink, width: 2),
              boxShadow: const [ManiShadow.sm],
            ),
            child: Icon(
              Icons.event_available_rounded,
              color: context.mani.onBrand,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mi disponibilidad',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: context.mani.ink,
                  ),
                ),
                Text(
                  'Vacaciones, enfermedad y otras ausencias',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.mani.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('btn-actualizar-disponibilidad'),
            tooltip: 'Actualizar',
            onPressed: () =>
                context.read<DisponibilidadCubit>().cargar(silencioso: true),
            icon: Icon(Icons.refresh_rounded, color: context.mani.ink),
          ),
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      children: [
        _EstadoActual(disponible: state.disponibleAhora),
        const SizedBox(height: 20),
        Text(
          'Ausencias programadas',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: context.mani.ink,
          ),
        ),
        const SizedBox(height: 10),
        if (state.ausencias.isEmpty)
          Padding(
            key: ValueKey('sin-ausencias'),
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No tienes ausencias programadas. Recibes solicitudes con normalidad.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mani.inkMuted),
            ),
          )
        else
          for (final a in state.ausencias)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
            color: disponible ? ManiColors.successText : ManiColors.dangerText,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disponible ? 'Disponible' : 'No disponible',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: context.mani.ink,
                  ),
                ),
                Text(
                  disponible
                      ? 'Estás recibiendo solicitudes nuevas.'
                      : 'Tienes una ausencia en curso: no recibes solicitudes nuevas.',
                  style: TextStyle(fontSize: 13, color: context.mani.inkMuted),
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: context.mani.ink,
                      ),
                    ),
                    if (ausencia.activa) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.mani.brand,
                          borderRadius: BorderRadius.circular(ManiRadius.sm),
                          border: Border.all(color: context.mani.ink),
                        ),
                        child: const Text(
                          'En curso',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Desde ${formatearFechaHora(ausencia.inicio)}\nHasta ${formatearFechaHora(ausencia.fin)}',
                  style: TextStyle(fontSize: 13, color: context.mani.ink),
                ),
                if (ausencia.nota != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    ausencia.nota!,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.mani.inkMuted,
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
            icon: Icon(Icons.edit_outlined, color: context.mani.ink),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mani.ink),
          ),
          const SizedBox(height: 16),
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
