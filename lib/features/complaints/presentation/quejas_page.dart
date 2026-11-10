import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/network/mensaje_error_gateway.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

import '../domain/queja.dart';
import 'quejas_cubit.dart';
import 'package:mani/core/widgets/mani_estado.dart';

String _fecha(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${dos(l.month)}-${dos(l.day)} ${dos(l.hour)}:${dos(l.minute)}';
}

/// Quejas del cliente (HU-M12-01 / SCRUM-895) o del tenant (HU-M12-02 /
/// SCRUM-896), según [QuejasCubit.esAdmin]. El administrador cambia el estado
/// con las transiciones válidas; cerrar exige la respuesta al cliente.
class QuejasPage extends StatelessWidget {
  const QuejasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<QuejasCubit, QuejasState>(
      listenWhen: (a, b) => b.aviso != null && a.aviso != b.aviso,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('quejas-aviso'),
              content: Text(state.aviso!),
              backgroundColor: state.avisoEsError
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          );
      },
      builder: (context, state) {
        final cubit = context.read<QuejasCubit>();
        return ManiPagina(
          ancho: ManiAncho.panel,
          encabezado: ManiBarraPagina(
            icono: cubit.esAdmin
                ? Icons.support_agent_outlined
                : Icons.feedback_outlined,
            titulo: cubit.esAdmin ? 'Quejas del tenant' : 'Mis quejas',
            descripcion: cubit.esAdmin
                ? 'Atiende las quejas de los clientes y cambia su estado. '
                      'Cada cambio queda registrado con tu usuario.'
                : 'Quejas que presentaste sobre tus servicios. Para '
                      'presentar una nueva, ve a Mis solicitudes.',
          ),
          alRefrescar: cubit.cargar,
          children: [
            if (cubit.esAdmin) ...[
              Wrap(
                spacing: ManiSpace.sm,
                runSpacing: ManiSpace.sm,
                children: [
                  _Filtro(
                    clave: const Key('filtro-todas'),
                    etiqueta: 'Todas',
                    activo: state.filtro == null,
                    onTap: () => cubit.filtrar(null),
                  ),
                  for (final e in EstadoQueja.values)
                    _Filtro(
                      clave: Key('filtro-${e.valor}'),
                      etiqueta: e.etiqueta,
                      activo: state.filtro == e,
                      onTap: () => cubit.filtrar(e),
                    ),
                ],
              ),
              ManiGap.vXl,
            ],
            if (state.cargando && state.quejas.isEmpty)
              const ManiCargando()
            else if (state.error != null)
              ManiAvisoTarjeta(
                key: const Key('quejas-error'),
                icono: Icons.error_outline,
                texto: state.error!,
                esError: true,
                accion: ManiBotonPildora(
                  etiqueta: 'Reintentar',
                  icono: Icons.refresh,
                  onPressed: cubit.cargar,
                ),
              )
            else if (state.quejas.isEmpty)
              const ManiEstadoVacio(
                key: Key('quejas-vacio'),
                icono: Icons.inbox_outlined,
                titulo: 'No hay quejas',
              )
            else
              ManiRejilla(
                anchoMinimo: 460,
                maxColumnas: 2,
                espacio: 20,
                children: [
                  for (final q in state.quejas)
                    _TarjetaQueja(
                      queja: q,
                      esAdmin: cubit.esAdmin,
                      actualizando: state.actualizandoId == q.id,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Filtro por estado en píldora: color de marca con sombra el activo.
class _Filtro extends StatelessWidget {
  const _Filtro({
    required this.clave,
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final Key clave;
  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: activo ? ManiColors.brand : ManiColors.surface,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
        boxShadow: activo ? const [ManiShadow.sm] : const [],
      ),
      child: TextButton(
        key: clave,
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: ManiColors.ink,
          padding: const EdgeInsets.symmetric(
            horizontal: ManiSpace.md,
            vertical: ManiSpace.sm,
          ),
          textStyle: TextStyle(
            fontSize: ManiFontSize.bodySm,
            fontWeight: activo ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
        child: Text(etiqueta),
      ),
    );
  }
}

/// Fondo del estado de una queja; el texto va en negro (contraste AA).
Color _colorEstado(EstadoQueja e) => switch (e) {
  EstadoQueja.abierta => ManiColors.brand,
  EstadoQueja.enRevision => ManiColors.infoBorder,
  EstadoQueja.resuelta => ManiColors.successBorder,
  EstadoQueja.rechazada => ManiColors.dangerBorder,
};

class _TarjetaQueja extends StatelessWidget {
  const _TarjetaQueja({
    required this.queja,
    required this.esAdmin,
    required this.actualizando,
  });

  final Queja queja;
  final bool esAdmin;
  final bool actualizando;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<QuejasCubit>();
    return ManiCard(
      key: Key('queja-${queja.id}'),
      padding: const EdgeInsets.all(ManiSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${queja.etiquetaMotivo} · ${queja.categoria}',
                  style: const TextStyle(
                    fontSize: ManiFontSize.bodyLg,
                    fontWeight: FontWeight.w900,
                    color: ManiColors.ink,
                  ),
                ),
              ),
              ManiGap.hMd,
              Container(
                key: Key('queja-estado-${queja.id}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: ManiSpace.sm,
                  vertical: ManiSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: _colorEstado(queja.estado),
                  borderRadius: ManiRadius.brSm,
                  border: Border.all(
                    color: ManiColors.border,
                    width: ManiBorder.thin,
                  ),
                ),
                child: Text(
                  queja.estado.etiqueta,
                  style: const TextStyle(
                    fontSize: ManiFontSize.caption,
                    fontWeight: FontWeight.w800,
                    color: ManiColors.ink,
                  ),
                ),
              ),
            ],
          ),
          ManiGap.vSm,
          Text(
            queja.descripcion,
            style: const TextStyle(
              fontSize: ManiFontSize.body,
              color: ManiColors.ink,
            ),
          ),
          ManiGap.vSm,
          Text(
            [
              'Presentada ${_fecha(queja.creadaEn)}',
              if (esAdmin && queja.clienteEmail != null) queja.clienteEmail!,
            ].join(' · '),
            style: const TextStyle(
              fontSize: ManiFontSize.caption,
              fontWeight: FontWeight.w600,
              color: ManiColors.inkMuted,
            ),
          ),
          if (queja.respuesta != null) ...[
            ManiGap.vMd,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ManiSpace.md),
              decoration: BoxDecoration(
                color: ManiColors.background,
                borderRadius: ManiRadius.brSm,
                border: Border.all(
                  color: ManiColors.border,
                  width: ManiBorder.thin,
                ),
              ),
              child: Text(
                'Respuesta: ${queja.respuesta}',
                key: Key('queja-respuesta-${queja.id}'),
                style: const TextStyle(
                  fontSize: ManiFontSize.bodySm,
                  fontWeight: FontWeight.w600,
                  color: ManiColors.ink,
                ),
              ),
            ),
          ],
          ManiGap.vLg,
          Wrap(
            alignment: WrapAlignment.end,
            spacing: ManiSpace.sm,
            runSpacing: ManiSpace.sm,
            children: [
              ManiBotonPildora(
                key: Key('queja-historial-${queja.id}'),
                etiqueta: 'Historial',
                icono: Icons.history,
                onPressed: () => _verHistorial(context, cubit, queja),
              ),
              if (esAdmin && actualizando)
                const Padding(
                  padding: EdgeInsets.all(ManiSpace.md),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ManiColors.ink,
                    ),
                  ),
                )
              else if (esAdmin)
                for (final siguiente in queja.estado.siguientes)
                  ManiBotonPildora(
                    key: Key('queja-${siguiente.valor}-${queja.id}'),
                    // Avanzar la queja es la acción principal; rechazar o
                    // reabrir quedan como secundarias.
                    principal:
                        siguiente == EstadoQueja.resuelta ||
                        siguiente == EstadoQueja.enRevision,
                    etiqueta: switch (siguiente) {
                      EstadoQueja.enRevision => 'Pasar a revisión',
                      EstadoQueja.resuelta => 'Resolver',
                      EstadoQueja.rechazada => 'Rechazar',
                      EstadoQueja.abierta => 'Reabrir',
                    },
                    onPressed: () =>
                        _cambiarEstado(context, cubit, queja, siguiente),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _cambiarEstado(
  BuildContext context,
  QuejasCubit cubit,
  Queja queja,
  EstadoQueja estado,
) async {
  String? nota;
  if (estado.esFinal) {
    nota = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoRespuesta(estado: estado),
    );
    if (nota == null) return;
  }
  await cubit.cambiarEstado(queja, estado, nota: nota);
}

Future<void> _verHistorial(
  BuildContext context,
  QuejasCubit cubit,
  Queja queja,
) => showDialog<void>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Historial de la queja'),
    content: SizedBox(
      width: 460,
      child: FutureBuilder<List<TransicionQueja>>(
        future: cubit.historial(queja.id),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 80, child: ManiCargando());
          }
          if (snap.hasError) return Text(mensajeErrorGateway(snap.error!));
          return ListView(
            shrinkWrap: true,
            children: [
              for (final (i, h) in snap.data!.indexed)
                ListTile(
                  key: Key('queja-transicion-$i'),
                  dense: true,
                  title: Text(
                    h.estadoAnterior == null
                        ? 'Presentada (${h.estadoNuevo.etiqueta})'
                        : '${h.estadoAnterior!.etiqueta} → ${h.estadoNuevo.etiqueta}',
                  ),
                  subtitle: Text(
                    [
                      _fecha(h.fecha),
                      h.actorRol == 'ADMIN' ? 'Administrador' : 'Cliente',
                      if (h.nota != null) h.nota!,
                    ].join(' · '),
                  ),
                ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cerrar'),
      ),
    ],
  ),
);

/// Respuesta al cliente al cerrar una queja: entre 5 y 1000 caracteres.
class _DialogoRespuesta extends StatefulWidget {
  const _DialogoRespuesta({required this.estado});

  final EstadoQueja estado;

  @override
  State<_DialogoRespuesta> createState() => _DialogoRespuestaState();
}

class _DialogoRespuestaState extends State<_DialogoRespuesta> {
  final _nota = TextEditingController();

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  bool get _valida {
    final n = _nota.text.trim().runes.length;
    return n >= 5 && n <= 1000;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.estado == EstadoQueja.resuelta
            ? 'Resolver queja'
            : 'Rechazar queja',
      ),
      content: SizedBox(
        width: 420,
        child: TextField(
          key: const Key('queja-nota'),
          controller: _nota,
          maxLines: 3,
          maxLength: 1000,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Respuesta para el cliente',
            helperText: 'Mínimo 5 caracteres',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ManiButton(
          key: const Key('queja-confirmar'),
          etiqueta: 'Confirmar',
          onPressed: _valida
              ? () => Navigator.of(context).pop(_nota.text.trim())
              : null,
        ),
      ],
    );
  }
}
