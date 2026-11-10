import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/utils/formato_fecha.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart'
    show formatearPesos;

import '../domain/evento_transaccion.dart';
import 'auditoria_cubit.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

/// Auditoría de transacciones (SCRUM-889, HU-M11-03): el registro inmutable de
/// pagos del tenant, solo para el administrador. Cada evento dice quién, cuándo
/// y con qué desenlace; nada se edita ni se borra desde aquí.
class AuditoriaPage extends StatelessWidget {
  const AuditoriaPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AuditoriaCubit(sl())..cargar(),
    child: const AuditoriaView(),
  );
}

class AuditoriaView extends StatefulWidget {
  const AuditoriaView({super.key});

  @override
  State<AuditoriaView> createState() => _AuditoriaViewState();
}

class _AuditoriaViewState extends State<AuditoriaView> {
  final _filtro = TextEditingController();

  @override
  void dispose() {
    _filtro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManiBarraPagina(
            icono: Icons.receipt_long_rounded,
            titulo: 'Auditoría de transacciones',
          ),
          Expanded(
            child: BlocBuilder<AuditoriaCubit, AuditoriaState>(
              builder: (context, state) {
                final cubit = context.read<AuditoriaCubit>();
                return ListView(
                  padding: const EdgeInsets.all(ManiSpace.lg),
                  children: [
                    const Text(
                      'Registro inmutable: cada pago deja un evento con quién lo '
                      'hizo y cuándo. Solo ves los eventos de tu empresa.',
                      key: Key('aviso-inmutable'),
                    ),
                    ManiGap.vMd,
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('filtro-pago'),
                            controller: _filtro,
                            decoration: const InputDecoration(
                              labelText: 'Filtrar por id de pago (opcional)',
                            ),
                            onSubmitted: (v) => cubit.cargar(pagoId: v),
                          ),
                        ),
                        ManiGap.hSm,
                        FilledButton(
                          key: const Key('btn-filtrar'),
                          onPressed: () => cubit.cargar(pagoId: _filtro.text),
                          child: const Text('Buscar'),
                        ),
                      ],
                    ),
                    ManiGap.vLg,
                    if (state.fase == FaseAuditoria.cargando)
                      const ManiCargando(),
                    if (state.fase == FaseAuditoria.error)
                      Column(
                        children: [
                          Text(state.error!, key: const Key('error-auditoria')),
                          ManiGap.vSm,
                          OutlinedButton(
                            key: const Key('reintentar-auditoria'),
                            onPressed: () =>
                                cubit.cargar(pagoId: state.filtroPago),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    if (state.fase == FaseAuditoria.listo &&
                        state.eventos.isEmpty)
                      const Text(
                        'No hay transacciones registradas con ese criterio.',
                        key: Key('auditoria-vacia'),
                      ),
                    for (final e in state.eventos) _TarjetaEvento(evento: e),
                    if (state.hayMas)
                      Center(
                        child: OutlinedButton(
                          key: const Key('cargar-mas'),
                          onPressed: state.cargandoMas ? null : cubit.cargarMas,
                          child: Text(
                            state.cargandoMas ? 'Cargando…' : 'Cargar más',
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaEvento extends StatelessWidget {
  const _TarjetaEvento({required this.evento});

  final EventoTransaccion evento;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('evento-${evento.id}'),
      margin: const EdgeInsets.only(bottom: ManiSpace.md),
      child: Padding(
        padding: const EdgeInsets.all(ManiSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${evento.etiquetaTipo} · ${evento.estado}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ManiGap.vXs,
            Text('${formatearPesos(evento.monto)} ${evento.moneda}'),
            Text('Hizo: ${evento.etiquetaActor}'),
            Text('Cuándo: ${formatearFechaHora(evento.creadoEn)}'),
            Text('Pago: ${evento.pagoId}'),
            if (evento.correlationId != null)
              Text('Correlación: ${evento.correlationId}'),
          ],
        ),
      ),
    );
  }
}
