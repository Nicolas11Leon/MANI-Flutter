import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_estado.dart';

/// Carga una librería diferida (`import ... deferred as x`) antes de pintar su pantalla (SCRUM-1647).
///
/// En web, Flutter parte el programa en trozos: lo que solo usa una pantalla pesada (el mapa de zonas, la auditoría de
/// transacciones) no se descarga al abrir la app, sino la primera vez que alguien entra a esa pantalla. Mientras llega
/// se ve el indicador de carga (anunciado a lectores de pantalla) y, si la descarga falla (sin red, por ejemplo),
/// un mensaje con «Reintentar» en lugar de una pantalla en blanco.
///
/// Uso: `CargaDiferida(cargar: mapa.loadLibrary, builder: (_) => mapa.MapaZonasPage())`.
class CargaDiferida extends StatefulWidget {
  const CargaDiferida({
    super.key,
    required this.cargar,
    required this.builder,
    this.mensajeCarga = 'Cargando la pantalla',
    this.pantalla = true,
  });

  /// `loadLibrary` de la librería diferida. Es idempotente: tras la primera vez devuelve al instante.
  final Future<void> Function() cargar;

  /// Construye la pantalla; solo se llama cuando la librería ya está cargada.
  final WidgetBuilder builder;

  final String mensajeCarga;

  /// `true`: ocupa toda la pantalla (con su `Scaffold`), para una ruta. `false`: va embebida dentro de otra pantalla,
  /// como el mapa dentro de Cobertura o de Sedes, y solo pinta el indicador o el error en su sitio.
  final bool pantalla;

  @override
  State<CargaDiferida> createState() => _CargaDiferidaState();
}

class _CargaDiferidaState extends State<CargaDiferida> {
  late Future<void> _carga = widget.cargar();

  void _reintentar() {
    final nueva = widget.cargar();
    setState(() {
      _carga = nueva;
    });
  }

  /// En una ruta ocupa toda la pantalla; embebida (el mapa dentro de otra pantalla) solo ocupa su sitio.
  Widget _contenedor(BuildContext context, Widget hijo) {
    if (!widget.pantalla) return hijo;
    return Scaffold(backgroundColor: context.mani.background, body: hijo);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _carga,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _contenedor(
            context,
            ManiCargando(mensaje: widget.mensajeCarga),
          );
        }
        if (snapshot.hasError) {
          return _contenedor(
            context,
            Center(
              child: Padding(
                padding: const EdgeInsets.all(ManiSpace.xxl),
                child: ManiEstadoError(
                  mensaje:
                      'No se pudo cargar. Revisa tu conexión e inténtalo de nuevo.',
                  onReintentar: _reintentar,
                  botonKey: const Key('carga-diferida-reintentar'),
                ),
              ),
            ),
          );
        }
        return widget.builder(context);
      },
    );
  }
}
