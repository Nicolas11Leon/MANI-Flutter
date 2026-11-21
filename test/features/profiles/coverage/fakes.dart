import 'dart:async';
import 'package:mani/features/profiles/coverage/domain/entities/zona.dart';
import 'package:mani/features/profiles/coverage/domain/failures/cobertura_failure.dart';
import 'package:mani/features/profiles/coverage/domain/repositories/cobertura_repository.dart';

// Catálogo de prueba: Bogotá > {Chapinero > {Chicó, Rosales}, Suba > {Niza}}
const bogota = Zona(
  id: 'bog',
  nombre: 'Bogotá',
  nivel: NivelZona.ciudad,
  tieneHijas: true,
);
const chapinero = Zona(
  id: 'cha',
  nombre: 'Chapinero',
  nivel: NivelZona.localidad,
  padreId: 'bog',
  ancestros: ['bog'],
  tieneHijas: true,
);
const suba = Zona(
  id: 'sub',
  nombre: 'Suba',
  nivel: NivelZona.localidad,
  padreId: 'bog',
  ancestros: ['bog'],
  tieneHijas: true,
);
const chico = Zona(
  id: 'chi',
  nombre: 'Chicó',
  nivel: NivelZona.barrio,
  padreId: 'cha',
  ancestros: ['cha', 'bog'],
);
const rosales = Zona(
  id: 'ros',
  nombre: 'Rosales',
  nivel: NivelZona.barrio,
  padreId: 'cha',
  ancestros: ['cha', 'bog'],
);
const niza = Zona(
  id: 'niz',
  nombre: 'Niza',
  nivel: NivelZona.barrio,
  padreId: 'sub',
  ancestros: ['sub', 'bog'],
);
const nizaDesactivada = Zona(
  id: 'niz',
  nombre: 'Niza',
  nivel: NivelZona.barrio,
  padreId: 'sub',
  ancestros: ['sub', 'bog'],
  activa: false,
);

class FakeCoberturaRepository implements CoberturaRepository {
  FakeCoberturaRepository({List<Zona> coberturaInicial = const []})
    : guardada = coberturaInicial.map((z) => z.id).toSet() {
    _coberturaZonas = List.of(coberturaInicial);
  }

  final Map<String?, List<Zona>> catalogo = {
    null: [bogota],
    'bog': [chapinero, suba],
    'cha': [chico, rosales],
    'sub': [niza],
  };

  late List<Zona> _coberturaZonas;
  Set<String> guardada;
  int llamadasDeclarar = 0;
  Set<String>? ultimoEnvio;
  CoberturaFailure? fallarAlDeclarar;
  CoberturaFailure? fallarAlCargar;

  /// Retrasa la carga de hijas para poder ver el estado intermedio, en el que
  /// la localidad aún no está y la pantalla muestra el indicador.
  Completer<void>? esperaHijas;

  @override
  Future<List<Zona>> listarZonas({String? padreId}) async {
    if (fallarAlCargar != null) throw fallarAlCargar!;
    if (padreId != null && esperaHijas != null) await esperaHijas!.future;
    return catalogo[padreId] ?? const [];
  }

  @override
  Future<List<Zona>> buscarZonas({
    required String ciudadId,
    required String texto,
  }) async {
    final t = texto.toLowerCase();
    return [
      chapinero,
      suba,
      chico,
      rosales,
      niza,
    ].where((z) => z.nombre.toLowerCase().contains(t)).toList();
  }

  @override
  Future<List<Zona>> obtenerMiCobertura() async {
    if (fallarAlCargar != null) throw fallarAlCargar!;
    return _coberturaZonas;
  }

  @override
  Future<Set<String>> declararCobertura(Set<String> zonaIds) async {
    llamadasDeclarar++;
    ultimoEnvio = zonaIds;
    if (fallarAlDeclarar != null) throw fallarAlDeclarar!;
    guardada = zonaIds;
    return zonaIds;
  }
}
