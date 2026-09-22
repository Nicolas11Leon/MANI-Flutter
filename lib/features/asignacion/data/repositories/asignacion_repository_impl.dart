import 'package:mani/features/asignacion/domain/entities/solicitud_entity.dart';
import 'package:mani/features/asignacion/domain/repositories/i_asignacion_repository.dart';

class AsignacionRepositoryImpl implements IAsignacionRepository {
  @override
  Future<SolicitudEntity> aceptar(String solicitudId, String aliadoId) async {
    // Dummy implementation
    return SolicitudEntity(id: solicitudId, aliadoId: aliadoId);
  }
}
