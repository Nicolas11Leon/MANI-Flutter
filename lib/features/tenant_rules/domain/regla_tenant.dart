/// Reglas operativas propias por tenant (SCRUM-1366 / HU-M01-03).
class ReglasOperativas {
  const ReglasOperativas({
    required this.criterioOrden,
    required this.toleranciaTarifa,
    required this.comisionPorcentaje,
    required this.ventanaCancelacionHoras,
    required this.penalizacionCancelacion,
    required this.minutosParaAceptarOferta,
  });

  final String criterioOrden; // CALIFICACION | COBERTURA
  final double toleranciaTarifa; // 0..50
  final double comisionPorcentaje; // 0..30
  final double ventanaCancelacionHoras; // 0..72
  final double penalizacionCancelacion; // 0..100
  final int minutosParaAceptarOferta; // 1..1440

  factory ReglasOperativas.fromJson(Map<String, dynamic> json) {
    final orden = json['ordenListado'] as Map<String, dynamic>? ?? {};
    final alerta = json['alertaTarifa'] as Map<String, dynamic>? ?? {};
    final com = json['comision'] as Map<String, dynamic>? ?? {};
    final canc = json['cancelacion'] as Map<String, dynamic>? ?? {};
    final oft = json['oferta'] as Map<String, dynamic>? ?? {};

    return ReglasOperativas(
      criterioOrden: (orden['criterio'] ?? 'CALIFICACION')
          .toString()
          .toUpperCase(),
      toleranciaTarifa:
          (alerta['toleranciaPorcentaje'] as num?)?.toDouble() ?? 10.0,
      comisionPorcentaje: (com['porcentaje'] as num?)?.toDouble() ?? 10.0,
      ventanaCancelacionHoras:
          (canc['ventanaHoras'] as num?)?.toDouble() ?? 2.0,
      penalizacionCancelacion:
          (canc['penalizacionPorcentaje'] as num?)?.toDouble() ?? 20.0,
      minutosParaAceptarOferta:
          (oft['minutosParaAceptar'] as num?)?.toInt() ?? 15,
    );
  }

  Map<String, dynamic> toJson() => {
    'ordenListado': {'criterio': criterioOrden},
    'alertaTarifa': {'toleranciaPorcentaje': toleranciaTarifa},
    'comision': {'porcentaje': comisionPorcentaje},
    'cancelacion': {
      'ventanaHoras': ventanaCancelacionHoras,
      'penalizacionPorcentaje': penalizacionCancelacion,
    },
    'oferta': {'minutosParaAceptar': minutosParaAceptarOferta},
  };
}

class ReglaTenantVigente {
  const ReglaTenantVigente({
    this.id,
    required this.version,
    required this.origen,
    this.estado,
    required this.reglas,
    this.auditoria,
  });

  final String? id;
  final int version;
  final String origen; // POR_OMISION | PROPIO
  final String? estado;
  final ReglasOperativas reglas;
  final Map<String, dynamic>? auditoria;

  factory ReglaTenantVigente.fromJson(Map<String, dynamic> json) {
    return ReglaTenantVigente(
      id: json['id'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 0,
      origen: json['origen'] as String? ?? 'POR_OMISION',
      estado: json['estado'] as String?,
      reglas: ReglasOperativas.fromJson(
        json['reglas'] as Map<String, dynamic>? ?? {},
      ),
      auditoria: json['auditoria'] as Map<String, dynamic>?,
    );
  }
}

class ReglaTenantHistorialItem {
  const ReglaTenantHistorialItem({
    required this.id,
    required this.version,
    required this.estado,
    required this.reglas,
    this.auditoria,
  });

  final String id;
  final int version;
  final String estado;
  final ReglasOperativas reglas;
  final Map<String, dynamic>? auditoria;

  factory ReglaTenantHistorialItem.fromJson(Map<String, dynamic> json) {
    return ReglaTenantHistorialItem(
      id: json['id'] as String? ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      estado: json['estado'] as String? ?? 'HISTORICA',
      reglas: ReglasOperativas.fromJson(
        json['reglas'] as Map<String, dynamic>? ?? {},
      ),
      auditoria: json['auditoria'] as Map<String, dynamic>?,
    );
  }
}
