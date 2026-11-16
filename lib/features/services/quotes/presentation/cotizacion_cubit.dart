import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/cotizaciones_datasource.dart';
import '../domain/cotizacion.dart';

class CotizacionState extends Equatable {
  const CotizacionState({
    this.cargando = false,
    this.enviando = false,
    this.cotizaciones = const [],
    this.error,
    this.aviso,
    this.avisoEsError = false,
  });

  final bool cargando;
  final bool enviando;

  /// Versiones de la más reciente a la más antigua, como las entrega Core.
  final List<Cotizacion> cotizaciones;

  /// La consulta falló y no hay nada que mostrar.
  final String? error;

  /// Resultado de la última acción (enviar o responder).
  final String? aviso;
  final bool avisoEsError;

  Cotizacion? get vigente => cotizaciones.isEmpty ? null : cotizaciones.first;

  CotizacionState copiar({
    bool? cargando,
    bool? enviando,
    List<Cotizacion>? cotizaciones,
    String? error,
    String? aviso,
    bool avisoEsError = false,
  }) => CotizacionState(
    cargando: cargando ?? this.cargando,
    enviando: enviando ?? this.enviando,
    cotizaciones: cotizaciones ?? this.cotizaciones,
    error: error,
    aviso: aviso,
    avisoEsError: avisoEsError,
  );

  @override
  List<Object?> get props => [
    cargando,
    enviando,
    cotizaciones,
    error,
    aviso,
    avisoEsError,
  ];
}

/// Cotización de una solicitud: el aliado la emite (SCRUM-865) y el cliente
/// la acepta, rechaza o pide ajustarla (SCRUM-867). Tras cada acción se
/// vuelve a consultar a Core, que es el dueño del estado (decisión 6A).
class CotizacionCubit extends Cubit<CotizacionState> {
  CotizacionCubit(this._fuente, this.solicitudId)
    : super(const CotizacionState());

  final FuenteCotizaciones _fuente;
  final String solicitudId;

  /// Sube con cada acción o carga normal. Un sondeo cuya respuesta llega
  /// después la descarta: lo que leyó ya puede ser viejo (SCRUM-1644).
  int _generacion = 0;

  /// Con [silencioso] (sondeo, SCRUM-1644) no muestra cargando, no pisa una
  /// acción en curso y, si falla, conserva lo que ya se ve sin avisar.
  Future<void> cargar({bool silencioso = false}) async {
    if (silencioso && (state.enviando || state.cargando)) return;
    final generacion = silencioso ? _generacion : ++_generacion;
    if (!silencioso) emit(state.copiar(cargando: true));
    try {
      final lista = await _fuente.listar(solicitudId);
      if (isClosed || (silencioso && generacion != _generacion)) return;
      emit(CotizacionState(cotizaciones: lista));
    } on CotizacionFailure catch (f) {
      if (isClosed || silencioso) return;
      // Si ya había datos se conservan y se avisa; si no, se muestra el error.
      emit(
        state.cotizaciones.isEmpty
            ? CotizacionState(error: f.mensajeUsuario)
            : state.copiar(
                cargando: false,
                aviso: f.mensajeUsuario,
                avisoEsError: true,
              ),
      );
    }
  }

  Future<void> emitir({
    required String valorManoObra,
    required String valorMateriales,
  }) => _accion(
    () => _fuente.emitir(
      solicitudId,
      valorManoObra: valorManoObra,
      valorMateriales: valorMateriales,
    ),
    (c) => 'Cotización v${c.version} enviada al cliente.',
  );

  Future<void> responder(DecisionCotizacion decision, {String? texto}) {
    final vigente = state.vigente;
    if (vigente == null) return Future.value();
    return _accion(
      () => _fuente.responder(vigente.id, decision, texto: texto),
      (_) => switch (decision) {
        DecisionCotizacion.aceptar => 'Aceptaste la cotización.',
        DecisionCotizacion.rechazar => 'Rechazaste la cotización.',
        DecisionCotizacion.ajustar =>
          'Pediste un ajuste. El aliado enviará una nueva versión.',
      },
    );
  }

  Future<void> _accion(
    Future<Cotizacion> Function() op,
    String Function(Cotizacion) exito,
  ) async {
    if (state.enviando) return;
    _generacion++;
    emit(state.copiar(enviando: true));
    final Cotizacion c;
    try {
      c = await op();
    } on CotizacionFailure catch (f) {
      if (isClosed) return;
      emit(
        state.copiar(
          enviando: false,
          aviso: f.mensajeUsuario,
          avisoEsError: true,
        ),
      );
      return;
    }
    if (isClosed) return;
    try {
      final lista = await _fuente.listar(solicitudId);
      if (isClosed) return;
      emit(CotizacionState(cotizaciones: lista, aviso: exito(c)));
    } on CotizacionFailure {
      // La acción ya quedó en Core: no se reporta como fallo. Se muestra lo que
      // devolvió Core para esa versión y se avisa que la lista puede estar vieja.
      if (isClosed) return;
      final resto = state.cotizaciones.where((x) => x.id != c.id);
      emit(
        CotizacionState(
          cotizaciones: [c, ...resto],
          aviso:
              '${exito(c)} No se pudo actualizar la lista; desliza para refrescar.',
        ),
      );
    }
  }
}
