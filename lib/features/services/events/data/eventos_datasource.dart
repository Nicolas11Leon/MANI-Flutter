import 'package:equatable/equatable.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/network/gateway_exception.dart';
import 'package:mani/features/services/quotes/data/cotizaciones_datasource.dart';
import 'package:mani/features/services/quotes/domain/cotizacion.dart';
import 'package:mani/features/services/requests/domain/entities/foto_adjunta.dart';

/// Tipo de evento que el aliado registra durante la ejecución (SCRUM-869).
enum TipoEventoAliado {
  avance('AVANCE', 'Avance'),
  novedad('NOVEDAD', 'Novedad'),
  observacion('OBSERVACION', 'Observación');

  const TipoEventoAliado(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;
}

/// Un evento de la línea de tiempo del servicio. El autor y la hora de
/// registro los pone Core. Un evento tomado sin conexión trae además la hora
/// de captura ([ocurridoEn], SCRUM-873), que es la oficial.
class EventoServicio extends Equatable {
  const EventoServicio({
    required this.id,
    required this.tipo,
    required this.registradoEn,
    DateTime? ocurridoEn,
    required this.autorRol,
    this.descripcion,
    this.tieneEvidencia = false,
  }) : ocurridoEn = ocurridoEn ?? registradoEn;

  factory EventoServicio.fromJson(Map<String, dynamic> json) {
    DateTime? fecha(String campo) =>
        DateTime.tryParse((json[campo] as String?) ?? '')?.toLocal();
    final autor = json['autor'] is Map
        ? Map<String, dynamic>.from(json['autor'] as Map)
        : const <String, dynamic>{};
    return EventoServicio(
      id: json['id'] as String,
      tipo: (json['tipo'] as String?) ?? '',
      descripcion: json['descripcion'] as String?,
      registradoEn:
          fecha('registradoEn') ?? DateTime.fromMillisecondsSinceEpoch(0),
      ocurridoEn: fecha('ocurridoEn'),
      autorRol: (autor['rol'] as String?) ?? '',
      tieneEvidencia: json['tieneEvidencia'] == true,
    );
  }

  final String id;
  final String tipo;
  final String? descripcion;
  final DateTime registradoEn;

  /// Hora de captura: la que se muestra. Igual a [registradoEn] si el evento
  /// no la trajo.
  final DateTime ocurridoEn;

  /// Se tomó sin conexión y llegó más de un minuto después.
  bool get llegoTarde => registradoEn.difference(ocurridoEn).inMinutes >= 1;
  final String autorRol;
  final bool tieneEvidencia;

  /// Texto del tipo; uno que la app no conoce se muestra tal cual.
  String get etiquetaTipo => switch (tipo) {
    'SOLICITUD_CREADA' => 'Solicitud creada',
    'COTIZACION_ENVIADA' => 'Cotización enviada',
    'COTIZACION_ACEPTADA' => 'Cotización aceptada',
    'COTIZACION_RECHAZADA' => 'Cotización rechazada',
    'AJUSTE_SOLICITADO' => 'Ajuste solicitado',
    'INICIO_EJECUCION' => 'Inicio del servicio',
    'FIN_EJECUCION' => 'Fin del servicio',
    'PAGO_REGISTRADO' => 'Pago aprobado',
    'EJECUCION_AVANCE' => 'Avance',
    'EJECUCION_NOVEDAD' => 'Novedad',
    'EJECUCION_OBSERVACION' => 'Observación',
    'SOLICITUD_ASIGNADA' => 'Aliado asignado',
    'SOLICITUD_CANCELADA' => 'Solicitud cancelada',
    'ADICION_SOLICITADA' => 'Adición solicitada',
    'ADICION_ACEPTADA' => 'Adición aceptada',
    'ADICION_RECHAZADA' => 'Adición rechazada',
    'CALIFICACION_ALIADO' => 'Calificación al aliado',
    'CALIFICACION_CLIENTE' => 'Calificación al cliente',
    'SERVICIO_CERRADO' => 'Servicio cerrado',
    _ => _legible(tipo),
  };

  /// Un tipo que la app no conoce se muestra como texto («SERVICIO_PAUSADO» → «Servicio pausado»), nunca como el
  /// código de Core.
  static String _legible(String codigo) {
    final texto = codigo.replaceAll('_', ' ').trim().toLowerCase();
    if (texto.isEmpty) return codigo;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  @override
  List<Object?> get props => [
    id,
    tipo,
    descripcion,
    registradoEn,
    ocurridoEn,
    autorRol,
    tieneEvidencia,
  ];
}

abstract interface class FuenteEventos {
  Future<List<EventoServicio>> listar(String solicitudId);

  Future<EventoServicio> registrar(
    String solicitudId, {
    required TipoEventoAliado tipo,
    required String observacion,
    required String claveIdempotencia,
    FotoAdjunta? foto,
    DateTime? ocurridoEn,
  });

  /// URL temporal de la foto de un evento (SCRUM-870). Vence en minutos: se
  /// pide cada vez que el usuario la abre.
  Future<Uri> urlEvidencia(String solicitudId, String eventoId);
}

/// Eventos del servicio por el Gateway a Core (US-04.3.2 / SCRUM-869). El
/// registro va en multipart con la foto opcional y la clave de idempotencia en
/// la cabecera, así el `GatewayClient` puede reintentar sin duplicar.
class GatewayFuenteEventos implements FuenteEventos {
  GatewayFuenteEventos(this._gateway);

  static String ruta(String solicitudId) =>
      '/api/v1/core/solicitudes/$solicitudId/eventos';
  static String rutaEvidencia(String solicitudId, String eventoId) =>
      '${ruta(solicitudId)}/$eventoId/evidencia';

  final GatewayClient _gateway;

  @override
  Future<List<EventoServicio>> listar(String solicitudId) async {
    try {
      final res = await _gateway.get(ruta(solicitudId));
      final lista = res['eventos'];
      if (lista is! List) {
        throw const FormatException('Respuesta de Core sin "eventos"');
      }
      return lista
          .whereType<Map>()
          .map((e) => EventoServicio.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } on GatewayException catch (e) {
      throw GatewayFuenteCotizaciones.mapearGateway(e);
    } on FormatException catch (e) {
      throw CotizacionFailure(CotizacionErrorTipo.desconocido, e.message);
    }
  }

  @override
  Future<EventoServicio> registrar(
    String solicitudId, {
    required TipoEventoAliado tipo,
    required String observacion,
    required String claveIdempotencia,
    FotoAdjunta? foto,
    DateTime? ocurridoEn,
  }) async {
    try {
      final res = await _gateway.postMultipart(
        ruta(solicitudId),
        campos: {
          'tipo': tipo.valor,
          'observacion': observacion,
          'claveIdempotencia': claveIdempotencia,
          // Solo los eventos de la cola sin conexión (SCRUM-873); en línea la
          // hora la pone Core, así un reloj desajustado no los rechaza.
          if (ocurridoEn != null)
            'ocurridoEn': ocurridoEn.toUtc().toIso8601String(),
        },
        archivos: [
          if (foto != null)
            ArchivoMultipart(
              campo: 'foto',
              nombre: 'evidencia.${foto.extension}',
              bytes: foto.bytes,
              tipoContenido: foto.mime,
            ),
        ],
        headers: {GatewayClient.headerIdempotencyKey: claveIdempotencia},
      );
      final e = res['evento'];
      if (e is! Map) {
        throw const FormatException('Respuesta de Core sin "evento"');
      }
      return EventoServicio.fromJson(Map<String, dynamic>.from(e));
    } on GatewayException catch (e) {
      throw GatewayFuenteCotizaciones.mapearGateway(e);
    } on FormatException catch (e) {
      throw CotizacionFailure(CotizacionErrorTipo.desconocido, e.message);
    }
  }

  @override
  Future<Uri> urlEvidencia(String solicitudId, String eventoId) async {
    try {
      final res = await _gateway.get(rutaEvidencia(solicitudId, eventoId));
      final evidencia = res['evidencia'];
      final url = evidencia is Map ? evidencia['url'] : null;
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null || !uri.hasScheme) {
        throw const FormatException('Respuesta de Core sin "evidencia.url"');
      }
      return uri;
    } on GatewayException catch (e) {
      throw GatewayFuenteCotizaciones.mapearGateway(e);
    } on FormatException catch (e) {
      throw CotizacionFailure(CotizacionErrorTipo.desconocido, e.message);
    }
  }
}
