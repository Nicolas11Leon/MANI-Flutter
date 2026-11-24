import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mani/features/catalog/map/presentation/widgets/mapa_zonas_diferido.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';

/// Mapa del catálogo geográfico como pantalla propia (HU-M04-07 / SCRUM-1396).
///
/// Queda para quien administra el catálogo, que sí mira las zonas por sí
/// mismas. Al aliado y al cliente el mapa les llega dentro de la pantalla
/// donde el dato significa algo —su cobertura y sus sedes—, no como una
/// pantalla aparte que obliga a recordar lo que se vio en la otra.
class MapaZonasPage extends StatelessWidget {
  const MapaZonasPage({super.key});

  /// Conservado por compatibilidad con quien ya lo referenciaba; el mismo valor que `MapaZonas.centroBogota`, que
  /// no se puede referenciar aquí porque esa librería es diferida.
  static const centroBogota = LatLng(4.6533, -74.0836);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barraDePantalla(context, titulo: 'Mapa de zonas'),
      body: const MapaZonasDiferido(),
    );
  }
}
