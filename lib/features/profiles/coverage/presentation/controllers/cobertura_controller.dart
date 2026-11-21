import 'package:flutter/foundation.dart';

import '../../domain/entities/seleccion_cobertura.dart';
import '../../domain/entities/zona.dart';
import '../../domain/failures/cobertura_failure.dart';
import '../../domain/repositories/cobertura_repository.dart';
import '../../domain/usecases/cobertura_usecases.dart';

enum EstadoCarga { inicial, cargando, listo, error }

/// Estado y acciones de la pantalla "Zona de cobertura" (US-02.1.4).
/// ChangeNotifier puro para no imponer paquete de estado; se adapta a
/// Riverpod/Bloc envolviéndolo si el equipo ya usa uno.
class CoberturaController extends ChangeNotifier {
  CoberturaController(CoberturaRepository repo)
    : _declarar = DeclararCobertura(repo),
      _obtener = ObtenerMiCobertura(repo),
      _catalogo = ConsultarCatalogoZonas(repo);

  final DeclararCobertura _declarar;
  final ObtenerMiCobertura _obtener;
  final ConsultarCatalogoZonas _catalogo;

  EstadoCarga carga = EstadoCarga.inicial;
  List<Zona> ciudades = const [];
  Zona? ciudad;
  final Map<String, List<Zona>> _hijas = {};
  final Set<String> _cargandoHijas = {};
  final Map<String, String> _nombres = {};

  String consulta = '';
  bool buscando = false;
  List<Zona> resultados = const [];
  int _tokenBusqueda = 0;

  SeleccionCobertura seleccion = SeleccionCobertura.vacia();
  SeleccionCobertura _inicial = SeleccionCobertura.vacia();
  bool guardando = false;
  CoberturaFailure? error;
  String? _aviso;
  bool _cerrado = false;

  // ---------------------------------------------------------------- lectura
  List<Zona>? hijasDe(String padreId) => _hijas[padreId];
  bool cargandoHijasDe(String padreId) => _cargandoHijas.contains(padreId);
  String nombreDe(String id) => _nombres[id] ?? '…';

  /// "Chapinero · Bogotá" — ruta legible a partir de los ancestros.
  String rutaDe(Zona z) => z.ancestros.map(nombreDe).join(' · ');

  bool get hayCambios => !seleccion.mismoContenidoQue(_inicial);
  bool get esPrimeraDeclaracion => _inicial.estaVacia;
  bool get puedeGuardar =>
      hayCambios &&
      !seleccion.estaVacia &&
      seleccion.desactivadas.isEmpty &&
      !guardando;

  /// Mensaje de un solo uso para SnackBar.
  String? tomarAviso() {
    final a = _aviso;
    _aviso = null;
    return a;
  }

  // ---------------------------------------------------------------- acciones
  Future<void> iniciar() async {
    carga = EstadoCarga.cargando;
    error = null;
    _notificar();
    try {
      final r = await Future.wait([_catalogo.ciudades(), _obtener()]);
      ciudades = r[0] as List<Zona>;
      _inicial = r[1] as SeleccionCobertura;
      seleccion = _inicial;
      _indexar(ciudades);
      _indexar(seleccion.zonas);
      ciudad = _ciudadInicial();
      carga = EstadoCarga.listo;
      _notificar();
      if (ciudad != null) await cargarHijas(ciudad!.id);
    } on CoberturaFailure catch (f) {
      error = f;
      carga = EstadoCarga.error;
      _notificar();
    }
  }

  Future<void> seleccionarCiudad(Zona c) async {
    if (ciudad?.id == c.id) return;
    ciudad = c;
    limpiarBusqueda();
    _notificar();
    await cargarHijas(c.id);
  }

  Future<void> cargarHijas(String padreId) async {
    if (_hijas.containsKey(padreId) || _cargandoHijas.contains(padreId)) return;
    _cargandoHijas.add(padreId);
    _notificar();
    try {
      final hijas = await _catalogo.hijas(padreId);
      _hijas[padreId] = hijas;
      _indexar(hijas);
    } on CoberturaFailure catch (f) {
      _aviso = f.mensajeUsuario;
    } finally {
      _cargandoHijas.remove(padreId);
      _notificar();
    }
  }

  Future<void> buscar(String texto) async {
    consulta = texto;
    final token = ++_tokenBusqueda;
    final c = ciudad;
    if (c == null || texto.trim().length < 2) {
      resultados = const [];
      buscando = false;
      _notificar();
      return;
    }
    buscando = true;
    _notificar();
    try {
      final r = await _catalogo.buscar(c.id, texto);
      if (token != _tokenBusqueda) return; // respuesta vieja: se descarta
      resultados = r;
      _indexar(r);
    } on CoberturaFailure catch (f) {
      if (token == _tokenBusqueda) _aviso = f.mensajeUsuario;
    } finally {
      if (token == _tokenBusqueda) {
        buscando = false;
        _notificar();
      }
    }
  }

  void limpiarBusqueda() {
    _tokenBusqueda++;
    consulta = '';
    resultados = const [];
    buscando = false;
    _notificar();
  }

  /// Zona del catálogo ya cargada, por id. La necesita el mapa, que solo
  /// conoce identificadores: [alternar] trabaja con la zona entera porque
  /// tiene que mirar sus ancestros. Devuelve null si todavía no está cargada,
  /// y entonces no se altera nada en vez de inventar una zona suelta.
  Zona? zonaDelCatalogo(String id) {
    for (final z in ciudades) {
      if (z.id == id) return z;
    }
    for (final hijas in _hijas.values) {
      for (final z in hijas) {
        if (z.id == id) return z;
      }
    }
    for (final z in resultados) {
      if (z.id == id) return z;
    }
    return seleccion.zonas.where((z) => z.id == id).firstOrNull;
  }

  void alternar(Zona z) {
    if (seleccion.estaCubiertaPorAncestro(z)) return;
    final absorbidas = seleccion.estaSeleccionadaDirectamente(z)
        ? 0
        : seleccion.cantidadAbsorbidaPor(z);
    seleccion = seleccion.alternar(z);
    if (absorbidas > 0) {
      _aviso =
          '${z.nombre} completa reemplaza $absorbidas '
          '${absorbidas == 1 ? 'zona' : 'zonas'} que ya tenías dentro.';
    }
    _notificar();
  }

  void quitarDesactivadas() {
    seleccion = seleccion.sinDesactivadas();
    _notificar();
  }

  void descartarCambios() {
    seleccion = _inicial;
    error = null;
    _notificar();
  }

  /// Devuelve `true` si guardó. Ante error conserva la selección del usuario.
  Future<bool> guardar() async {
    if (!puedeGuardar) return false;
    guardando = true;
    error = null;
    _notificar();
    try {
      final confirmados = await _declarar(seleccion);
      seleccion = seleccion.soloIds(confirmados);
      _inicial = seleccion;
      _aviso =
          'Cobertura guardada: ${seleccion.cantidad} '
          '${seleccion.cantidad == 1 ? 'zona' : 'zonas'}. '
          'Solo recibirás solicitudes de estas zonas.';
      return true;
    } on CoberturaFailure catch (f) {
      error = f;
      _aviso = f.mensajeUsuario;
      return false;
    } finally {
      guardando = false;
      _notificar();
    }
  }

  // ---------------------------------------------------------------- interno
  Zona? _ciudadInicial() {
    if (ciudades.isEmpty) return null;
    for (final z in seleccion.zonas) {
      final raizId = z.nivel == NivelZona.ciudad
          ? z.id
          : (z.ancestros.isEmpty ? null : z.ancestros.last);
      for (final c in ciudades) {
        if (c.id == raizId) return c;
      }
    }
    return ciudades.first;
  }

  void _indexar(Iterable<Zona> zonas) {
    for (final z in zonas) {
      _nombres[z.id] = z.nombre;
    }
  }

  void _notificar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
