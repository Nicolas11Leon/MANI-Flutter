/// Error de una petición al API Gateway, ya traducido a un mensaje que se
/// puede mostrar al usuario.
///
/// [statusCode] es `null` cuando la petición no llegó a tener respuesta
/// (sin red, timeout, DNS).
class GatewayException implements Exception {
  const GatewayException({
    required this.message,
    this.statusCode,
    this.correlationId,
    this.cuerpo,
  });

  /// Construye el error a partir del status HTTP. [detalle] es el mensaje que
  /// devuelve el servicio (campo `message` o `error` del cuerpo); solo se usa
  /// en los 400 y 409, donde explica qué campo o dato hay que corregir.
  factory GatewayException.fromStatus(
    int statusCode, {
    String? detalle,
    String? correlationId,
    Map<String, dynamic>? cuerpo,
  }) {
    final String message;
    if (statusCode == 400 || statusCode == 422) {
      message =
          detalle ?? 'Revisa los datos del formulario e inténtalo de nuevo.';
    } else if (statusCode == 401) {
      message = 'Tu sesión no es válida o expiró. Inicia sesión de nuevo.';
    } else if (statusCode == 403) {
      message = 'No tienes permiso para realizar esta acción.';
    } else if (statusCode == 404) {
      message = 'El servicio solicitado no está disponible.';
    } else if (statusCode == 409) {
      message = detalle ?? 'Ya existe un registro con estos datos.';
    } else if (statusCode == 413) {
      message = 'Los archivos adjuntos superan el tamaño permitido.';
    } else if (statusCode >= 500) {
      message =
          'El servicio no está disponible en este momento. Inténtalo más tarde.';
    } else {
      message = detalle ?? 'No se pudo completar la solicitud ($statusCode).';
    }
    return GatewayException(
      message: message,
      statusCode: statusCode,
      correlationId: correlationId,
      cuerpo: cuerpo,
    );
  }

  final String message;
  final int? statusCode;

  /// `X-Correlation-ID` de la petición, para rastrearla en los logs del
  /// Gateway y de los servicios.
  final String? correlationId;

  /// Cuerpo JSON de la respuesta de error, si lo hubo. Permite a cada feature
  /// leer los códigos de negocio del servicio (`code`, `violations[].code`)
  /// sin depender del texto de [message].
  final Map<String, dynamic>? cuerpo;

  /// Código de negocio de Core con la forma `MANI-XXX-NNN` (por ejemplo
  /// `MANI-SOL-422Z`), o `null` si la respuesta no lo trae. Sale del campo
  /// `code` del cuerpo y, si no está, del prefijo del mensaje (los errores de
  /// Core empiezan con su código). Es lo que debe decidir qué se le dice al
  /// usuario: el status HTTP solo sirve para códigos que la app no conoce.
  String? get codigo {
    final delCuerpo = cuerpo?['code'];
    if (delCuerpo is String && _formatoCodigo.hasMatch(delCuerpo)) {
      return delCuerpo;
    }
    return _prefijoCodigo.firstMatch(message)?.group(1);
  }

  /// Referencia para rastrear la petición en los logs: el `correlationId` que
  /// Core devuelve en el cuerpo del error o, si no, el que la app envió en la
  /// cabecera `X-Correlation-ID`.
  String? get referencia {
    final delCuerpo = cuerpo?['correlationId'];
    if (delCuerpo is String && delCuerpo.isNotEmpty && delCuerpo != 'none') {
      return delCuerpo;
    }
    return correlationId;
  }

  /// Línea de diagnóstico para mostrar en texto pequeño junto al error:
  /// `Código: MANI-SOL-422Z · Ref: 3f2a…`. Omite la parte que no existe y es
  /// `null` si no hay ninguna de las dos.
  String? get lineaDeDiagnostico =>
      lineaDeDiagnosticoDe(codigo: codigo, referencia: referencia);

  /// Arma la línea de diagnóstico a partir de un código y una referencia ya
  /// conocidos (para los errores de feature que los guardan por separado).
  static String? lineaDeDiagnosticoDe({String? codigo, String? referencia}) {
    final partes = <String>[
      if (codigo != null && codigo.isNotEmpty) 'Código: $codigo',
      if (referencia != null && referencia.isNotEmpty) 'Ref: $referencia',
    ];
    return partes.isEmpty ? null : partes.join(' · ');
  }

  static final _formatoCodigo = RegExp(r'^MANI-[A-Z0-9]+-[0-9]{3}[A-Z]?$');
  static final _prefijoCodigo = RegExp(
    r'^\s*(MANI-[A-Z0-9]+-[0-9]{3}[A-Z]?)\b',
  );

  /// Indica si el error se debe a un conflicto de concurrencia o duplicado (HTTP 409).
  bool get isConflict => statusCode == 409;

  /// Indica si el error se debe a falta de autenticación o expiración de token (HTTP 401).
  bool get isUnauthorized => statusCode == 401;

  /// Indica si el error se debe a permisos insuficientes (HTTP 403).
  bool get isForbidden => statusCode == 403;

  /// Indica si ocurrió un fallo de red o timeout sin respuesta del servidor.
  bool get isConnectionError => statusCode == null;

  @override
  String toString() =>
      'GatewayException($statusCode, $message, correlation: $correlationId)';
}
