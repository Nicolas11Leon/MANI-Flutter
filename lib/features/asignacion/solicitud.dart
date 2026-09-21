/// Modelo mínimo del flujo de asignación (RF-14).
///
/// Referencias: SRS_MANI.md RF-14, DD-MANI.md §7.1, ADR-0016.
/// Implementación provisional en memoria: el backend real (Supabase/PostgreSQL)
/// resuelve la exclusión con un UPDATE condicional atómico sobre `solicitud`.
library;

enum EstadoSolicitud { pendiente, asignada }

class Solicitud {
  const Solicitud({required this.id, required this.estado, this.aliadoId});

  const Solicitud.pendiente(this.id)
    : estado = EstadoSolicitud.pendiente,
      aliadoId = null;

  final String id;
  final EstadoSolicitud estado;
  final String? aliadoId;

  Solicitud asignadaA(String aliadoId) =>
      Solicitud(id: id, estado: EstadoSolicitud.asignada, aliadoId: aliadoId);
}

/// Equivalente a `409 { "error": "ya_no_disponible" }` (DD-MANI.md §7.1).
class SolicitudNoDisponible implements Exception {
  const SolicitudNoDisponible(this.solicitudId);
  final String solicitudId;

  @override
  String toString() => 'ya_no_disponible: $solicitudId';
}

/// Equivalente a `404 Not Found` (DD-MANI.md §7.1).
class SolicitudNoEncontrada implements Exception {
  const SolicitudNoEncontrada(this.solicitudId);
  final String solicitudId;

  @override
  String toString() => 'no_encontrada: $solicitudId';
}
