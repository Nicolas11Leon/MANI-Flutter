import 'dart:async';

import 'package:flutter/widgets.dart';

/// Vuelve a consultar el estado de una pantalla cada [intervalo] mientras la
/// persona la está viendo (SCRUM-1636, SCRUM-1644).
///
/// No usa Supabase Realtime (ADR-0027): es sondeo HTTP por el Gateway, el mismo
/// patrón de `solicitudes_aliado_page` y `chat_cubit`.
///
/// - Pausa cuando la app o la pestaña quedan ocultas (`hidden`, `paused`,
///   `detached`) y cuando otra ruta tapa esta pantalla.
/// - No pausa en `inactive`: en web la ventana pasa a `inactive` solo con
///   perder el foco, y debe seguir actualizándose aunque esté a la vista junto
///   a otra ventana.
/// - Al volver a la pestaña o a la app consulta enseguida y reinicia el
///   intervalo. Al volver de otra ruta (un diálogo, el chat) solo reanuda el
///   intervalo.
/// - Nunca lanza dos consultas a la vez: si la anterior no terminó, omite el
///   turno.
class RefrescoPeriodico extends StatefulWidget {
  const RefrescoPeriodico({
    super.key,
    required this.onRefrescar,
    required this.child,
    this.intervalo = intervaloPorDefecto,
  });

  /// Dentro del rango de 15 a 30 s que piden SCRUM-1644 y SCRUM-1710.
  static const intervaloPorDefecto = Duration(seconds: 20);

  /// Consulta silenciosa: no debe mostrar cargando ni avisos si falla.
  final Future<void> Function() onRefrescar;

  /// `null` desactiva el sondeo (pruebas).
  final Duration? intervalo;

  final Widget child;

  @override
  State<RefrescoPeriodico> createState() => _RefrescoPeriodicoState();
}

class _RefrescoPeriodicoState extends State<RefrescoPeriodico>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _enCurso = false;
  bool _appVisible = true;
  bool _rutaActual = true;

  bool get _visible => _appVisible && _rutaActual;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final estado = WidgetsBinding.instance.lifecycleState;
    _appVisible = estado == null || _esVisible(estado);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sin ruta (p. ej. en una prueba sin Navigator) se considera visible.
    final actual = ModalRoute.isCurrentOf(context) ?? true;
    if (actual == _rutaActual && _timer != null) return;
    _rutaActual = actual;
    // Al volver de otra ruta solo se reanuda el intervalo, sin consultar
    // enseguida: lo que estaba encima suele ser un diálogo que dispara una
    // acción (confirmar, cancelar), y el Cubit ya relee tras cada acción.
    _reprogramar();
  }

  @override
  void didUpdateWidget(RefrescoPeriodico anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.intervalo != widget.intervalo) _reprogramar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    final visible = _esVisible(estado);
    if (visible == _appVisible) return;
    _appVisible = visible;
    _reprogramar(consultarYa: visible);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  static bool _esVisible(AppLifecycleState estado) =>
      estado == AppLifecycleState.resumed ||
      estado == AppLifecycleState.inactive;

  void _reprogramar({bool consultarYa = false}) {
    _timer?.cancel();
    _timer = null;
    final intervalo = widget.intervalo;
    if (intervalo == null || !_visible) return;
    _timer = Timer.periodic(intervalo, (_) => _consultar());
    if (consultarYa) _consultar();
  }

  Future<void> _consultar() async {
    if (_enCurso || !_visible || !mounted) return;
    _enCurso = true;
    try {
      await widget.onRefrescar();
    } catch (_) {
      // Un sondeo fallido no interrumpe la pantalla: el siguiente lo reintenta.
    } finally {
      _enCurso = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
