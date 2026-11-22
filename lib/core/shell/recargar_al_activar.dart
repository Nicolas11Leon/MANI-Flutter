import 'package:flutter/material.dart';

/// Avisa qué pestaña principal se acaba de abrir (SCRUM-1647). Lo publica el armazón y lo escuchan las pantallas que
/// envuelven [RecargarAlActivar].
class ActivacionDePestanas extends ChangeNotifier {
  String? _ruta;

  /// La última pestaña abierta, o `null` si aún ninguna.
  String? get ruta => _ruta;

  /// El usuario llegó a la pestaña [ruta].
  void activar(String ruta) {
    if (_ruta == ruta) return;
    _ruta = ruta;
    notifyListeners();
  }

  int _marca = 0;
  String? _exenta;

  /// Cuántas veces se han dado por viejos los datos de las pestañas.
  int get marca => _marca;

  /// La pestaña que la última invalidación dejó por fuera, si hubo alguna.
  String? get exenta => _exenta;

  /// Algo cambió (se publicó una solicitud, se aceptó una cotización…): las pestañas dejan de confiar en lo que tienen
  /// en pantalla. La que está abierta se recarga ya; las demás, cuando el usuario llegue a ellas, sin esperar a que
  /// caduquen. [excepto] deja por fuera a la pestaña que ya se puso al día por su cuenta.
  void invalidar({String? excepto}) {
    _marca++;
    _exenta = excepto;
    notifyListeners();
  }
}

/// Aviso compartido de pestañas abiertas.
final activacionDePestanas = ActivacionDePestanas();

/// Mantiene viva la pantalla de una pestaña, pero la reconstruye si el usuario vuelve después de [caducaEn].
///
/// Con pestañas que conservan su estado, cambiar de una a otra y volver es instantáneo y no repite las consultas: así el
/// «atrás» y el cambio de pestaña se sienten fluidos. El costo es que una lista podría quedar vieja (por ejemplo, un
/// pedido nuevo que no aparece). Por eso, si se estuvo fuera más de [caducaEn], al volver se reconstruye y trae datos
/// nuevos; si se vuelve antes, se queda tal cual estaba.
class RecargarAlActivar extends StatefulWidget {
  const RecargarAlActivar({
    super.key,
    required this.ruta,
    required this.child,
    this.caducaEn = const Duration(seconds: 30),
    this.avisos,
    this.reloj = DateTime.now,
  });

  /// Ruta de la pestaña a la que pertenece la pantalla.
  final String ruta;
  final Widget child;
  final Duration caducaEn;

  /// De dónde llega el aviso de pestaña abierta; por omisión, el compartido de la app.
  final ActivacionDePestanas? avisos;

  /// Reloj, para probar sin esperar.
  final DateTime Function() reloj;

  @override
  State<RecargarAlActivar> createState() => _RecargarAlActivarState();
}

class _RecargarAlActivarState extends State<RecargarAlActivar> {
  int _version = 0;
  DateTime? _salioEn;
  late ActivacionDePestanas _avisos;
  late int _marcaVista;
  bool _pendiente = false;

  @override
  void initState() {
    super.initState();
    _avisos = widget.avisos ?? activacionDePestanas;
    _marcaVista = _avisos.marca;
    _avisos.addListener(_alActivarPestana);
  }

  @override
  void dispose() {
    _avisos.removeListener(_alActivarPestana);
    super.dispose();
  }

  void _alActivarPestana() {
    final activa = _avisos.ruta;
    if (_avisos.marca != _marcaVista) {
      _marcaVista = _avisos.marca;
      if (_avisos.exenta != widget.ruta) _pendiente = true;
    }
    if (activa == widget.ruta) {
      final salio = _salioEn;
      _salioEn = null;
      final caduco =
          salio != null && widget.reloj().difference(salio) > widget.caducaEn;
      if (_pendiente || caduco) {
        _pendiente = false;
        setState(() => _version++);
      }
    } else {
      // Otra pestaña pasó al frente: desde ahora esta está fuera.
      _salioEn ??= widget.reloj();
    }
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: ValueKey(_version), child: widget.child);
}
