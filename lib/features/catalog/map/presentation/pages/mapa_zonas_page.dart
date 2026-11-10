import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mani/features/catalog/map/presentation/bloc/mapa_cubit.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

/// Mapa de zonas, barrios y sitios (HU-M04-07 / SCRUM-1396).
///
/// Dibuja los límites que entrega el catálogo. Sin GPS ni ubicación del
/// dispositivo: no decide elegibilidad ni cobertura, que es lo que ADR-0011
/// reserva para el despacho.
class MapaZonasPage extends StatelessWidget {
  const MapaZonasPage({super.key});

  /// Centro de respaldo mientras no hay límites: el centro de Bogotá. Solo
  /// encuadra la vista; no se dibuja nada en esa posición.
  static const centroBogota = LatLng(4.6533, -74.0836);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManiEncabezadoPantalla(
            icono: Icons.map_rounded,
            titulo: 'Mapa de zonas',
          ),
          Expanded(
            child: BlocBuilder<MapaCubit, MapaState>(
              builder: (context, state) {
                if (state.estado == MapaEstado.cargando &&
                    state.geometrias.isEmpty) {
                  return const ManiCargando();
                }
                if (state.estado == MapaEstado.error) {
                  return _Aviso(
                    icono: Icons.error_outline,
                    titulo: 'No se pudo cargar el mapa',
                    detalle: state.mensajeError ?? 'Intenta de nuevo.',
                    accion: () => context.read<MapaCubit>().cargar(),
                  );
                }
                return Column(
                  children: [
                    if (state.localidades.length > 1)
                      _SelectorLocalidad(state: state),
                    Expanded(
                      // Hay algo que dibujar si existe un límite o una sede ubicada:
                      // con solo sedes el mapa sigue teniendo sentido.
                      child: state.geometrias.isEmpty && state.sitios.isEmpty
                          ? const _Aviso(
                              icono: Icons.map_outlined,
                              titulo: 'Sin límites para mostrar',
                              detalle:
                                  'El catálogo no tiene todavía los límites de esta zona. '
                                  'No se dibuja una forma aproximada.',
                            )
                          : _Mapa(state: state),
                    ),
                    if (state.sinGeometria.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(ManiSpace.md),
                        child: Text(
                          '${state.sinGeometria.length} zona(s) sin límite cargado: no se dibujan.',
                          key: const Key('mapa_sin_geometria'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (state.coberturaPropia.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: ManiSpace.md,
                          right: ManiSpace.md,
                          top: ManiSpace.sm,
                        ),
                        child: Text(
                          'En verde, las zonas que ya declaraste como cobertura. '
                          'Para cambiarlas, usa Cobertura en el menú.',
                          key: const Key('mapa_leyenda_cobertura'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (state.sitiosSinUbicacion > 0)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: ManiSpace.md,
                          right: ManiSpace.md,
                          bottom: ManiSpace.md,
                        ),
                        child: Text(
                          '${state.sitiosSinUbicacion} sede(s) sin ubicación capturada: '
                          'no se marcan en el mapa.',
                          key: const Key('mapa_sitios_sin_ubicacion'),
                          style: Theme.of(context).textTheme.bodySmall,
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

class _SelectorLocalidad extends StatelessWidget {
  const _SelectorLocalidad({required this.state});

  final MapaState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.lg,
        vertical: ManiSpace.sm,
      ),
      child: DropdownButtonFormField<String>(
        key: const Key('mapa_selector_localidad'),
        initialValue: state.localidadId,
        decoration: const InputDecoration(labelText: 'Localidad'),
        items: state.localidades
            .map(
              (l) => DropdownMenuItem(
                value: '${l['id']}',
                child: Text('${l['name'] ?? ''}'),
              ),
            )
            .toList(growable: false),
        onChanged: (id) {
          if (id != null) context.read<MapaCubit>().seleccionar(id);
        },
      ),
    );
  }
}

class _Mapa extends StatelessWidget {
  const _Mapa({required this.state});

  final MapaState state;

  @override
  Widget build(BuildContext context) {
    final poligonos = <Polygon>[];
    for (final g in state.geometrias) {
      // El barrio se distingue de la localidad por color, no por rótulo:
      // rotular cada polígono tapa el mapa cuando hay varios.
      final esBarrio = g.nivel == 'BARRIO';
      // Al aliado se le resalta en verde lo que ya declaró como cobertura, para
      // que vea de un golpe dónde atiende. Es solo lectura: declarar cobertura
      // es de `/aliado/cobertura`, por lista y hasta localidad.
      final esCobertura = state.coberturaPropia.contains(g.zonaId);
      final base = esCobertura
          ? const Color(0xFF166534)
          : (esBarrio ? const Color(0xFFC2410C) : const Color(0xFF1D4ED8));
      for (final anillo in g.anillos) {
        poligonos.add(
          Polygon(
            points: anillo,
            borderStrokeWidth: esCobertura ? 3 : 2,
            borderColor: base,
            color: base.withValues(alpha: esCobertura ? 0.30 : 0.18),
          ),
        );
      }
    }

    // El encuadre considera los límites y las sedes, para que una sede que
    // cae fuera del polígono no quede fuera de la vista.
    final puntos = [
      ...state.geometrias.expand((g) => g.anillos).expand((a) => a),
      ...state.sitios.map((s) => LatLng(s.latitud!, s.longitud!)),
    ];

    // Un solo punto, o varios en la misma posición, dan un rectángulo de área
    // cero y `CameraFit.bounds` falla con «Camera zoom must be finite». Es el
    // caso real de un cliente con una sola sede ubicada y sin límites
    // cargados, así que se encuadra centrando en el punto.
    final distintos = <String>{
      for (final p in puntos) '${p.latitude},${p.longitude}',
    };
    final encuadrable = distintos.length > 1;
    final bounds = encuadrable ? LatLngBounds.fromPoints(puntos) : null;
    final centro = puntos.isEmpty ? MapaZonasPage.centroBogota : puntos.first;

    return FlutterMap(
      key: const Key('mapa_zonas'),
      options: MapOptions(
        initialCenter: centro,
        // Con un solo punto se acerca lo suficiente para ubicarlo en su
        // manzana; con varios, el encuadre lo decide `CameraFit`.
        initialZoom: puntos.isEmpty ? 12 : 15,
        initialCameraFit: bounds == null
            ? null
            : CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(ManiSpace.xxl),
              ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'co.mani.app',
        ),
        PolygonLayer(polygons: poligonos),
        // Sedes propias con punto capturado. Las que no lo tienen no se
        // dibujan en el centroide de su zona: se cuentan aparte (C2).
        MarkerLayer(
          markers: [
            for (final s in state.sitios)
              Marker(
                point: LatLng(s.latitud!, s.longitud!),
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: Tooltip(
                  message: s.nombre,
                  child: const Icon(
                    Icons.place,
                    size: 34,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
          ],
        ),
        // La licencia de la fuente obliga a acreditarla donde se muestren los
        // límites, así que la atribución no es decorativa.
        RichAttributionWidget(
          attributions: [
            const TextSourceAttribution('OpenStreetMap contributors'),
            for (final a in state.atribuciones) TextSourceAttribution(a),
          ],
        ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ManiSpace.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 48),
            ManiGap.vMd,
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            ManiGap.vSm,
            Text(detalle, textAlign: TextAlign.center),
            if (accion != null) ...[
              ManiGap.vLg,
              FilledButton(onPressed: accion, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
