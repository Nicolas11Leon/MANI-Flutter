import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/features/profiles/company_sites/domain/entities/sede_empresa.dart';
import 'package:mani/features/profiles/company_sites/domain/usecases/sedes_empresa_usecases.dart';

class SedesEmpresaState extends Equatable {
  const SedesEmpresaState({
    this.sedes = const [],
    this.zonas = const [],
    this.cargando = false,
    this.error,
    this.aviso,
    this.soloClientesEmpresa = false,
  });

  final List<SedeEmpresa> sedes;

  /// Catálogo completo de zonas: las elegibles alimentan el selector y el
  /// resto sirve para nombrar la zona padre.
  final List<ZonaSede> zonas;
  final bool cargando;
  final String? error;

  /// Confirmación de la última acción («Sede actualizada.»).
  final String? aviso;

  /// La cuenta no es de un cliente empresa: la pantalla muestra una explicación y no los formularios.
  final bool soloClientesEmpresa;

  List<ZonaSede> get zonasElegibles {
    final elegibles = zonas.where((z) => z.elegible).toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    return elegibles;
  }

  /// «Padre · Zona» para mostrar; si la zona no está en el catálogo, su id.
  String nombreZona(String zonaId) {
    final porId = {for (final z in zonas) z.id: z};
    final zona = porId[zonaId];
    if (zona == null) return zonaId;
    final padre = zona.padreId == null ? null : porId[zona.padreId];
    return padre == null ? zona.nombre : '${padre.nombre} · ${zona.nombre}';
  }

  SedesEmpresaState copyWith({
    List<SedeEmpresa>? sedes,
    List<ZonaSede>? zonas,
    bool? cargando,
    String? error,
    String? aviso,
    bool? soloClientesEmpresa,
  }) {
    return SedesEmpresaState(
      sedes: sedes ?? this.sedes,
      zonas: zonas ?? this.zonas,
      cargando: cargando ?? this.cargando,
      error: error,
      aviso: aviso,
      soloClientesEmpresa: soloClientesEmpresa ?? this.soloClientesEmpresa,
    );
  }

  @override
  List<Object?> get props => [
    sedes,
    zonas,
    cargando,
    error,
    aviso,
    soloClientesEmpresa,
  ];
}

class SedesEmpresaCubit extends Cubit<SedesEmpresaState> {
  SedesEmpresaCubit({
    required this.listarUseCase,
    required this.agregarUseCase,
    required this.editarUseCase,
    required this.listarZonasUseCase,
  }) : super(const SedesEmpresaState());

  final ListarSedesEmpresaUseCase listarUseCase;
  final AgregarSedeEmpresaUseCase agregarUseCase;
  final EditarSedeEmpresaUseCase editarUseCase;
  final ListarZonasSedeUseCase listarZonasUseCase;

  /// Carga las sedes y el catálogo de zonas a la vez. Si fallan las zonas, la
  /// lista se muestra igual, pero sin zonas no se puede registrar ni editar.
  Future<void> cargar() async {
    emit(state.copyWith(cargando: true));
    // El fallo de las zonas se captura desde ya: si llegara mientras se
    // esperan las sedes, quedaría como un error sin manejar.
    final zonas = listarZonasUseCase().then<List<ZonaSede>?>(
      (z) => z,
      onError: (Object _) => null,
    );
    final List<SedeEmpresa> sedes;
    try {
      sedes = await listarUseCase();
    } on SedeEmpresaFailure catch (e) {
      emit(
        e.soloClientesEmpresa
            ? const SedesEmpresaState(soloClientesEmpresa: true)
            : state.copyWith(cargando: false, error: e.message),
      );
      return;
    }
    final catalogo = await zonas;
    if (catalogo == null) {
      emit(
        SedesEmpresaState(
          sedes: sedes,
          error:
              'No se pudieron cargar las zonas. Puedes ver tus sedes, pero '
              'no registrar ni editar hasta volver a intentarlo.',
        ),
      );
      return;
    }
    emit(SedesEmpresaState(sedes: sedes, zonas: catalogo));
  }

  Future<void> agregar(NuevaSedeEmpresa sede) async {
    emit(state.copyWith(cargando: true));
    try {
      final creada = await agregarUseCase(sede);
      emit(
        state.copyWith(
          cargando: false,
          // Se reemplaza la sede si ya estaba en la lista en vez de añadirla
          // siempre: una recarga que llegue entre el POST y este emit la deja
          // dos veces, y dos tarjetas con la misma Key rompen el Column con
          // "Duplicate keys found".
          sedes: [...state.sedes.where((s) => s.id != creada.id), creada],
          aviso: 'Sede registrada.',
        ),
      );
    } on SedeEmpresaFailure catch (e) {
      emit(state.copyWith(cargando: false, error: e.message));
    }
  }

  /// Devuelve `true` si Core guardó el cambio, para cerrar el formulario.
  Future<bool> editar(SedeEmpresa actual, NuevaSedeEmpresa datos) async {
    emit(state.copyWith(cargando: true));
    try {
      final editada = await editarUseCase(actual, datos);
      emit(
        state.copyWith(
          cargando: false,
          sedes: [
            for (final s in state.sedes) s.id == editada.id ? editada : s,
          ],
          aviso: 'Sede actualizada.',
        ),
      );
      return true;
    } on SedeEmpresaFailure catch (e) {
      emit(state.copyWith(cargando: false, error: e.message));
      return false;
    }
  }
}
