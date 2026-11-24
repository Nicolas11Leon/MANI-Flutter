import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_card.dart';

import '../../domain/entities/categoria_servicio.dart';
import 'flujo_operativo_estilo.dart';

/// Tarjeta de una categoría en el catálogo del administrador.
class CategoriaCard extends StatelessWidget {
  const CategoriaCard({
    super.key,
    required this.categoria,
    this.recienCreada = false,
    this.cambiandoEstado = false,
    this.onCambiarEstado,
  });

  final CategoriaServicio categoria;

  /// Resalta la tarjeta justo después de crearla.
  final bool recienCreada;

  /// Indica que se está enviando el cambio de estado (`ACTIVO` / `INACTIVO`).
  final bool cambiandoEstado;

  /// Callback para ocultar o activar la categoría sin cancelar servicios en curso.
  final ValueChanged<bool>? onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    final c = categoria;
    return ManiCard(
      key: ValueKey('card-categoria-${c.id}'),
      seleccionada: recienCreada,
      sombra: ManiShadow.sm,
      padding: const EdgeInsets.all(ManiSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.flujo?.fondo ?? context.mani.background,
                  borderRadius: ManiRadius.brMd,
                  border: Border.all(
                    color: context.mani.border,
                    width: ManiBorder.regular,
                  ),
                ),
                child: Icon(
                  Icons.home_repair_service_rounded,
                  color: context.mani.ink,
                  size: 22,
                ),
              ),
              ManiGap.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ManiFontSize.body,
                        fontWeight: FontWeight.w900,
                        color: context.mani.ink,
                      ),
                    ),
                    ManiGap.vXs,
                    _EstadoVisibilidad(activa: c.activa),
                  ],
                ),
              ),
              if (recienCreada) const _EtiquetaNueva(),
            ],
          ),
          ManiGap.vSm,
          FlujoOperativoBadge(flujo: c.flujo),
          ManiGap.vSm,
          Row(
            children: [
              Icon(
                Icons.engineering_outlined,
                size: 14,
                color: context.mani.inkSubtle,
              ),
              ManiGap.hXs,
              Expanded(
                child: Text(
                  switch (c.aliadosAsociados) {
                    0 => 'Aún sin aliados',
                    1 => '1 aliado',
                    final n => '$n aliados',
                  },
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ManiFontSize.caption,
                    fontWeight: FontWeight.w600,
                    color: context.mani.inkMuted,
                  ),
                ),
              ),
              if (onCambiarEstado != null) ...[
                ManiGap.hSm,
                _BotonVisibilidad(
                  categoriaId: c.id,
                  activa: c.activa,
                  cargando: cambiandoEstado,
                  onTap: () => onCambiarEstado!(!c.activa),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonVisibilidad extends StatelessWidget {
  const _BotonVisibilidad({
    required this.categoriaId,
    required this.activa,
    required this.cargando,
    required this.onTap,
  });

  final String categoriaId;
  final bool activa;
  final bool cargando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: activa
          ? 'Ocultar del catálogo público sin afectar servicios en curso'
          : 'Volver a mostrar en el catálogo público',
      child: Material(
        color: activa ? context.mani.background : context.mani.brand,
        borderRadius: ManiRadius.brXs,
        child: InkWell(
          key: ValueKey('toggle-estado-categoria-$categoriaId'),
          borderRadius: ManiRadius.brXs,
          onTap: cargando ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ManiSpace.sm,
              vertical: ManiSpace.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: ManiRadius.brXs,
              border: Border.all(
                color: context.mani.border,
                width: ManiBorder.thin,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cargando)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.mani.ink,
                    ),
                  )
                else
                  Icon(
                    activa
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 13,
                    color: context.mani.ink,
                  ),
                ManiGap.hXs,
                Text(
                  cargando ? 'Guardando...' : (activa ? 'Ocultar' : 'Activar'),
                  style: TextStyle(
                    fontSize: ManiFontSize.micro,
                    fontWeight: FontWeight.w800,
                    color: context.mani.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EstadoVisibilidad extends StatelessWidget {
  const _EstadoVisibilidad({required this.activa});

  final bool activa;

  @override
  Widget build(BuildContext context) {
    final color = activa ? ManiColors.success : context.mani.inkSubtle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          activa ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 14,
          color: color,
        ),
        ManiGap.hXs,
        Flexible(
          child: Text(
            activa ? 'Visible para clientes' : 'Oculta',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ManiFontSize.caption,
              fontWeight: FontWeight.w700,
              color: activa ? ManiColors.success : context.mani.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _EtiquetaNueva extends StatelessWidget {
  const _EtiquetaNueva();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.sm,
        vertical: ManiSpace.xs,
      ),
      decoration: BoxDecoration(
        color: context.mani.ink,
        borderRadius: ManiRadius.brXs,
      ),
      child: Text(
        'NUEVA',
        style: TextStyle(
          fontSize: ManiFontSize.nano,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: context.mani.brand,
        ),
      ),
    );
  }
}
