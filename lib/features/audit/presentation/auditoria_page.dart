import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_text_field.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/utils/formato_fecha.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';
import 'package:mani/features/services/quotes/presentation/cotizacion_page.dart'
    show formatearPesos;

import '../domain/evento_transaccion.dart';
import 'auditoria_cubit.dart';

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
    final t = context.mani;
    return Scaffold(
      backgroundColor: t.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ManiEncabezadoPantalla(
            ancho: ManiAncho.lista,
            icono: Icons.receipt_long_rounded,
            titulo: 'Auditoría de transacciones',
            descripcion:
                'Bitácora inmutable de eventos financieros de tu empresa.',
          ),
          Expanded(
            child: ManiAnchoContenido(
              ancho: ManiAncho.lista,
              child: BlocBuilder<AuditoriaCubit, AuditoriaState>(
                builder: (context, state) {
                  final cubit = context.read<AuditoriaCubit>();
                  return ListView(
                    padding: const EdgeInsets.all(ManiSpace.xl),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(ManiSpace.md),
                        decoration: BoxDecoration(
                          color: t.surfaceWarm,
                          borderRadius: ManiRadius.brMd,
                          border: Border.all(
                            color: t.border,
                            width: ManiBorder.regular,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                              color: t.ink,
                            ),
                            ManiGap.hSm,
                            Expanded(
                              child: Text(
                                'Registro inmutable: cada pago deja un evento con quién lo '
                                'hizo y cuándo. Solo ves los eventos de tu empresa.',
                                key: const Key('aviso-inmutable'),
                                style: TextStyle(
                                  fontSize: ManiFontSize.bodySm,
                                  fontWeight: FontWeight.w700,
                                  color: t.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ManiGap.vLg,
                      Row(
                        children: [
                          Expanded(
                            child: ManiTextField(
                              key: const Key('filtro-pago'),
                              controller: _filtro,
                              label: 'Filtrar por id de pago (opcional)',
                              prefixIcon: const Icon(Icons.search_rounded),
                              onFieldSubmitted: (v) => cubit.cargar(pagoId: v),
                            ),
                          ),
                          ManiGap.hSm,
                          ManiButton(
                            key: const Key('btn-filtrar'),
                            etiqueta: 'Buscar',
                            onPressed: () => cubit.cargar(pagoId: _filtro.text),
                          ),
                        ],
                      ),
                      ManiGap.vLg,
                      if (state.fase == FaseAuditoria.cargando)
                        const ManiCargando(),
                      if (state.fase == FaseAuditoria.error)
                        Column(
                          children: [
                            Text(
                              state.error!,
                              key: const Key('error-auditoria'),
                              style: TextStyle(color: t.ink),
                            ),
                            ManiGap.vSm,
                            ManiButton(
                              key: const Key('reintentar-auditoria'),
                              variante: ManiButtonVariante.secundario,
                              etiqueta: 'Reintentar',
                              onPressed: () =>
                                  cubit.cargar(pagoId: state.filtroPago),
                            ),
                          ],
                        ),
                      if (state.fase == FaseAuditoria.listo &&
                          state.eventos.isEmpty)
                        const ManiEstadoVacio(
                          key: Key('auditoria-vacia'),
                          icono: Icons.receipt_long_outlined,
                          titulo:
                              'No hay transacciones registradas con ese criterio.',
                        ),
                      for (final e in state.eventos) ...[
                        _TarjetaEvento(evento: e),
                        ManiGap.vMd,
                      ],
                      if (state.hayMas)
                        Center(
                          child: ManiButton(
                            key: const Key('cargar-mas'),
                            variante: ManiButtonVariante.secundario,
                            etiqueta: state.cargandoMas
                                ? 'Cargando…'
                                : 'Cargar más',
                            onPressed: state.cargandoMas
                                ? null
                                : cubit.cargarMas,
                          ),
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
  }
}

class _TarjetaEvento extends StatelessWidget {
  const _TarjetaEvento({required this.evento});

  final EventoTransaccion evento;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    return ManiCard(
      key: Key('evento-${evento.id}'),
      sombra: t.shadowSm,
      padding: const EdgeInsets.all(ManiSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${evento.etiquetaTipo} · ${evento.estado}',
                  style: TextStyle(
                    fontSize: ManiFontSize.bodyLg,
                    fontWeight: FontWeight.w900,
                    color: t.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ManiSpace.sm,
                  vertical: ManiSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: t.brandSoft,
                  borderRadius: ManiRadius.brSm,
                  border: Border.all(color: t.border, width: ManiBorder.thin),
                ),
                child: Text(
                  '${formatearPesos(evento.monto)} ${evento.moneda}',
                  style: TextStyle(
                    fontSize: ManiFontSize.bodySm,
                    fontWeight: FontWeight.w900,
                    color: t.ink,
                  ),
                ),
              ),
            ],
          ),
          ManiGap.vSm,
          Text(
            'Hizo: ${evento.etiquetaActor}',
            style: TextStyle(color: t.ink, fontWeight: FontWeight.w600),
          ),
          Text(
            'Cuándo: ${formatearFechaHora(evento.creadoEn)}',
            style: TextStyle(color: t.inkMuted),
          ),
          Text('Pago: ${evento.pagoId}', style: TextStyle(color: t.inkMuted)),
          if (evento.correlationId != null)
            Text(
              'Correlación: ${evento.correlationId}',
              style: TextStyle(
                fontSize: ManiFontSize.caption,
                color: t.inkSubtle,
              ),
            ),
        ],
      ),
    );
  }
}
