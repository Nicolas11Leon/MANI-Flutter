import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';

import '../../domain/entities/nueva_solicitud.dart';
import '../bloc/crear_solicitud_cubit.dart';
import 'encabezado_paso.dart';

/// Paso 3: ¿dónde es el servicio? Una dirección guardada o una nueva.
class PasoUbicacion extends StatelessWidget {
  const PasoUbicacion({
    super.key,
    required this.direccion,
    required this.busquedaZona,
    required this.onBuscarZona,
  });

  final TextEditingController direccion;
  final TextEditingController busquedaZona;
  final ValueChanged<String> onBuscarZona;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CrearSolicitudCubit>().state;
    final cubit = context.read<CrearSolicitudCubit>();
    final nueva = state.modo == ModoUbicacion.nuevaDireccion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EncabezadoPaso(
          titulo: '¿Dónde es el servicio?',
          subtitulo:
              'Los aliados solo ven el barrio. La dirección exacta la recibe '
              'únicamente el aliado que tome tu solicitud.',
        ),
        ManiGap.vLg,
        for (final s in state.catalogo.sitios) ...[
          _Opcion(
            clave: ValueKey('sitio-${s.id}'),
            seleccionada: !nueva && state.sitioId == s.id,
            icono: Icons.home_outlined,
            titulo: s.direccion,
            subtitulo: s.ubicacion,
            onTap: () => cubit.elegirSitio(s.id),
          ),
          ManiGap.vSm,
        ],
        _Opcion(
          clave: const ValueKey('opcion-nueva-direccion'),
          seleccionada: nueva,
          icono: Icons.add_location_alt_outlined,
          titulo: state.catalogo.sitios.isEmpty
              ? 'Dirección del servicio'
              : 'Usar otra dirección',
          subtitulo: 'Escribe la dirección y elige el barrio',
          onTap: cubit.usarNuevaDireccion,
        ),
        if (nueva) ...[
          ManiGap.vMd,
          TextField(
            key: const ValueKey('campo-direccion'),
            controller: direccion,
            onChanged: cubit.actualizarDireccion,
            maxLength: NuevaDireccion.maximo,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: _decoracion(
              context,
              etiqueta: 'Dirección',
              hint: 'Ej: Calle Colima 120, Apto 401',
              icono: Icons.signpost_outlined,
            ),
          ),
          ManiGap.vXs,
          if (state.zona != null)
            _ZonaElegida(
              etiqueta: state.zona!.etiqueta,
              onCambiar: () {
                busquedaZona.clear();
                cubit.quitarZona();
              },
            )
          else ...[
            TextField(
              key: const ValueKey('campo-buscar-zona'),
              controller: busquedaZona,
              onChanged: onBuscarZona,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: _decoracion(
                context,
                etiqueta: 'Barrio o localidad',
                hint: 'Escribe al menos 2 letras',
                icono: Icons.search_rounded,
              ),
            ),
            ManiGap.vSm,
            if (state.buscandoZonas)
              Padding(
                padding: EdgeInsets.all(ManiSpace.md),
                child: Center(
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: context.mani.ink,
                    ),
                  ),
                ),
              )
            else if (state.zonasEncontradas.isNotEmpty)
              // Material propio: los ListTile pintan ahí su efecto de toque.
              Material(
                color: context.mani.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: ManiRadius.brMd,
                  side: ManiBorder.sideThin,
                ),
                child: Column(
                  children: [
                    for (final z in state.zonasEncontradas)
                      ListTile(
                        key: ValueKey('zona-${z.id}'),
                        dense: true,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(
                          z.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: z.zonaPadre == null
                            ? null
                            : Text(z.zonaPadre!),
                        onTap: () => cubit.elegirZona(z),
                      ),
                  ],
                ),
              )
            else if (busquedaZona.text.trim().length >= 2)
              Padding(
                padding: EdgeInsets.all(ManiSpace.sm),
                child: Text(
                  'No encontramos ese barrio. Prueba con otro nombre.',
                  style: TextStyle(color: context.mani.inkMuted),
                ),
              ),
          ],
        ],
      ],
    );
  }

  static InputDecoration _decoracion(
    BuildContext context, {
    required String etiqueta,
    required String hint,
    required IconData icono,
  }) {
    OutlineInputBorder borde(double ancho) => OutlineInputBorder(
      borderRadius: ManiRadius.brMd,
      borderSide: BorderSide(color: context.mani.ink, width: ancho),
    );
    return InputDecoration(
      labelText: etiqueta,
      hintText: hint,
      prefixIcon: Icon(icono, color: context.mani.ink),
      filled: true,
      fillColor: context.mani.surface,
      enabledBorder: borde(2),
      focusedBorder: borde(2.5),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.clave,
    required this.seleccionada,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final Key clave;
  final bool seleccionada;
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radio = ManiRadius.brMd;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: seleccionada,
      button: true,
      label: '$titulo, $subtitulo',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: ManiMotion.fast,
        decoration: BoxDecoration(
          color: seleccionada ? context.mani.brandSoft : context.mani.surface,
          borderRadius: radio,
          border: Border.all(
            color: context.mani.border,
            width: seleccionada ? 2.5 : 1.5,
          ),
          boxShadow: [if (seleccionada) ManiShadow.sm],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: clave,
            borderRadius: radio,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(ManiSpace.md),
              child: Row(
                children: [
                  Icon(icono, color: context.mani.ink),
                  ManiGap.hMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          subtitulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ManiFontSize.caption,
                            color: context.mani.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    seleccionada
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: context.mani.ink,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZonaElegida extends StatelessWidget {
  const _ZonaElegida({required this.etiqueta, required this.onCambiar});

  final String etiqueta;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('zona-elegida'),
      padding: const EdgeInsets.fromLTRB(
        ManiSpace.md,
        ManiSpace.sm,
        ManiSpace.sm,
        ManiSpace.sm,
      ),
      decoration: BoxDecoration(
        color: ManiColors.successContainer,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: context.mani.border, width: ManiBorder.thin),
      ),
      child: Row(
        children: [
          Icon(Icons.place_rounded, color: context.mani.ink),
          ManiGap.hSm,
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            key: const ValueKey('btn-cambiar-zona'),
            onPressed: onCambiar,
            child: Text(
              'Cambiar',
              style: TextStyle(
                color: context.mani.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
