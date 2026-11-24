import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mani/core/logging/structured_logger.dart';
import 'package:mani/core/network/gateway_exception.dart';
import 'package:mani/core/utils/generador_id.dart';

import '../../domain/entities/catalogo_solicitud.dart';
import '../../domain/entities/nueva_solicitud.dart';
import '../../domain/entities/solicitud_publicada.dart';
import '../../domain/failures/solicitud_failure.dart';
import '../../domain/repositories/solicitudes_cliente_repository.dart';
import '../datasources/solicitudes_cliente_remote_datasource.dart';
import '../models/solicitud_models.dart';

class SolicitudesClienteRepositoryImpl implements SolicitudesClienteRepository {
  SolicitudesClienteRepositoryImpl(this._ds, {StructuredLogger? logger})
    : _log = logger ?? StructuredLogger(canal: 'mani.solicitudes');

  final SolicitudesClienteRemoteDataSource _ds;
  final StructuredLogger _log;

  static const _evento = 'US-04.1.1.crear_solicitud';

  @override
  Future<List<CategoriaDisponible>> categoriasDisponibles() => _guard(
    () async => (await _ds.listarCategorias())
        .map<CategoriaDisponible>(CategoriaDisponibleModel.fromJson)
        .toList(),
  );

  @override
  Future<List<SitioCliente>> misSitios() => _guard(
    () async => (await _ds.listarSitios())
        .map<SitioCliente>(SitioClienteModel.fromJson)
        .toList(),
  );

  @override
  Future<List<ZonaOpcion>> buscarZonas(String texto) => _guard(
    () async => (await _ds.buscarZonas(
      texto,
    )).map<ZonaOpcion>(ZonaOpcionModel.fromJson).toList(),
  );

  /// Envía la solicitud con sus fotos a Core por el Gateway en una sola
  /// petición. Core sube las fotos, crea la solicitud y, si falla o es un
  /// reintento, borra lo que subió: la app ya no compensa en Storage.
  ///
  /// Si la respuesta se pierde (sin conexión), el reintento con la misma
  /// clave de idempotencia devuelve la solicitud que Core ya creó.
  @override
  Future<SolicitudPublicada> publicar(NuevaSolicitud solicitud) async {
    final traceId = StructuredLogger.nuevoTraceId();
    final tenantId = _ds.tenantIdSesion;
    final sw = Stopwatch()..start();
    try {
      if (_ds.usuarioId == null) {
        throw const SolicitudFailure(SolicitudErrorTipo.sinSesion);
      }
      final ubicacion = solicitud.ubicacion;
      final publicada = await _guard(
        () async => SolicitudPublicadaModel.fromJson(
          await _ds.crear(
            categoriaId: solicitud.categoria.id,
            descripcion: solicitud.descripcion,
            fotos: solicitud.fotos,
            claveIdempotencia: solicitud.claveIdempotencia,
            sitioId: switch (ubicacion) {
              SitioExistente(:final sitio) => sitio.id,
              NuevaDireccion() => null,
            },
            direccion: switch (ubicacion) {
              NuevaDireccion(:final direccion) => direccion,
              SitioExistente() => null,
            },
            zonaId: switch (ubicacion) {
              NuevaDireccion(:final zona) => zona.id,
              SitioExistente() => null,
            },
          ),
        ),
      );
      final avisados = await _avisar(
        publicada.id,
        solicitud.claveIdempotencia,
        traceId: traceId,
        tenantId: tenantId,
      );
      _log.info(
        'solicitud_creada',
        traceId: traceId,
        tenantId: tenantId,
        extra: {
          'event': _evento,
          'solicitud_id': publicada.id,
          'categoria_id': solicitud.categoria.id,
          'fotos': solicitud.fotos.length,
          'sitio_nuevo': ubicacion is NuevaDireccion,
          'aliados_avisados': avisados,
          'duracion_ms': sw.elapsedMilliseconds,
        },
      );
      return publicada.conAviso(avisados);
    } on SolicitudFailure catch (f) {
      _log.error(
        'solicitud_no_creada',
        traceId: traceId,
        tenantId: tenantId,
        extra: {
          'event': _evento,
          'error': f.tipo.name,
          'fotos': solicitud.fotos.length,
          'duracion_ms': sw.elapsedMilliseconds,
        },
      );
      rethrow;
    }
  }

  @override
  Future<void> avisarAliados(String solicitudId) =>
      _guard(() => _ds.avisarAliados(solicitudId, clave: nuevoUuid()));

  /// La solicitud ya existe en Core: si Dispatch no responde no se informa un
  /// error de publicación, solo que falta el aviso (el cliente lo reintenta).
  Future<bool> _avisar(
    String solicitudId,
    String clave, {
    required String traceId,
    String? tenantId,
  }) async {
    try {
      await _ds.avisarAliados(solicitudId, clave: clave);
      return true;
    } on Object catch (e) {
      _log.error(
        'aliados_no_avisados',
        traceId: traceId,
        tenantId: tenantId,
        extra: {
          'event': 'SCRUM-1402.orquestar_despacho',
          'solicitud_id': solicitudId,
          'error': e is GatewayException
              ? '${e.statusCode ?? 'sin respuesta'}'
              : e.runtimeType.toString(),
        },
      );
      return false;
    }
  }

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on GatewayException catch (e) {
      throw mapearGateway(e);
    } on PostgrestException catch (e) {
      throw mapearMensaje(e.message);
    } on AuthException catch (e) {
      throw SolicitudFailure(SolicitudErrorTipo.sinSesion, e.message);
    } on SolicitudFailure {
      rethrow;
    } catch (e) {
      final s = e.toString();
      if (s.contains('SocketException') ||
          s.contains('ClientException') ||
          s.contains('TimeoutException')) {
        throw SolicitudFailure(SolicitudErrorTipo.sinConexion, s);
      }
      throw SolicitudFailure(SolicitudErrorTipo.desconocido, s);
    }
  }

  /// Códigos de Core que la pantalla de solicitudes sabe explicar (SCRUM-1643).
  /// Cualquier otro código, o ninguno, se resuelve por el status HTTP.
  static const _tipoPorCodigo = <String, SolicitudErrorTipo>{
    'MANI-SOL-401': SolicitudErrorTipo.sinSesion,
    'MANI-SOL-403C': SolicitudErrorTipo.noEsCliente,
    'MANI-SOL-422C': SolicitudErrorTipo.categoriaInvalida,
    'MANI-SOL-422D': SolicitudErrorTipo.descripcionInvalida,
    'MANI-SOL-422F': SolicitudErrorTipo.fotosInvalidas,
    'MANI-SOL-422S': SolicitudErrorTipo.ubicacionInvalida,
    'MANI-SOL-422Z': SolicitudErrorTipo.zonaInvalida,
    // Contexto de plataforma (administrador que actúa en nombre de un tenant).
    'MANI-PLA-403': SolicitudErrorTipo.sinPermiso,
  };

  /// Traduce la respuesta de Core **por su código** `MANI-XXX-NNN`: es lo que
  /// decide el mensaje. El status HTTP solo se usa cuando el código no viene o
  /// no se conoce; así un 403 de otra causa ya no se muestra como «solo los
  /// clientes pueden publicar» (SCRUM-1643).
  static SolicitudFailure mapearGateway(GatewayException e) {
    final detalle = '${e.statusCode ?? 'sin respuesta'}: ${e.message}';
    final codigo = e.codigo;
    final referencia = e.referencia;

    final porCodigo = codigo == null ? null : _tipoPorCodigo[codigo];
    if (porCodigo != null) {
      return SolicitudFailure(porCodigo, detalle, codigo, referencia);
    }

    final tipo = switch (e.statusCode) {
      null => SolicitudErrorTipo.sinConexion,
      401 => SolicitudErrorTipo.sinSesion,
      403 => SolicitudErrorTipo.sinPermiso,
      413 => SolicitudErrorTipo.fotoMuyPesada,
      400 || 422 => mapearMensaje(e.message).tipo,
      _ => SolicitudErrorTipo.desconocido,
    };
    return SolicitudFailure(tipo, detalle, codigo, referencia);
  }

  /// Traduce el prefijo `MANI-SOL-*` de un mensaje (Core y RPC de la migración 006).
  static SolicitudFailure mapearMensaje(String mensaje) {
    for (final e in _tipoPorCodigo.entries) {
      if (mensaje.startsWith(e.key)) {
        return SolicitudFailure(e.value, mensaje);
      }
    }
    if (mensaje.contains('JWT') || mensaje.contains('permission denied')) {
      return SolicitudFailure(SolicitudErrorTipo.sinSesion, mensaje);
    }
    return SolicitudFailure(SolicitudErrorTipo.desconocido, mensaje);
  }
}
