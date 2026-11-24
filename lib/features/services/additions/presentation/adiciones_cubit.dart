import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/features/services/quotes/domain/cotizacion.dart';

import '../data/adiciones_datasource.dart';

class AdicionesState extends Equatable {
  const AdicionesState({
    this.cargando = false,
    this.enviando = false,
    this.datos,
    this.error,
    this.aviso,
    this.avisoEsError = false,
  });

  final bool cargando;
  final bool enviando;
  final AdicionesServicio? datos;
  final String? error;
  final String? aviso;
  final bool avisoEsError;

  @override
  List<Object?> get props => [
    cargando,
    enviando,
    datos,
    error,
    aviso,
    avisoEsError,
  ];
}

/// Adiciones por imprevisto del servicio (US-04.3.5 / SCRUM-872). Tras cada
/// acción se vuelve a consultar a Core, que calcula el total vigente y es el
/// dueño del estado.
class AdicionesCubit extends Cubit<AdicionesState> {
  AdicionesCubit(this._fuente, this.solicitudId)
    : super(const AdicionesState());

  final FuenteAdiciones _fuente;
  final String solicitudId;

  /// Sube con cada acción o carga normal. Un sondeo cuya respuesta llega
  /// después la descarta: lo que leyó ya puede ser viejo (SCRUM-1644).
  int _generacion = 0;

  /// Con [silencioso] (sondeo, SCRUM-1644) no muestra cargando, no pisa una
  /// acción en curso y, si falla, conserva lo que ya se ve sin avisar.
  Future<void> cargar({bool silencioso = false}) async {
    if (silencioso && (state.enviando || state.cargando)) return;
    final generacion = silencioso ? _generacion : ++_generacion;
    if (!silencioso) emit(AdicionesState(cargando: true, datos: state.datos));
    try {
      final datos = await _fuente.listar(solicitudId);
      if (isClosed || (silencioso && generacion != _generacion)) return;
      emit(AdicionesState(datos: datos));
    } on CotizacionFailure catch (f) {
      if (isClosed || silencioso) return;
      emit(AdicionesState(datos: state.datos, error: f.mensajeUsuario));
    }
  }

  /// El aliado asignado pide la adición. Devuelve true si Core la registró,
  /// para que el formulario se cierre solo en ese caso.
  Future<bool> solicitar({
    required String motivo,
    required String valorManoObra,
    required String valorMateriales,
    int? tiempoAdicionalMinutos,
  }) => _accion(
    () => _fuente.solicitar(
      solicitudId,
      motivo: motivo,
      valorManoObra: valorManoObra,
      valorMateriales: valorMateriales,
      tiempoAdicionalMinutos: tiempoAdicionalMinutos,
    ),
    'Enviaste la adición. El cliente debe aceptarla o rechazarla.',
  );

  /// El cliente dueño decide sobre la adición pendiente.
  Future<bool> responder(
    String adicionId,
    DecisionAdicion decision, {
    String? comentario,
  }) => _accion(
    () => _fuente.responder(adicionId, decision, comentario: comentario),
    decision == DecisionAdicion.aceptar
        ? 'Aceptaste la adición. El total del servicio se actualizó.'
        : 'Rechazaste la adición. El servicio sigue con lo pactado.',
  );

  Future<bool> _accion(Future<void> Function() accion, String exito) async {
    if (state.enviando) return false;
    _generacion++;
    emit(AdicionesState(enviando: true, datos: state.datos));
    try {
      await accion();
    } on CotizacionFailure catch (f) {
      if (isClosed) return false;
      emit(
        AdicionesState(
          datos: state.datos,
          aviso: f.mensajeUsuario,
          avisoEsError: true,
        ),
      );
      return false;
    }
    if (isClosed) return true;
    try {
      final datos = await _fuente.listar(solicitudId);
      if (isClosed) return true;
      emit(AdicionesState(datos: datos, aviso: exito));
    } on CotizacionFailure {
      // La acción ya quedó en Core: no se reporta como fallo.
      if (isClosed) return true;
      emit(
        AdicionesState(
          datos: state.datos,
          aviso:
              '$exito No se pudo actualizar la vista; desliza para refrescar.',
        ),
      );
    }
    return true;
  }
}
