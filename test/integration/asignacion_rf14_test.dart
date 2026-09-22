import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/features/asignacion/presentation/pages/aceptar_solicitud_page.dart';
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

  Widget appPara(IAsignacionRepository repo, String aliadoId) => MaterialApp(
    home: AceptarSolicitudPage(
      repository: repo,
      solicitudId: solicitudId,
      aliadoId: aliadoId,
    ),
  );

  testWidgets(
    'una solicitud se asigna a un único aliado y el resto ve ya_no_disponible',
    (tester) async {
      final repo = InMemoryAsignacionRepository(
        solicitudes: [const SolicitudEntity(id: solicitudId, aliadoId: null)],
      );

      // Aliado A acepta primero.
      await tester.pumpWidget(appPara(repo, 'aliado-a'));
      expect(find.text('Solicitud pendiente'), findsOneWidget);

      await tester.tap(find.text('Aceptar solicitud'));
      await tester.pumpAndSettle();

      expect(find.text('Asignada a aliado-a'), findsOneWidget);

      // Aliado B intenta aceptar la misma solicitud.
      await tester.pumpWidget(appPara(repo, 'aliado-b'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aceptar solicitud'));
      await tester.pumpAndSettle();

      expect(find.text('Ya no disponible'), findsOneWidget);
      expect(find.text('Asignada a aliado-b'), findsNothing);

      // La asignación persistida sigue siendo la del primer aliado.
      final persistida = await repo.obtener(solicitudId);
      expect(persistida.aliadoId, 'aliado-a');
    },
  );
}
