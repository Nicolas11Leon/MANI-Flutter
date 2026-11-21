import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mani/features/catalog/map/presentation/bloc/mapa_cubit.dart';

/// Mapa de zonas, barrios y sedes (HU-M04-07 / SCRUM-1396), sin armazón de
/// pantalla, para poder montarlo **dentro** de la pantalla donde el dato tiene
/// sentido: la cobertura del aliado y las sedes del cliente. Un mapa en una
/// pantalla aparte obliga a recordar lo que se vio en la otra.
///
/// Dibuja los límites que entrega el catálogo. Sin GPS ni ubicación del
/// dispositivo: no decide elegibilidad ni cobertura, que es lo que ADR-0011
/// reserva para el despacho.
class MapaZonas extends StatelessWidget {
  const MapaZonas({
    super.key,
    this.coberturaResaltada,
    this.leyendaCobertura,
    this.alto,
    this.onZonaTocada,
  });

  /// Zonas a resaltar en verde. Cuando se monta dentro de la pantalla de
  /// cobertura se pasa **la selección en curso**, no la guardada, para que el
  /// aliado vea pintado lo que lleva marcado antes de guardar. Sin este
  /// parámetro se usa la cobertura ya declarada que trae el estado.
  final Set<String>? coberturaResaltada;

  /// Texto bajo el mapa que explica el resaltado. Cambia según dónde se monte:
  /// en cobertura describe una selección en curso; suelto, lo ya declarado.
  final String? leyendaCobertura;

  /// Alto fijo cuando el mapa va embebido en una pantalla que ya hace scroll.
  /// Sin alto ocupa el espacio disponible, que es lo que quiere una pantalla
  /// dedicada al mapa.
  final double? alto;

  /// Con esto el mapa **es el selector**: cada zona lleva encima su nombre y
  /// una marca de verificación, y tocarla la alterna. Sigue eligiéndose una
  /// zona del catálogo —lo que cambia es el gesto, no el dato—, así que
  /// ADR-0011 se mantiene: sin geometría propia, sin radio y sin
  /// geolocalización en vivo.
  ///
  /// Sin esto el mapa es de solo lectura.
  final void Function(String zonaId)? onZonaTocada;

  /// Centro de respaldo mientras no hay límites: el centro de Bogotá. Solo
  /// encuadra la vista; no se dibuja nada en esa posición.
  static const centroBogota = LatLng(4.6533, -74.0836);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapaCubit, MapaState>(
      builder: (context, state) {
        if (state.estado == MapaEstado.cargando && state.geometrias.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.estado == MapaEstado.error) {
          return _Aviso(
            icono: Icons.error_outline,
            titulo: 'No se pudo cargar el mapa',
            detalle: state.mensajeError ?? 'Intenta de nuevo.',
            accion: () => context.read<MapaCubit>().cargar(),
          );
        }

        final resaltadas = coberturaResaltada ?? state.coberturaPropia;
        // Hay algo que dibujar si existe un límite o una sede ubicada: con
        // solo sedes el mapa sigue teniendo sentido.
        final lienzo = state.geometrias.isEmpty && state.sitios.isEmpty
            ? const _Aviso(
                icono: Icons.map_outlined,
                titulo: 'Sin límites para mostrar',
                detalle:
                    'El catálogo no tiene todavía los límites de esta zona. '
                    'No se dibuja una forma aproximada.',
              )
            : _Mapa(
                state: state,
                resaltadas: resaltadas,
                onZonaTocada: onZonaTocada,
              );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En modo selector están todas las localidades a la vez, así que
            // un desplegable para elegir una sola sobra.
            if (onZonaTocada == null && state.localidades.length > 1)
              _SelectorLocalidad(state: state),
            if (alto == null)
              Expanded(child: lienzo)
            else
              SizedBox(height: alto, child: lienzo),
            if (state.sinGeometria.isNotEmpty)
              _Nota(
                texto:
                    '${state.sinGeometria.length} zona(s) sin límite cargado: no se dibujan.',
                clave: const Key('mapa_sin_geometria'),
              ),
            if (resaltadas.isNotEmpty)
              _Nota(
                texto:
                    leyendaCobertura ??
                    'En verde, las zonas que ya declaraste como cobertura.',
                clave: const Key('mapa_leyenda_cobertura'),
              ),
            if (state.sitiosSinUbicacion > 0)
              _Nota(
                texto:
                    '${state.sitiosSinUbicacion} sede(s) sin ubicación capturada: '
                    'no se marcan en el mapa.',
                clave: const Key('mapa_sitios_sin_ubicacion'),
              ),
          ],
        );
      },
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.texto, required this.clave});

  final String texto;
  final Key clave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        texto,
        key: clave,
        style: Theme.of(context).textTheme.bodySmall,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

/// Encuadre que corresponde a un estado: o un rectángulo que contiene todo lo
/// dibujable, o un centro con zoom cuando no hay con qué formar un rectángulo.
///
/// Es un valor comparable a propósito: así se sabe si el encuadre **cambió** y
/// solo entonces se mueve la cámara, en vez de reencuadrar en cada repintado y
/// deshacer el desplazamiento que haya hecho el usuario.
@immutable
class _Encuadre {
  const _Encuadre({required this.centro, required this.zoom, this.limites});

  final LatLng centro;
  final double zoom;
  final LatLngBounds? limites;

  factory _Encuadre.de(MapaState state) {
    // El encuadre considera los límites y las sedes, para que una sede que cae
    // fuera del polígono no quede fuera de la vista.
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
    return _Encuadre(
      centro: puntos.isEmpty ? MapaZonas.centroBogota : puntos.first,
      // Con un solo punto se acerca lo suficiente para ubicarlo en su manzana;
      // con varios, el encuadre lo decide `CameraFit`.
      zoom: puntos.isEmpty ? 12 : 15,
      limites: distintos.length > 1 ? LatLngBounds.fromPoints(puntos) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _Encuadre &&
      other.centro == centro &&
      other.zoom == zoom &&
      other.limites?.north == limites?.north &&
      other.limites?.south == limites?.south &&
      other.limites?.east == limites?.east &&
      other.limites?.west == limites?.west;

  @override
  int get hashCode => Object.hash(
    centro,
    zoom,
    limites?.north,
    limites?.south,
    limites?.east,
    limites?.west,
  );
}

class _Mapa extends StatefulWidget {
  const _Mapa({
    required this.state,
    required this.resaltadas,
    this.onZonaTocada,
  });

  final MapaState state;
  final Set<String> resaltadas;
  final void Function(String zonaId)? onZonaTocada;

  @override
  State<_Mapa> createState() => _MapaState();
}

class _MapaState extends State<_Mapa> {
  final _controlador = MapController();

  /// `fitCamera` y `move` exigen que el mapa ya esté montado; antes de
  /// `onMapReady` lanzan. El primer encuadre lo hace `initialCameraFit`.
  bool _listo = false;

  @override
  void didUpdateWidget(covariant _Mapa anterior) {
    super.didUpdateWidget(anterior);
    // Al elegir otra localidad cambian los límites, pero la cámara se había
    // fijado con `initialCameraFit`, que solo actúa al construir: el mapa se
    // quedaba sobre la localidad anterior. Se reencuadra al cambiar.
    final previo = _Encuadre.de(anterior.state);
    if (_listo && _Encuadre.de(widget.state) != previo) _encuadrar();
  }

  void _encuadrar() {
    final encuadre = _Encuadre.de(widget.state);
    if (encuadre.limites != null) {
      _controlador.fitCamera(
        CameraFit.bounds(
          bounds: encuadre.limites!,
          padding: const EdgeInsets.all(24),
        ),
      );
    } else {
      _controlador.move(encuadre.centro, encuadre.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final encuadre = _Encuadre.de(widget.state);
    final poligonos = <Polygon>[];
    for (final g in widget.state.geometrias) {
      // El barrio se distingue de la localidad por color, no por rótulo:
      // rotular cada polígono tapa el mapa cuando hay varios.
      final esBarrio = g.nivel == 'BARRIO';
      // Verde para lo que es cobertura del aliado: ya declarada cuando el mapa
      // va suelto, o la selección en curso cuando va dentro de la pantalla de
      // cobertura, para que vea pintado lo que marca.
      final esCobertura = widget.resaltadas.contains(g.zonaId);
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

    return FlutterMap(
      key: const Key('mapa_zonas'),
      mapController: _controlador,
      options: MapOptions(
        initialCenter: encuadre.centro,
        initialZoom: encuadre.zoom,
        initialCameraFit: encuadre.limites == null
            ? null
            : CameraFit.bounds(
                bounds: encuadre.limites!,
                padding: const EdgeInsets.all(24),
              ),
        onMapReady: () => _listo = true,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'co.mani.app',
        ),
        PolygonLayer(polygons: poligonos),
        // Modo selector: cada zona lleva su nombre y una marca que dice si
        // está elegida. Tocarla la alterna, igual que la casilla de la lista.
        if (widget.onZonaTocada != null)
          MarkerLayer(
            markers: [
              for (final g in widget.state.geometrias)
                if (_centroDe(g.anillos) case final centro?)
                  Marker(
                    point: centro,
                    width: 128,
                    height: 56,
                    child: _MarcaZona(
                      nombre: g.nombre,
                      elegida: widget.resaltadas.contains(g.zonaId),
                      onTocar: () => widget.onZonaTocada!(g.zonaId),
                    ),
                  ),
            ],
          ),
        // Sedes propias con punto capturado. Las que no lo tienen no se
        // dibujan en el centroide de su zona: se cuentan aparte (C2).
        MarkerLayer(
          markers: [
            for (final s in widget.state.sitios)
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
            for (final a in widget.state.atribuciones) TextSourceAttribution(a),
          ],
        ),
      ],
    );
  }
}

/// Punto donde colocar la marca de una zona: el promedio de los vértices del
/// anillo más grande. No es el centroide exacto del polígono, y no hace falta
/// que lo sea: solo sitúa una etiqueta dentro de la zona.
LatLng? _centroDe(List<List<LatLng>> anillos) {
  if (anillos.isEmpty) return null;
  var mayor = anillos.first;
  for (final a in anillos) {
    if (a.length > mayor.length) mayor = a;
  }
  if (mayor.isEmpty) return null;
  var lat = 0.0;
  var lon = 0.0;
  for (final p in mayor) {
    lat += p.latitude;
    lon += p.longitude;
  }
  return LatLng(lat / mayor.length, lon / mayor.length);
}

/// Nombre de la zona y su marca de elegida, encima del polígono.
class _MarcaZona extends StatelessWidget {
  const _MarcaZona({
    required this.nombre,
    required this.elegida,
    required this.onTocar,
  });

  final String nombre;
  final bool elegida;
  final VoidCallback onTocar;

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF166534);
    return GestureDetector(
      onTap: onTocar,
      behavior: HitTestBehavior.opaque,
      child: Tooltip(
        message: elegida ? 'Quitar $nombre' : 'Agregar $nombre',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: Key('mapa_marca_$nombre'),
              decoration: BoxDecoration(
                color: elegida ? verde : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: elegida ? verde : Colors.black54,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Icon(
                elegida ? Icons.check : Icons.add,
                size: 18,
                color: elegida ? Colors.white : Colors.black54,
              ),
            ),
            const SizedBox(height: 2),
            // Fondo propio: sobre las teselas el texto suelto no se lee.
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Text(
                nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 48),
            const SizedBox(height: 12),
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(detalle, textAlign: TextAlign.center),
            if (accion != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: accion, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
