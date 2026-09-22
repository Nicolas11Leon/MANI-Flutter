import 'package:mani/features/asignacion/domain/entities/solicitud_entity.dart';

abstract class IAsignacionRepository {
  Future<SolicitudEntity> aceptar(String solicitudId, String aliadoId);
}

class SolicitudNoDisponible implements Exception {}
class SolicitudNoEncontrada implements Exception {}
