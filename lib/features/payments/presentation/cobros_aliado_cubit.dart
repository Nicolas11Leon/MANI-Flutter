import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/cobros_datasource.dart';
import '../domain/cobros.dart';
import '../domain/pago.dart';

enum FaseCobros { cargando, listo, error }

class CobrosAliadoState extends Equatable {
  const CobrosAliadoState({
    this.fase = FaseCobros.cargando,
    this.cobros = const [],
    this.error,
  });

  final FaseCobros fase;
  final List<CobroAliado> cobros;
  final PagoFailure? error;

  @override
  List<Object?> get props => [fase, cobros, error];
}

/// Cobros del aliado (SCRUM-894). Solo lee: Core decide qué cobros ve cada
/// aliado, según el JWT.
class CobrosAliadoCubit extends Cubit<CobrosAliadoState> {
  CobrosAliadoCubit(this._fuente) : super(const CobrosAliadoState());

  final FuenteCobros _fuente;

  /// Con [silencioso] (sondeo, SCRUM-1710) no vuelve a «cargando» y, si
  /// falla, conserva los cobros que ya se ven sin mostrar el error.
  Future<void> cargar({bool silencioso = false}) async {
    if (silencioso && state.fase == FaseCobros.cargando) return;
    if (!silencioso) emit(const CobrosAliadoState());
    try {
      final cobros = await _fuente.cobrosDelAliado();
      if (isClosed) return;
      emit(CobrosAliadoState(fase: FaseCobros.listo, cobros: cobros));
    } on PagoFailure catch (f) {
      if (isClosed || silencioso) return;
      emit(CobrosAliadoState(fase: FaseCobros.error, error: f));
    }
  }
}
