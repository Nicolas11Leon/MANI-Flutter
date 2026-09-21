import 'package:flutter_test/flutter_test.dart';
import 'package:mani/features/asignacion/asignacion_repository.dart';
import 'package:mani/features/asignacion/solicitud.dart';

void main() {
  const solicitudId = 'sol-001';

  InMemoryAsignacionRepository nuevoRepo() => InMemoryAsignacionRepository(
    solicitudes: const [Solicitud.pendiente(solicitudId)],
  );

  group('RF-14 · aceptación de solicitud', () {
    test('el primer aliado en aceptar se queda con la solicitud', () async {
      final repo = nuevoRepo();

      final resultado = await repo.aceptar(solicitudId, 'aliado-a');

      expect(resultado.estado, EstadoSolicitud.asignada);
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
      expect(reintento.estado, EstadoSolicitud.asignada);
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

        final asignaciones = resultados.whereType<Solicitud>().toList();
        final rechazos = resultados.whereType<SolicitudNoDisponible>().toList();

        expect(asignaciones, hasLength(1));
        expect(rechazos, hasLength(aliados.length - 1));

        final persistida = await repo.obtener(solicitudId);
        expect(persistida.aliadoId, asignaciones.single.aliadoId);
      },
    );
  });
}
