import 'package:flutter/material.dart';
import 'package:mani/features/catalog/map/presentation/widgets/mapa_zonas.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';

/// Mapa del catálogo geográfico como pantalla propia (HU-M04-07 / SCRUM-1396).
///
/// Queda para quien administra el catálogo, que sí mira las zonas por sí
/// mismas. Al aliado y al cliente el mapa les llega dentro de la pantalla
/// donde el dato significa algo —su cobertura y sus sedes—, no como una
/// pantalla aparte que obliga a recordar lo que se vio en la otra.
class MapaZonasPage extends StatelessWidget {
  const MapaZonasPage({super.key});

  /// Conservado por compatibilidad con quien ya lo referenciaba; el valor vive
  /// en [MapaZonas].
  static const centroBogota = MapaZonas.centroBogota;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barraDePantalla(context, titulo: 'Mapa de zonas'),
      body: const MapaZonas(),
    );
  }
}
