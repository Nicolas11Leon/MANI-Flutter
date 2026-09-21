import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/features/asignacion/aceptar_solicitud_page.dart';
import 'package:mani/features/asignacion/asignacion_repository.dart';
import 'package:mani/features/asignacion/solicitud.dart';

/// Prueba de integración del flujo de asignación (RF-14).
///
/// Recorre la interfaz completa: dos aliados abren la misma solicitud, el
/// primero la acepta y el segundo debe ver "Ya no disponible".
///
/// Vive en `test/integration/` y no en `integration_test/` a propósito:
/// `flutter test integration_test` exige un dispositivo conectado, lo que no
/// existe en un runner de CI. Aquí se ejecuta headless con el flutter tester,
/// cubriendo el mismo recorrido de interfaz (CFG-06 / SCRUM-955).
void main() {
  const solicitudId = 'sol-001';

  Widget appPara(AsignacionRepository repo, String aliadoId) => MaterialApp(
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
        solicitudes: const [Solicitud.pendiente(solicitudId)],
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
      expect(persistida.estado, EstadoSolicitud.asignada);
    },
  );
}
