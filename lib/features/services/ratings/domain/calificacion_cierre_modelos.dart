import 'package:equatable/equatable.dart';

/// Calificación emitida en un sentido (SCRUM-874: CLIENT -> ALLY;
/// SCRUM-875: ALLY -> CLIENT).
class CalificacionServicio extends Equatable {
  const CalificacionServicio({
    required this.id,
    required this.solicitudId,
    required this.autorId,
    required this.destinatarioId,
    required this.rolAutor,
    required this.puntaje,
    required this.creadaEn,
    this.comentario,
  });

  factory CalificacionServicio.fromJson(Map<String, dynamic> json) {
    return CalificacionServicio(
      id: (json['id'] as String?) ?? '',
      solicitudId: (json['solicitudId'] as String?) ?? '',
      autorId: (json['autorId'] as String?) ?? '',
      destinatarioId: (json['destinatarioId'] as String?) ?? '',
      // Core informa la dirección (CLIENTE_A_ALIADO / ALIADO_A_CLIENTE), no el rol.
      rolAutor:
          (json['rolAutor'] as String?) ??
          switch (json['direccion']) {
            'CLIENTE_A_ALIADO' => 'CLIENT',
            'ALIADO_A_CLIENTE' => 'ALLY',
            _ => '',
          },
      puntaje: (json['puntaje'] as num?)?.toInt() ?? 0,
      comentario: json['comentario'] as String?,
      creadaEn:
          DateTime.tryParse((json['creadaEn'] as String?) ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String solicitudId;
  final String autorId;
  final String destinatarioId;
  final String rolAutor;
  final int puntaje;
  final String? comentario;
  final DateTime creadaEn;

  bool get esDeCliente => rolAutor.trim().toUpperCase() == 'CLIENT';
  bool get esDeAliado => rolAutor.trim().toUpperCase() == 'ALLY';

  @override
  List<Object?> get props => [
    id,
    solicitudId,
    autorId,
    destinatarioId,
    rolAutor,
    puntaje,
    comentario,
    creadaEn,
  ];
}

/// Estado del cierre condicionado a la calificación bidireccional
/// (SCRUM-1418 / HU-M08-03).
class EstadoCierreSolicitud extends Equatable {
  const EstadoCierreSolicitud({
    required this.cerrada,
    required this.estadoSolicitud,
    required this.tieneCalificacionCliente,
    required this.tieneCalificacionAliado,
    required this.pendientes,
    this.cerradaEn,
  });

  factory EstadoCierreSolicitud.fromJson(Map<String, dynamic> json) {
    final pendientesRaw = json['pendientes'];
    final estado = (json['estadoSolicitud'] as String?) ?? 'COMPLETADA';
    // Core: calificacionClienteRegistrada / calificacionAliadoRegistrada.
    final cliente =
        json['tieneCalificacionCliente'] == true ||
        json['calificacionClienteRegistrada'] == true;
    final aliado =
        json['tieneCalificacionAliado'] == true ||
        json['calificacionAliadoRegistrada'] == true;
    return EstadoCierreSolicitud(
      cerrada: json['cerrada'] == true || estado.toUpperCase() == 'CERRADA',
      estadoSolicitud: estado,
      cerradaEn: json['cerradaEn'] is String
          ? DateTime.tryParse(json['cerradaEn'] as String)?.toLocal()
          : null,
      tieneCalificacionCliente: cliente,
      tieneCalificacionAliado: aliado,
      pendientes: pendientesRaw is List
          ? pendientesRaw.whereType<String>().toList(growable: false)
          : [if (!cliente) 'CLIENTE', if (!aliado) 'ALIADO'],
    );
  }

  final bool cerrada;
  final String estadoSolicitud;
  final DateTime? cerradaEn;
  final bool tieneCalificacionCliente;
  final bool tieneCalificacionAliado;
  final List<String> pendientes;

  bool get cierreCompleto =>
      cerrada && tieneCalificacionCliente && tieneCalificacionAliado;

  String get etiquetaEstadoCierre {
    if (cierreCompleto) return 'Cerrada (ambas calificaciones registradas)';
    if (!tieneCalificacionCliente && !tieneCalificacionAliado) {
      return 'Pendiente de calificación de cliente y aliado';
    }
    if (!tieneCalificacionCliente) {
      return 'Pendiente de calificación del cliente';
    }
    return 'Pendiente de calificación del aliado';
  }

  @override
  List<Object?> get props => [
    cerrada,
    estadoSolicitud,
    cerradaEn,
    tieneCalificacionCliente,
    tieneCalificacionAliado,
    pendientes,
  ];
}

/// Estado consolidado de calificaciones y cierre de una solicitud.
class ResumenCalificacionesSolicitud extends Equatable {
  const ResumenCalificacionesSolicitud({
    required this.solicitudId,
    required this.estado,
    required this.cierre,
    this.clienteAAliado,
    this.aliadoACliente,
  });

  factory ResumenCalificacionesSolicitud.fromJson(Map<String, dynamic> json) {
    final califs = json['calificaciones'] is Map
        ? Map<String, dynamic>.from(json['calificaciones'] as Map)
        : const <String, dynamic>{};
    final cierreMap = json['cierre'] is Map
        ? Map<String, dynamic>.from(json['cierre'] as Map)
        : const <String, dynamic>{};
    // Core responde `calificaciones.clienteAlAliado` / `aliadoAlCliente` y el
    // estado de la solicitud dentro de `cierre.estadoSolicitud`.
    CalificacionServicio? leer(List<String> claves) {
      for (final c in claves) {
        if (califs[c] is Map) {
          return CalificacionServicio.fromJson(
            Map<String, dynamic>.from(califs[c] as Map),
          );
        }
      }
      return null;
    }

    return ResumenCalificacionesSolicitud(
      solicitudId:
          (json['solicitudId'] as String?) ??
          (cierreMap['solicitudId'] as String?) ??
          '',
      estado:
          (json['estado'] as String?) ??
          (cierreMap['estadoSolicitud'] as String?) ??
          '',
      cierre: EstadoCierreSolicitud.fromJson(cierreMap),
      clienteAAliado: leer(['clienteAlAliado', 'clienteAAliado']),
      aliadoACliente: leer(['aliadoAlCliente', 'aliadoACliente']),
    );
  }

  final String solicitudId;
  final String estado;
  final EstadoCierreSolicitud cierre;
  final CalificacionServicio? clienteAAliado;
  final CalificacionServicio? aliadoACliente;

  @override
  List<Object?> get props => [
    solicitudId,
    estado,
    cierre,
    clienteAAliado,
    aliadoACliente,
  ];
}

/// Calificación agregada de un aliado en el listado (SCRUM-876).
class CalificacionAgregadaAliado extends Equatable {
  const CalificacionAgregadaAliado({
    required this.aliadoId,
    required this.nombreRazonSocial,
    required this.tipo,
    required this.estadoVerificacion,
    required this.totalCalificaciones,
    this.calificacionPromedio,
    this.etiquetaCalificacion,
  });

  factory CalificacionAgregadaAliado.fromJson(Map<String, dynamic> json) {
    final total = (json['totalCalificaciones'] as num?)?.toInt() ?? 0;
    final promedio = (json['calificacionPromedio'] as num?)?.toDouble();
    return CalificacionAgregadaAliado(
      aliadoId: (json['aliadoId'] as String?) ?? (json['id'] as String?) ?? '',
      nombreRazonSocial: (json['nombreRazonSocial'] as String?) ?? '',
      tipo: (json['tipo'] as String?) ?? '',
      estadoVerificacion:
          (json['estadoVerificacion'] as String?) ?? 'VERIFICADO',
      totalCalificaciones: total < 0 ? 0 : total,
      calificacionPromedio: total > 0 ? promedio : null,
      etiquetaCalificacion: json['etiquetaCalificacion'] as String?,
    );
  }

  final String aliadoId;
  final String nombreRazonSocial;
  final String tipo;
  final String estadoVerificacion;
  final double? calificacionPromedio;
  final int totalCalificaciones;
  final String? etiquetaCalificacion;

  bool get tieneCalificaciones =>
      totalCalificaciones > 0 && calificacionPromedio != null;

  /// SCRUM-876 (C2): nunca muestra `0.0` cuando no tiene calificaciones.
  String get textoVisible {
    if (!tieneCalificaciones) {
      return etiquetaCalificacion ?? 'Sin valorar';
    }
    return '★ ${calificacionPromedio!.toStringAsFixed(1)} ($totalCalificaciones)';
  }

  @override
  List<Object?> get props => [
    aliadoId,
    nombreRazonSocial,
    tipo,
    estadoVerificacion,
    calificacionPromedio,
    totalCalificaciones,
    etiquetaCalificacion,
  ];
}

/// Vista previa de penalización por cancelación tardía (SCRUM-878).
/// Estados en los que Core ya no admite cancelar (SCRUM-877).
const _estadosNoCancelables = {
  'CANCELADA',
  'EN_EJECUCION',
  'FINALIZADA',
  'CERRADA',
};

class VistaPreviaPenalizacion extends Equatable {
  const VistaPreviaPenalizacion({
    required this.solicitudId,
    required this.estadoActual,
    required this.cancelable,
    required this.aplicaPenalizacion,
    required this.montoPenalizacion,
    required this.politicaActiva,
    this.motivoPenalizacion,
    this.modoCalculo,
  });

  factory VistaPreviaPenalizacion.fromJson(Map<String, dynamic> json) {
    // Forma que responde Core en GET /solicitudes/me/{id}/cancelacion-preview
    // (calculoPenalizacionCancelacion.js): campos planos dentro de `penalizacion`,
    // con `razon` y sin `cancelable`.
    if (json.containsKey('aplicaPenalizacion')) {
      final estado = (json['estadoActual'] as String?) ?? '';
      return VistaPreviaPenalizacion(
        solicitudId: (json['solicitudId'] as String?) ?? '',
        estadoActual: estado,
        cancelable: !_estadosNoCancelables.contains(estado.toUpperCase()),
        aplicaPenalizacion: json['aplicaPenalizacion'] == true,
        montoPenalizacion: (json['montoPenalizacion'] as num?)?.toDouble() ?? 0,
        motivoPenalizacion: json['razon'] as String?,
        modoCalculo: json['tipoCobro'] as String?,
        politicaActiva: json['politicaActiva'] == true,
      );
    }
    final pen = json['penalizacion'] is Map
        ? Map<String, dynamic>.from(json['penalizacion'] as Map)
        : const <String, dynamic>{};
    final pol = json['politicaVigente'] is Map
        ? Map<String, dynamic>.from(json['politicaVigente'] as Map)
        : const <String, dynamic>{};
    return VistaPreviaPenalizacion(
      solicitudId: (json['solicitudId'] as String?) ?? '',
      estadoActual: (json['estadoActual'] as String?) ?? '',
      cancelable: json['cancelable'] == true,
      aplicaPenalizacion: pen['aplica'] == true,
      montoPenalizacion: (pen['monto'] as num?)?.toDouble() ?? 0,
      motivoPenalizacion: pen['motivo'] as String?,
      modoCalculo: pen['modoCalculo'] as String?,
      politicaActiva: pol['activa'] == true,
    );
  }

  final String solicitudId;
  final String estadoActual;
  final bool cancelable;
  final bool aplicaPenalizacion;
  final double montoPenalizacion;
  final String? motivoPenalizacion;
  final String? modoCalculo;
  final bool politicaActiva;

  String get resumenUsuario {
    if (!aplicaPenalizacion || montoPenalizacion <= 0) {
      return 'Sin penalización por cancelación (\$0).';
    }
    return 'Penalización por cancelación tardía: \$${montoPenalizacion.toStringAsFixed(0)}';
  }

  @override
  List<Object?> get props => [
    solicitudId,
    estadoActual,
    cancelable,
    aplicaPenalizacion,
    montoPenalizacion,
    motivoPenalizacion,
    modoCalculo,
    politicaActiva,
  ];
}

/// Elemento del historial de servicios del cliente (SCRUM-879) o de trabajos
/// del aliado (SCRUM-880).
class RegistroHistorialServicio extends Equatable {
  const RegistroHistorialServicio({
    required this.id,
    required this.estado,
    required this.categoriaId,
    required this.categoria,
    required this.descripcion,
    required this.direccion,
    required this.zona,
    required this.creadaEn,
    this.zonaPadre,
    this.nombreContraparte,
    this.valorTotal,
    this.penalizacionAplicada = false,
    this.penalizacionMonto = 0,
    this.calificacionEmitida,
    this.calificacionRecibida,
    this.calificacionRecibidaRegistrada = false,
    this.cerradaEn,
  });

  static CalificacionServicio? _leerCalificacion(
    Map<String, dynamic> califs,
    String clave,
  ) {
    final valor = califs[clave];
    return valor is Map
        ? CalificacionServicio.fromJson(Map<String, dynamic>.from(valor))
        : null;
  }

  static RegistroHistorialServicio _desdeJsonComun(
    Map<String, dynamic> json, {
    required String categoriaPorDefecto,
    required String? nombreContraparte,
    // (clave de Core, clave anterior)
    required (String, String) claveEmitida,
    required (String, String) claveRecibida,
  }) {
    // El historial del aliado trae `penalizacionCancelacion` y `valorCotizado`; la
    // zona viene en `zonaDeclarada` en ambos historiales.
    final penRaw = json['penalizacion'] ?? json['penalizacionCancelacion'];
    final pen = penRaw is Map
        ? Map<String, dynamic>.from(penRaw)
        : const <String, dynamic>{};
    final califs = json['calificaciones'] is Map
        ? Map<String, dynamic>.from(json['calificaciones'] as Map)
        : const <String, dynamic>{};
    final zonaDeclarada = json['zonaDeclarada'] is Map
        ? Map<String, dynamic>.from(json['zonaDeclarada'] as Map)
        : const <String, dynamic>{};
    return RegistroHistorialServicio(
      id: (json['id'] as String?) ?? '',
      estado: (json['estado'] as String?) ?? '',
      categoriaId: (json['categoriaId'] as String?) ?? '',
      categoria: (json['categoria'] as String?) ?? categoriaPorDefecto,
      descripcion: (json['descripcion'] as String?) ?? '',
      direccion: (json['direccion'] as String?) ?? '',
      zona:
          (json['zona'] as String?) ??
          (zonaDeclarada['nombre'] as String?) ??
          '',
      zonaPadre:
          (json['zonaPadre'] as String?) ??
          (zonaDeclarada['zonaPadre'] as String?),
      nombreContraparte: nombreContraparte,
      valorTotal: ((json['valorTotal'] ?? json['valorCotizado']) as num?)
          ?.toDouble(),
      penalizacionAplicada: pen['aplicada'] == true,
      penalizacionMonto: (pen['monto'] as num?)?.toDouble() ?? 0,
      calificacionEmitida:
          _leerCalificacion(califs, claveEmitida.$1) ??
          _leerCalificacion(califs, claveEmitida.$2),
      calificacionRecibida:
          _leerCalificacion(califs, claveRecibida.$1) ??
          _leerCalificacion(califs, claveRecibida.$2),
      // Core oculta la calificación del otro participante (es privada) y
      // solo informa si ya existe.
      calificacionRecibidaRegistrada:
          califs['calificacionRecibidaRegistrada'] == true ||
          _leerCalificacion(califs, claveRecibida.$1) != null ||
          _leerCalificacion(califs, claveRecibida.$2) != null,
      creadaEn:
          DateTime.tryParse((json['creadaEn'] as String?) ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      cerradaEn: json['cerradaEn'] is String
          ? DateTime.tryParse(json['cerradaEn'] as String)?.toLocal()
          : null,
    );
  }

  factory RegistroHistorialServicio.desdeHistorialCliente(
    Map<String, dynamic> json,
  ) {
    final aliado = json['aliado'] is Map
        ? Map<String, dynamic>.from(json['aliado'] as Map)
        : null;
    return _desdeJsonComun(
      json,
      categoriaPorDefecto: 'Servicio',
      nombreContraparte: aliado?['nombreRazonSocial'] as String?,
      claveEmitida: ('clienteAlAliado', 'emitidaAlAliado'),
      claveRecibida: ('aliadoAlCliente', 'recibidaDelAliado'),
    );
  }

  factory RegistroHistorialServicio.desdeHistorialAliado(
    Map<String, dynamic> json,
  ) {
    final cliente = json['cliente'] is Map
        ? Map<String, dynamic>.from(json['cliente'] as Map)
        : null;
    return _desdeJsonComun(
      json,
      categoriaPorDefecto: 'Trabajo',
      nombreContraparte: cliente?['nombre'] as String?,
      claveEmitida: ('aliadoAlCliente', 'emitidaAlCliente'),
      claveRecibida: ('clienteAlAliado', 'recibidaDelCliente'),
    );
  }

  final String id;
  final String estado;
  final String categoriaId;
  final String categoria;
  final String descripcion;
  final String direccion;
  final String zona;
  final String? zonaPadre;
  final String? nombreContraparte;
  final double? valorTotal;
  final bool penalizacionAplicada;
  final double penalizacionMonto;
  final CalificacionServicio? calificacionEmitida;
  final CalificacionServicio? calificacionRecibida;

  /// El otro participante ya calificó. El puntaje es privado: solo lo ve el
  /// administrador del tenant.
  final bool calificacionRecibidaRegistrada;
  final DateTime creadaEn;
  final DateTime? cerradaEn;

  @override
  List<Object?> get props => [
    id,
    estado,
    categoriaId,
    categoria,
    descripcion,
    direccion,
    zona,
    zonaPadre,
    nombreContraparte,
    valorTotal,
    penalizacionAplicada,
    penalizacionMonto,
    calificacionEmitida,
    calificacionRecibida,
    calificacionRecibidaRegistrada,
    creadaEn,
    cerradaEn,
  ];
}

enum ModuloM08ErrorTipo {
  puntajeInvalido, // MANI-CAL-422P
  comentarioInvalido, // MANI-CAL-422C
  calificacionDuplicada, // MANI-CAL-409D
  servicioNoEjecutado, // MANI-CAL-409E
  cierreIncompleto, // MANI-CAL-409C
  sinPermiso, // 403 / MANI-CAL-403* / MANI-HIS-403*
  noEncontrado, // 404 / MANI-CAL-404* / MANI-HIS-404
  sinSesion, // 401
  servicioNoDisponible, // 5xx
  sinConexion,
  desconocido,
}

class ModuloM08Failure implements Exception {
  const ModuloM08Failure(this.tipo, [this.detalle]);

  final ModuloM08ErrorTipo tipo;
  final String? detalle;

  String get mensajeUsuario => switch (tipo) {
    ModuloM08ErrorTipo.puntajeInvalido =>
      'Selecciona una calificación válida entre 1 y 5 estrellas.',
    ModuloM08ErrorTipo.comentarioInvalido =>
      'El comentario no puede superar 500 caracteres.',
    ModuloM08ErrorTipo.calificacionDuplicada =>
      'Ya registraste tu calificación para este servicio.',
    ModuloM08ErrorTipo.servicioNoEjecutado =>
      'Solo puedes calificar un servicio cuya ejecución haya finalizado.',
    ModuloM08ErrorTipo.cierreIncompleto =>
      'El servicio no puede declararse cerrado hasta contar con las calificaciones de cliente y aliado.',
    ModuloM08ErrorTipo.sinPermiso =>
      'No tienes permiso para realizar esta acción sobre el servicio.',
    ModuloM08ErrorTipo.noEncontrado =>
      'No encontramos el servicio solicitado en tu organización.',
    ModuloM08ErrorTipo.sinSesion =>
      'Tu sesión expiró. Vuelve a iniciar sesión.',
    ModuloM08ErrorTipo.servicioNoDisponible =>
      'El servicio no está disponible temporalmente. Inténtalo de nuevo.',
    ModuloM08ErrorTipo.sinConexion =>
      'Sin conexión. Verifica tu internet e inténtalo de nuevo.',
    ModuloM08ErrorTipo.desconocido =>
      detalle ?? 'No pudimos completar la operación.',
  };

  @override
  String toString() => 'ModuloM08Failure(${tipo.name}, $detalle)';
}
