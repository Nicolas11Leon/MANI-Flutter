import 'package:flutter/material.dart';

/// Avisa cuando la pantalla deja de verse o vuelve a verse (SCRUM-1647).
///
/// Las pestañas conservan su estado al cambiar de una a otra, así que una pantalla puede seguir viva sin estar a la
/// vista. Si consulta al servidor cada tantos segundos, debe parar mientras nadie la mira: gasta datos y batería del
/// celular para nada. Se considera que no se ve cuando su pestaña no es la abierta, cuando otra pantalla la tapa o
/// cuando la app pasa a segundo plano.
class AlCambiarVisibilidad extends StatefulWidget {
  const AlCambiarVisibilidad({
    super.key,
    required this.alCambiar,
    required this.child,
  });

  /// Recibe `false` al dejar de verse y `true` al volver. No se llama al montar si la pantalla arranca visible.
  final ValueChanged<bool> alCambiar;
  final Widget child;

  @override
  State<AlCambiarVisibilidad> createState() => _AlCambiarVisibilidadState();
}

class _AlCambiarVisibilidadState extends State<AlCambiarVisibilidad>
    with WidgetsBindingObserver {
  bool _aLaVista = true;
  bool _enPrimerPlano = true;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El armazón apaga los relojes de animación de las pestañas ocultas, y el navegador los de las pantallas tapadas
    // por otra: esa misma señal dice si esta pantalla se ve.
    _aLaVista = TickerMode.valuesOf(context).enabled;
    _revisar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // «inactive» es perder el foco (otra ventana encima en web) con la app aún a la vista: no cuenta como oculta.
    if (estado == AppLifecycleState.inactive) return;
    _enPrimerPlano = estado == AppLifecycleState.resumed;
    _revisar();
  }

  void _revisar() {
    final visible = _aLaVista && _enPrimerPlano;
    if (visible == _visible) return;
    _visible = visible;
    widget.alCambiar(visible);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
