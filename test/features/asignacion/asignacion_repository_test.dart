import 'package:flutter_test/flutter_test.dart';
import 'package:mani/features/asignacion/domain/repositories/i_asignacion_repository.dart';
import 'package:mani/features/asignacion/domain/entities/solicitud_entity.dart';

class InMemoryAsignacionRepository implements IAsignacionRepository {
  List<SolicitudEntity> solicitudes;

  InMemoryAsignacionRepository({required this.solicitudes});

  @override
  Future<SolicitudEntity> aceptar(String solicitudId, String aliadoId) async {
    final index = solicitudes.indexWhere((s) => s.id == solicitudId);
    if (index == -1) throw SolicitudNoEncontrada();
    final solicitud = solicitudes[index];
    if (solicitud.aliadoId != null && solicitud.aliadoId != aliadoId) {
      throw SolicitudNoDisponible();
    }
    final nuevaSolicitud = SolicitudEntity(id: solicitudId, aliadoId: aliadoId);
    solicitudes[index] = nuevaSolicitud;
    return nuevaSolicitud;
  }

  Future<SolicitudEntity> obtener(String solicitudId) async {
    final s = solicitudes.firstWhere((s) => s.id == solicitudId);
    return s;
  }
}

void main() {
  const solicitudId = 'sol-001';

  InMemoryAsignacionRepository nuevoRepo() => InMemoryAsignacionRepository(
    solicitudes: [const SolicitudEntity(id: solicitudId, aliadoId: null)],
  );

  group('RF-14 · aceptación de solicitud', () {
    test('el primer aliado en aceptar se queda con la solicitud', () async {
      final repo = nuevoRepo();
      final resultado = await repo.aceptar(solicitudId, 'aliado-a');
      expect(resultado.aliadoId, 'aliado-a');
    });

    test('un segundo aliado recibe ya_no_disponible', () async {
      final repo = nuevoRepo();
      await repo.aceptar(solicitudId, 'aliado-a');
      expect(
        () => repo.aceptar(solicitudId, 'aliado-b'),
        throwsA(isA<SolicitudNoDisponible>()),
      );
    });

    test('el reintento del mismo aliado es idempotente', () async {
      final repo = nuevoRepo();
      final primera = await repo.aceptar(solicitudId, 'aliado-a');
      final reintento = await repo.aceptar(solicitudId, 'aliado-a');
      expect(reintento.aliadoId, primera.aliadoId);
    });

    test('una solicitud inexistente no se puede aceptar', () async {
      final repo = nuevoRepo();
      expect(
        () => repo.aceptar('sol-inexistente', 'aliado-a'),
        throwsA(isA<SolicitudNoEncontrada>()),
      );
    });
  });

  group('RNF-05 · exclusión concurrente', () {
    test(
      'cinco aceptaciones simultáneas producen exactamente una asignación',
      () async {
        final repo = nuevoRepo();
        final aliados = ['a', 'b', 'c', 'd', 'e'];

        final resultados = await Future.wait(
          aliados.map(
            (aliado) => repo
                .aceptar(solicitudId, aliado)
                .then<Object>((s) => s)
                .catchError((Object e) => e),
          ),
        );

        final asignaciones = resultados.whereType<SolicitudEntity>().toList();
        final rechazos = resultados.whereType<SolicitudNoDisponible>().toList();

        expect(asignaciones, hasLength(1));
        expect(rechazos, hasLength(aliados.length - 1));

        final persistida = await repo.obtener(solicitudId);
        expect(persistida.aliadoId, asignaciones.single.aliadoId);
      },
    );
  });
}
