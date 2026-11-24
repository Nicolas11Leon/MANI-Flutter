import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/network/gateway_exception.dart';
import 'package:mani/features/catalog/map/data/mapa_remote_datasource.dart';
import 'package:mani/features/catalog/map/domain/entities/geometria_zona.dart';

enum MapaEstado { inicial, cargando, listo, vacio, error }

class MapaState extends Equatable {
  const MapaState({
    this.estado = MapaEstado.inicial,
    this.localidades = const [],
    this.localidadId,
    this.geometrias = const [],
    this.sinGeometria = const [],
    this.atribuciones = const [],
    this.sitios = const [],
    this.sitiosSinUbicacion = 0,
    this.coberturaPropia = const {},
    this.mensajeError,
  });

  final MapaEstado estado;

  /// Localidades del catálogo, para elegir qué pintar.
  final List<Map<String, dynamic>> localidades;
  final String? localidadId;

  final List<GeometriaZona> geometrias;

  /// Zonas del catálogo que todavía no tienen límite cargado. Se muestran para
  /// que el usuario sepa que faltan, en lugar de dibujar algo inventado (C2).
  final List<String> sinGeometria;
  final List<String> atribuciones;

  /// Sedes propias que se pueden dibujar, de la localidad seleccionada.
  final List<SitioUbicado> sitios;

  /// Cuántas sedes de esa localidad no tienen punto capturado. Se informa en
  /// vez de ubicarlas en el centroide de su zona (C2).
  final int sitiosSinUbicacion;

  /// Zonas que el aliado de la sesión declaró como cobertura, para resaltarlas.
  /// Vacío para los demás roles. **Es lectura:** declarar cobertura es de
  /// `/aliado/cobertura`, por lista y hasta localidad.
  final Set<String> coberturaPropia;

  final String? mensajeError;

  MapaState copyWith({
    MapaEstado? estado,
    List<Map<String, dynamic>>? localidades,
    String? localidadId,
    List<GeometriaZona>? geometrias,
    List<String>? sinGeometria,
    List<String>? atribuciones,
    List<SitioUbicado>? sitios,
    int? sitiosSinUbicacion,
    Set<String>? coberturaPropia,
    String? mensajeError,
  }) {
    return MapaState(
      estado: estado ?? this.estado,
      localidades: localidades ?? this.localidades,
      localidadId: localidadId ?? this.localidadId,
      geometrias: geometrias ?? this.geometrias,
      sinGeometria: sinGeometria ?? this.sinGeometria,
      atribuciones: atribuciones ?? this.atribuciones,
      sitios: sitios ?? this.sitios,
      sitiosSinUbicacion: sitiosSinUbicacion ?? this.sitiosSinUbicacion,
      coberturaPropia: coberturaPropia ?? this.coberturaPropia,
      mensajeError: mensajeError,
    );
  }

  @override
  List<Object?> get props => [
    estado,
    localidades,
    localidadId,
    geometrias,
    sinGeometria,
    atribuciones,
    sitios,
    sitiosSinUbicacion,
    coberturaPropia,
    mensajeError,
  ];
}

/// Visualización cartográfica del catálogo (HU-M04-07 / SCRUM-1396).
///
/// Pinta los límites reales de una localidad y de sus barrios. No usa GPS ni
/// ubicación del dispositivo: las coordenadas salen del catálogo, que es lo
/// que la historia pide y lo que ADR-0011 permite, porque esto no decide
/// elegibilidad ni cobertura.
class MapaCubit extends Cubit<MapaState> {
  MapaCubit(this._datos) : super(const MapaState());

  final MapaRemoteDataSource _datos;

  /// Tope por petición que impone el contrato de Core.
  static const _porPeticion = GatewayMapaDataSource.maxZonasPorPeticion;

  Future<void> cargar() async {
    emit(state.copyWith(estado: MapaEstado.cargando));
    try {
      final zonas = await _datos.listarZonas();
      final localidades = zonas
          .where((z) => z['level'] == 'LOCALIDAD' && z['selectable'] != false)
          .toList(growable: false);
      if (localidades.isEmpty) {
        emit(state.copyWith(estado: MapaEstado.vacio, localidades: const []));
        return;
      }
      _zonas = zonas;
      // Las sedes son del cliente de la sesión. Un admin recibe error del
      // servicio, y eso no debe tumbar el mapa: se queda sin sedes y sigue
      // mostrando las zonas, que es su contenido principal.
      _misSitios = await _cargarSitiosTolerante();
      // La cobertura propia solo la tiene el aliado; los demás roles reciben
      // error y el mapa sigue igual, sin resaltado.
      final cobertura = await _cargarCoberturaTolerante();
      emit(
        state.copyWith(
          estado: MapaEstado.listo,
          localidades: localidades,
          coberturaPropia: cobertura,
        ),
      );
      await seleccionar('${localidades.first['id']}');
    } on GatewayException catch (e) {
      emit(state.copyWith(estado: MapaEstado.error, mensajeError: e.message));
    }
  }

  /// Carga **todas** las localidades a la vez, sin barrios.
  ///
  /// Es el modo que necesita la declaración de cobertura: el aliado elige
  /// sobre el mapa de la ciudad entera, así que no sirve mostrarle una
  /// localidad cada vez. Se pide en tandas porque el contrato topa cada
  /// petición en [MapaRemoteDataSource] y la ciudad puede tener más.
  Future<void> cargarPanoramica() async {
    emit(state.copyWith(estado: MapaEstado.cargando));
    try {
      final zonas = await _datos.listarZonas();
      final localidades = zonas
          .where((z) => z['level'] == 'LOCALIDAD' && z['selectable'] != false)
          .toList(growable: false);
      if (localidades.isEmpty) {
        emit(state.copyWith(estado: MapaEstado.vacio, localidades: const []));
        return;
      }
      _zonas = zonas;
      final cobertura = await _cargarCoberturaTolerante();

      final ids = localidades.map((z) => '${z['id']}').toList();
      final pedido = await _pedirEnTandas(ids);
      final geometrias = pedido.geometrias;
      final sinGeometria = pedido.sinGeometria;
      final atribuciones = pedido.atribuciones;

      emit(
        state.copyWith(
          estado: geometrias.isEmpty ? MapaEstado.vacio : MapaEstado.listo,
          localidades: localidades,
          geometrias: geometrias,
          sinGeometria: sinGeometria,
          atribuciones: atribuciones,
          coberturaPropia: cobertura,
          sitios: const [],
          sitiosSinUbicacion: 0,
        ),
      );
    } on GatewayException catch (e) {
      emit(state.copyWith(estado: MapaEstado.error, mensajeError: e.message));
    }
  }

  /// Pide los límites de [ids] partiéndolos en tandas del tope que impone el
  /// contrato, y junta lo recibido: solo los dibujables, lo que no tiene límite
  /// y las atribuciones sin repetir.
  Future<_GeometriasPedidas> _pedirEnTandas(List<String> ids) async {
    final geometrias = <GeometriaZona>[];
    final sinGeometria = <String>[];
    final atribuciones = <String>{};
    for (var i = 0; i < ids.length; i += _porPeticion) {
      final fin = i + _porPeticion > ids.length ? ids.length : i + _porPeticion;
      final res = await _datos.obtenerGeometrias(ids.sublist(i, fin));
      geometrias.addAll(res.geometrias.where((g) => g.tienePuntos));
      sinGeometria.addAll(res.sinGeometria);
      atribuciones.addAll(res.atribuciones);
    }
    return _GeometriasPedidas(
      geometrias,
      sinGeometria,
      atribuciones.toList(growable: false),
    );
  }

  Future<void> seleccionar(String localidadId) async {
    emit(state.copyWith(estado: MapaEstado.cargando, localidadId: localidadId));
    try {
      final barrios = _zonas
          .where((z) => z['parentId'] == localidadId && z['level'] == 'BARRIO')
          .map((z) => '${z['id']}')
          .toList();
      final pedidas = <String>[localidadId, ...barrios];
      // Una localidad grande llega a más de cien barrios: se pide en tandas del
      // tope del contrato. Con una sola petición el cliente recortaba la lista
      // a 20 y el resto de barrios no se dibujaba nunca, sin avisar.
      final res = await _pedirEnTandas(pedidas);
      final dibujables = res.geometrias;

      // Sedes de la localidad elegida y de sus barrios.
      final deLaZona = _misSitios
          .where((s) => pedidas.contains(s.zonaId))
          .toList(growable: false);
      final ubicadas = deLaZona
          .where((s) => s.tieneCoordenadas)
          .toList(growable: false);

      emit(
        state.copyWith(
          // El mapa tiene contenido si hay un límite que dibujar o una sede
          // que ubicar. Sin ninguna de las dos cosas queda vacío, y eso se
          // dice: no se rellena con una forma aproximada (C2).
          estado: dibujables.isEmpty && ubicadas.isEmpty
              ? MapaEstado.vacio
              : MapaEstado.listo,
          geometrias: dibujables,
          sinGeometria: res.sinGeometria,
          atribuciones: res.atribuciones,
          sitios: ubicadas,
          sitiosSinUbicacion: deLaZona.length - ubicadas.length,
        ),
      );
    } on GatewayException catch (e) {
      emit(state.copyWith(estado: MapaEstado.error, mensajeError: e.message));
    }
  }

  /// Pide las sedes sin dejar que su fallo tumbe el mapa. Un admin no las
  /// puede leer —son del cliente de la sesión— y eso es lo esperado, no un
  /// error que haya que mostrar.
  Future<List<SitioUbicado>> _cargarSitiosTolerante() async {
    try {
      return await _datos.listarMisSitios();
    } on GatewayException {
      return const [];
    }
  }

  /// Igual que las sedes: la cobertura es del aliado, y que otro rol no la
  /// pueda leer es lo esperado, no un error que mostrar.
  Future<Set<String>> _cargarCoberturaTolerante() async {
    try {
      return (await _datos.listarMiCobertura()).toSet();
    } on GatewayException {
      return const {};
    }
  }

  List<Map<String, dynamic>> _zonas = const [];
  List<SitioUbicado> _misSitios = const [];
}

/// Lo recibido tras pedir los límites de varias zonas en tandas.
class _GeometriasPedidas {
  const _GeometriasPedidas(
    this.geometrias,
    this.sinGeometria,
    this.atribuciones,
  );

  final List<GeometriaZona> geometrias;
  final List<String> sinGeometria;
  final List<String> atribuciones;
}
