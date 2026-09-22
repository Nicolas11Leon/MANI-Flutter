import 'solicitud.dart';

/// Contrato del despacho de solicitudes (RF-14).
///
/// La implementación definitiva llamará a `POST /solicitudes/:id/aceptar`
/// (DD-MANI.md §5.4). Esta interfaz existe para que los casos de prueba no
/// cambien cuando se conecte el backend.
abstract class AsignacionRepository {
  Future<Solicitud> obtener(String solicitudId);

  /// Devuelve la solicitud asignada si este aliado ganó la carrera.
  ///
  /// Lanza [SolicitudNoDisponible] si otro aliado la tomó primero y
  /// [SolicitudNoEncontrada] si no existe para el tenant de la sesión.
  /// Es idempotente: si el mismo aliado reintenta tras un éxito previo,
  /// devuelve el mismo resultado en vez de fallar (DD-MANI.md §7.1).
  Future<Solicitud> aceptar(String solicitudId, String aliadoId);
}

/// Implementación en memoria que reproduce el UPDATE condicional del backend.
///
/// El `await` de [_latencia] es el punto de entrelazado: dos aceptaciones
/// concurrentes se suspenden ahí y luego compiten por el mismo estado, igual
/// que dos transacciones contra la misma fila.
class InMemoryAsignacionRepository implements AsignacionRepository {
  InMemoryAsignacionRepository({
    Iterable<Solicitud> solicitudes = const [],
    this.latencia = Duration.zero,
  }) {
    for (final s in solicitudes) {
      _solicitudes[s.id] = s;
    }
  }

  final Duration latencia;
  final Map<String, Solicitud> _solicitudes = {};

  @override
  Future<Solicitud> obtener(String solicitudId) async {
    final actual = _solicitudes[solicitudId];
    if (actual == null) throw SolicitudNoEncontrada(solicitudId);
    return actual;
  }

  @override
  Future<Solicitud> aceptar(String solicitudId, String aliadoId) async {
    await Future<void>.delayed(latencia);

    final actual = _solicitudes[solicitudId];
    if (actual == null) throw SolicitudNoEncontrada(solicitudId);

    // UPDATE solicitud SET aliado_id = ?, estado = 'assigned'
    //   WHERE id = ? AND estado = 'pending';
    if (actual.estado == EstadoSolicitud.asignada) {
      if (actual.aliadoId == aliadoId) return actual; // reintento idempotente
      throw SolicitudNoDisponible(solicitudId);
    }

    final asignada = actual.asignadaA(aliadoId);
    _solicitudes[solicitudId] = asignada;
    return asignada;
  }
}
