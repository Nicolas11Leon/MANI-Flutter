import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/seguimiento_datasource.dart';
import '../domain/solicitud_seguimiento.dart';

class MisSolicitudesState extends Equatable {
  const MisSolicitudesState({
    this.cargando = false,
    this.solicitudes = const [],
    this.error,
    this.consultadoEn,
    this.cancelandoId,
  });

  final bool cargando;
  final List<SolicitudSeguimiento> solicitudes;

  /// Mensaje para el usuario si la última consulta falló.
  final String? error;

  /// Cuándo se consultó por última vez con éxito.
  final DateTime? consultadoEn;

  /// Solicitud cuya cancelación está en curso (SCRUM-877); bloquea el botón.
  final String? cancelandoId;

  @override
  List<Object?> get props => [
    cargando,
    solicitudes,
    error,
    consultadoEn,
    cancelandoId,
  ];
}

/// Estado de las solicitudes del cliente (HU-M07-04 / SCRUM-871). La pantalla
/// lo vuelve a consultar sola mientras está a la vista (SCRUM-1710) y el
/// cliente también puede pedirlo con «Actualizar».
class MisSolicitudesCubit extends Cubit<MisSolicitudesState> {
  MisSolicitudesCubit(this._fuente, {DateTime Function()? reloj})
    : _reloj = reloj ?? DateTime.now,
      super(const MisSolicitudesState());

  final FuenteSeguimiento _fuente;
  final DateTime Function() _reloj;

  /// El aviso visible explica por qué no se pudo cancelar: un sondeo no lo
  /// borra, porque la persona aún no lo ha leído o atendido.
  bool _avisoDeCancelacion = false;

  /// Sube con cada acción o carga normal. Un sondeo cuya respuesta llega
  /// después la descarta: lo que leyó ya puede ser viejo (SCRUM-1710).
  int _generacion = 0;

  /// Con [silencioso] (sondeo, SCRUM-1710) no muestra cargando, no consulta
  /// durante una cancelación y, si falla, conserva lo que ya se ve sin avisar.
  Future<void> cargar({bool silencioso = false}) async {
    if (silencioso) return _cargarSilencioso();
    _avisoDeCancelacion = false;
    _generacion++;
    emit(
      MisSolicitudesState(
        cargando: true,
        solicitudes: state.solicitudes,
        consultadoEn: state.consultadoEn,
      ),
    );
    try {
      final lista = await _fuente.listar();
      if (isClosed) return;
      emit(MisSolicitudesState(solicitudes: lista, consultadoEn: _reloj()));
    } on SeguimientoFailure catch (f) {
      _fallo(f.mensajeUsuario);
    } catch (_) {
      _fallo(
        const SeguimientoFailure(
          SeguimientoErrorTipo.desconocido,
        ).mensajeUsuario,
      );
    }
  }

  Future<void> _cargarSilencioso() async {
    if (state.cargando || state.cancelandoId != null) return;
    final generacion = _generacion;
    try {
      final lista = await _fuente.listar();
      if (isClosed || generacion != _generacion) return;
      emit(
        MisSolicitudesState(
          solicitudes: lista,
          consultadoEn: _reloj(),
          error: _avisoDeCancelacion ? state.error : null,
        ),
      );
    } catch (_) {
      // El siguiente sondeo lo reintenta; lo visible no cambia.
    }
  }

  /// Cancela la solicitud antes de la ejecución (US-04.5.1 / SCRUM-877) y
  /// reemplaza la tarjeta por el estado que devuelve Core. Devuelve `true` si
  /// quedó cancelada. Si Core la rechaza porque ya empezó la ejecución, se
  /// vuelve a consultar para mostrar el estado real.
  Future<bool> cancelar(String solicitudId, {String? motivo}) async {
    if (state.cancelandoId != null) return false;
    _generacion++;
    emit(
      MisSolicitudesState(
        solicitudes: state.solicitudes,
        consultadoEn: state.consultadoEn,
        cancelandoId: solicitudId,
      ),
    );
    try {
      final cancelada = await _fuente.cancelar(solicitudId, motivo: motivo);
      if (isClosed) return true;
      emit(
        MisSolicitudesState(
          solicitudes: [
            for (final s in state.solicitudes)
              s.id == cancelada.id ? cancelada : s,
          ],
          consultadoEn: state.consultadoEn,
        ),
      );
      return true;
    } on SeguimientoFailure catch (f) {
      _avisoDeCancelacion = true;
      _fallo(f.mensajeUsuario);
      if (f.tipo == SeguimientoErrorTipo.noCancelable ||
          f.tipo == SeguimientoErrorTipo.noEncontrada) {
        await _refrescarConservandoError(f.mensajeUsuario);
      }
      return false;
    } catch (_) {
      _avisoDeCancelacion = true;
      _fallo(
        const SeguimientoFailure(
          SeguimientoErrorTipo.desconocido,
        ).mensajeUsuario,
      );
      return false;
    }
  }

  /// Vuelve a consultar sin borrar el aviso de por qué no se canceló.
  Future<void> _refrescarConservandoError(String mensaje) async {
    try {
      final lista = await _fuente.listar();
      if (isClosed) return;
      emit(
        MisSolicitudesState(
          solicitudes: lista,
          consultadoEn: _reloj(),
          error: mensaje,
        ),
      );
    } catch (_) {
      // Ya se muestra el error de la cancelación; la lista se conserva.
    }
  }

  /// Se conserva lo que ya se veía, pero se avisa que no está al día.
  void _fallo(String mensaje) {
    if (isClosed) return;
    emit(
      MisSolicitudesState(
        solicitudes: state.solicitudes,
        consultadoEn: state.consultadoEn,
        error: mensaje,
      ),
    );
  }
}
