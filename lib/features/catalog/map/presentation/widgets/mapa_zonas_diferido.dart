import 'package:flutter/material.dart';
import 'package:mani/core/routing/carga_diferida.dart';
import 'package:mani/features/catalog/map/presentation/widgets/mapa_zonas.dart'
    deferred as mapa;

/// El mapa de zonas, descargado la primera vez que se muestra (SCRUM-1647).
///
/// `mapa_zonas.dart` trae `flutter_map` y todo lo que dibuja el mapa, que es lo más pesado de la app web y solo
/// importa a quien abre Cobertura, Sedes o el mapa del catálogo. Los tres usan este envoltorio, con los mismos
/// parámetros que [MapaZonas], para que ninguno lo importe de forma normal: un solo `import` normal en cualquier
/// archivo lo devolvería al programa principal (lo vigila test/core/routing/carga_diferida_test.dart).
class MapaZonasDiferido extends StatelessWidget {
  const MapaZonasDiferido({
    super.key,
    this.coberturaResaltada,
    this.leyendaCobertura,
    this.alto,
    this.onZonaTocada,
  });

  final Set<String>? coberturaResaltada;
  final String? leyendaCobertura;
  final double? alto;
  final void Function(String zonaId)? onZonaTocada;

  @override
  Widget build(BuildContext context) {
    return CargaDiferida(
      cargar: mapa.loadLibrary,
      pantalla: false,
      mensajeCarga: 'Cargando el mapa',
      builder: (_) => mapa.MapaZonas(
        coberturaResaltada: coberturaResaltada,
        leyendaCobertura: leyendaCobertura,
        alto: alto,
        onZonaTocada: onZonaTocada,
      ),
    );
  }
}
