import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/network/mensaje_error_gateway.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

import '../data/tenants_datasource.dart';

class TenantsState extends Equatable {
  const TenantsState({
    this.cargando = false,
    this.tenants = const [],
    this.actualizandoId,
    this.error,
    this.aviso,
    this.avisoEsError = false,
  });

  final bool cargando;
  final List<TenantPlataforma> tenants;
  final String? actualizandoId;
  final String? error;
  final String? aviso;
  final bool avisoEsError;

  @override
  List<Object?> get props => [
    cargando,
    tenants,
    actualizandoId,
    error,
    aviso,
    avisoEsError,
  ];
}

/// Administración de tenants (HU-M12-07 / SCRUM-901): el administrador de
/// plataforma habilita, suspende o inactiva un tenant con motivo. Core exige el
/// permiso PLATFORM_ADMIN y registra cada cambio.
class TenantsCubit extends Cubit<TenantsState> {
  TenantsCubit(this._fuente) : super(const TenantsState());

  final FuenteTenants _fuente;

  Future<void> cargar() async {
    emit(TenantsState(cargando: true, tenants: state.tenants));
    try {
      emit(TenantsState(tenants: await _fuente.listar()));
    } catch (e) {
      emit(TenantsState(tenants: state.tenants, error: mensajeErrorGateway(e)));
    }
  }

  Future<bool> cambiarEstado(
    TenantPlataforma tenant,
    EstadoTenant estado,
    String motivo,
  ) async {
    emit(TenantsState(tenants: state.tenants, actualizandoId: tenant.id));
    try {
      final actualizado = await _fuente.cambiarEstado(
        tenant.id,
        estado,
        motivo,
      );
      emit(
        TenantsState(
          tenants: [
            for (final t in state.tenants)
              t.id == actualizado.id ? actualizado : t,
          ],
          aviso:
              '${actualizado.nombre} quedó ${actualizado.estado.etiqueta.toLowerCase()}.',
        ),
      );
      return true;
    } catch (e) {
      emit(
        TenantsState(
          tenants: state.tenants,
          aviso: mensajeErrorGateway(e),
          avisoEsError: true,
        ),
      );
      return false;
    }
  }

  Future<List<CambioEstadoTenant>> historial(String tenantId) =>
      _fuente.historial(tenantId);
}

class TenantsPage extends StatelessWidget {
  const TenantsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TenantsCubit, TenantsState>(
      listenWhen: (a, b) => b.aviso != null && a.aviso != b.aviso,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('tenants-aviso'),
              content: Text(state.aviso!),
              backgroundColor: state.avisoEsError
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          );
      },
      builder: (context, state) {
        final cubit = context.read<TenantsCubit>();
        return ManiPagina(
          ancho: ManiAncho.panel,
          encabezado: const ManiEncabezadoPantalla(
            ancho: ManiAncho.panel,
            icono: Icons.domain_outlined,
            titulo: 'Tenants de la plataforma',
            descripcion:
                'Habilita, suspende o inactiva un tenant. Cada cambio pide '
                'un motivo y queda registrado con tu usuario.',
          ),
          alRefrescar: cubit.cargar,
          children: [
            if (state.cargando && state.tenants.isEmpty)
              const ManiCargando()
            else if (state.error != null)
              ManiAvisoTarjeta(
                key: const Key('tenants-error'),
                icono: Icons.error_outline,
                texto: state.error!,
                esError: true,
                accion: ManiBotonPildora(
                  etiqueta: 'Reintentar',
                  icono: Icons.refresh,
                  onPressed: cubit.cargar,
                ),
              )
            else ...[
              if (state.tenants.isNotEmpty) ...[
                _ResumenTenants(tenants: state.tenants),
                ManiGap.vXl,
              ],
              ManiRejilla(
                anchoMinimo: 340,
                maxColumnas: 3,
                espacio: 20,
                children: [
                  for (final t in state.tenants)
                    _TarjetaTenant(
                      tenant: t,
                      actualizando: state.actualizandoId == t.id,
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ResumenTenants extends StatelessWidget {
  const _ResumenTenants({required this.tenants});

  final List<TenantPlataforma> tenants;

  @override
  Widget build(BuildContext context) {
    final t = context.mani;
    final activos = tenants
        .where((x) => x.estado == EstadoTenant.activo)
        .length;
    final suspendidos = tenants
        .where((x) => x.estado == EstadoTenant.suspendido)
        .length;
    final inactivos = tenants
        .where((x) => x.estado == EstadoTenant.inactivo)
        .length;
    return ManiCard(
      color: t.surfaceMuted,
      sombra: t.shadowSm,
      padding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.xl,
        vertical: ManiSpace.md,
      ),
      child: Wrap(
        spacing: ManiSpace.lg,
        runSpacing: ManiSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.analytics_outlined, size: 18, color: t.ink),
              ManiGap.hXs,
              Text(
                'RESUMEN DE RED:',
                style: TextStyle(
                  fontSize: ManiFontSize.caption,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: t.ink,
                ),
              ),
            ],
          ),
          ManiStatusBadge(
            etiqueta: '${tenants.length} registrados',
            tono: ManiTono.marca,
            icono: Icons.domain_rounded,
          ),
          ManiStatusBadge(
            etiqueta: '$activos operativos',
            tono: ManiTono.exito,
            icono: Icons.check_circle_outline,
          ),
          if (suspendidos > 0)
            ManiStatusBadge(
              etiqueta: '$suspendidos en pausa',
              tono: ManiTono.aviso,
              icono: Icons.pause_circle_outline,
            ),
          if (inactivos > 0)
            ManiStatusBadge(
              etiqueta: '$inactivos de baja',
              tono: ManiTono.neutro,
              icono: Icons.remove_circle_outline,
            ),
        ],
      ),
    );
  }
}

/// Fondo del estado del tenant; el texto va en negro sobre fondos claros de
/// estado (contraste AA).
Color _colorEstado(EstadoTenant e) => switch (e) {
  EstadoTenant.activo => ManiColors.successBorder,
  EstadoTenant.suspendido => ManiColors.brand,
  EstadoTenant.inactivo => ManiColors.borderSubtle,
};

class _TarjetaTenant extends StatelessWidget {
  const _TarjetaTenant({required this.tenant, required this.actualizando});

  final TenantPlataforma tenant;
  final bool actualizando;

  @override
  Widget build(BuildContext context) {
    final tk = context.mani;
    final cubit = context.read<TenantsCubit>();
    final t = tenant;
    return ManiCard(
      key: Key('tenant-${t.id}'),
      padding: const EdgeInsets.all(ManiSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ManiSpace.sm),
                decoration: BoxDecoration(
                  color: tk.brand,
                  borderRadius: ManiRadius.brSm,
                  border: Border.all(
                    color: tk.border,
                    width: ManiBorder.regular,
                  ),
                ),
                child: Icon(
                  Icons.apartment_outlined,
                  size: 20,
                  color: tk.onBrand,
                ),
              ),
              ManiGap.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.nombre,
                      style: TextStyle(
                        fontSize: ManiFontSize.bodyLg,
                        fontWeight: FontWeight.w900,
                        color: tk.ink,
                      ),
                    ),
                    Text(
                      t.slug,
                      style: TextStyle(
                        fontSize: ManiFontSize.caption,
                        fontWeight: FontWeight.w600,
                        color: tk.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              ManiGap.hSm,
              Container(
                key: Key('tenant-estado-${t.id}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: ManiSpace.sm,
                  vertical: ManiSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: _colorEstado(t.estado),
                  borderRadius: ManiRadius.brSm,
                  border: Border.all(color: tk.border, width: ManiBorder.thin),
                ),
                child: Text(
                  t.estado.etiqueta,
                  style: const TextStyle(
                    fontSize: ManiFontSize.caption,
                    fontWeight: FontWeight.w800,
                    color: ManiColors.ink,
                  ),
                ),
              ),
            ],
          ),
          ManiGap.vLg,
          Align(
            alignment: Alignment.centerRight,
            child: actualizando
                ? Padding(
                    padding: const EdgeInsets.all(ManiSpace.sm),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tk.ink,
                      ),
                    ),
                  )
                : PopupMenuButton<String>(
                    key: Key('tenant-acciones-${t.id}'),
                    tooltip: 'Acciones del tenant',
                    onSelected: (accion) => accion == 'historial'
                        ? _verHistorial(context, cubit, t)
                        : _cambiar(
                            context,
                            cubit,
                            t,
                            EstadoTenant.desde(accion),
                          ),
                    itemBuilder: (_) => [
                      for (final e in EstadoTenant.values)
                        if (e != t.estado)
                          PopupMenuItem(
                            key: Key('tenant-${e.valor}-${t.id}'),
                            value: e.valor,
                            child: Text(switch (e) {
                              EstadoTenant.activo => 'Habilitar',
                              EstadoTenant.suspendido => 'Suspender',
                              EstadoTenant.inactivo => 'Inactivar',
                            }),
                          ),
                      PopupMenuItem(
                        key: Key('tenant-historial-${t.id}'),
                        value: 'historial',
                        child: const Text('Historial'),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ManiSpace.md,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: tk.surface,
                        borderRadius: ManiRadius.brMd,
                        border: Border.all(
                          color: tk.border,
                          width: ManiBorder.regular,
                        ),
                        boxShadow: [tk.shadowSm],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, size: 18, color: tk.ink),
                          ManiGap.hSm,
                          Text(
                            'Cambiar estado',
                            style: TextStyle(
                              fontSize: ManiFontSize.bodySm,
                              fontWeight: FontWeight.w800,
                              color: tk.ink,
                            ),
                          ),
                          ManiGap.hXs,
                          Icon(Icons.expand_more, size: 18, color: tk.ink),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

Future<void> _cambiar(
  BuildContext context,
  TenantsCubit cubit,
  TenantPlataforma tenant,
  EstadoTenant estado,
) async {
  final motivo = await showDialog<String>(
    context: context,
    builder: (_) => _DialogoMotivo(tenant: tenant, estado: estado),
  );
  if (motivo == null) return;
  await cubit.cambiarEstado(tenant, estado, motivo);
}

Future<void> _verHistorial(
  BuildContext context,
  TenantsCubit cubit,
  TenantPlataforma tenant,
) => showDialog<void>(
  context: context,
  builder: (_) => AlertDialog(
    title: Text('Historial · ${tenant.nombre}'),
    content: SizedBox(
      width: 460,
      child: FutureBuilder<List<CambioEstadoTenant>>(
        future: cubit.historial(tenant.id),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 80, child: ManiCargando());
          }
          if (snap.hasError) return Text(mensajeErrorGateway(snap.error!));
          final cambios = snap.data!;
          if (cambios.isEmpty) return const Text('Sin cambios registrados.');
          return ListView(
            shrinkWrap: true,
            children: [
              for (final c in cambios)
                ListTile(
                  dense: true,
                  title: Text('${c.anterior.etiqueta} → ${c.nuevo.etiqueta}'),
                  subtitle: Text('${c.fecha?.toLocal() ?? ''} · ${c.motivo}'),
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

/// Motivo del cambio: entre 10 y 500 caracteres, como exige Core.
class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo({required this.tenant, required this.estado});

  final TenantPlataforma tenant;
  final EstadoTenant estado;

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  bool get _valido {
    final n = _motivo.text.trim().runes.length;
    return n >= 10 && n <= 500;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.estado.etiqueta}: ${widget.tenant.nombre}'),
      content: SizedBox(
        width: 420,
        child: TextField(
          key: const Key('tenant-motivo'),
          controller: _motivo,
          maxLines: 3,
          maxLength: 500,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Motivo del cambio',
            helperText: 'Mínimo 10 caracteres',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ManiButton(
          key: const Key('tenant-confirmar'),
          etiqueta: 'Confirmar',
          onPressed: _valido
              ? () => Navigator.of(context).pop(_motivo.text.trim())
              : null,
        ),
      ],
    );
  }
}
