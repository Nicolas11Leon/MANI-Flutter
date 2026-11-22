import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/features/home/data/resumen_inicio.dart';
import 'package:mani/features/home/presentation/pages/inicio_page.dart';

class _Sesion implements FuenteDatosSesion {
  @override
  Future<DatosSesion> cargar() async =>
      const DatosSesion(nombreUsuario: 'Ana Pérez', nombreTenant: 'Tenant A');
}

class _Resumen implements FuenteResumenInicio {
  @override
  Future<List<IndicadorResumen>> cargar(RolUsuario rol) async => const [
    IndicadorResumen(
      etiqueta: 'Sedes registradas',
      ruta: '/cliente/sedes',
      valor: '2',
    ),
  ];
}

Future<void> _montar(
  WidgetTester tester, {
  double ancho = 390,
  ValueChanged<String>? onNavegar,
  RolUsuario rol = RolUsuario.cliente,
}) async {
  tester.view.physicalSize = Size(ancho, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: InicioPage(
        rol: rol,
        fuenteSesion: _Sesion(),
        fuenteResumen: _Resumen(),
        onNavegar: onNavegar ?? (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SCRUM-1647 — inicio del celular por módulos', () {
    testWidgets(
      'muestra el saludo, el resumen y los módulos Servicios y Tu cuenta',
      (tester) async {
        await _montar(tester);

        expect(find.byKey(const Key('inicio-movil')), findsOneWidget);
        expect(find.text('Ana Pérez'), findsOneWidget);
        expect(
          find.byKey(const Key('inicio-indicador-Sedes registradas')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('modulo-servicios')), findsOneWidget);
        expect(find.byKey(const Key('modulo-cuenta')), findsOneWidget);
        // Los avisos tienen su campana arriba: el inicio no los repite.
        expect(find.byKey(const Key('modulo-avisos')), findsNothing);
        // El inicio de celular no repite la lista completa de accesos ni la tarjeta de cerrar sesión.
        expect(find.text('Accesos Rápidos'), findsNothing);
        expect(find.byKey(const Key('inicio-card-sesion')), findsNothing);
      },
    );

    testWidgets('en un celular de 390×800 todo cabe sin deslizar', (
      tester,
    ) async {
      await _montar(tester);
      tester.view.physicalSize = const Size(390, 800);
      await tester.pumpAndSettle();

      final lista = tester.getRect(find.byKey(const Key('inicio-movil')));
      final ultimo = tester.getRect(
        find.byKey(const Key('modulo-cuenta-ver-todos')),
      );
      expect(ultimo.bottom, lessThanOrEqualTo(lista.bottom));
    });

    testWidgets('los atajos de Servicios son lo más usado del rol y navegan', (
      tester,
    ) async {
      String? destino;
      await _montar(tester, onNavegar: (r) => destino = r);

      expect(
        find.byKey(const Key('inicio-acceso-/cliente/solicitudes/nueva')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('inicio-acceso-/cliente/solicitudes')),
        findsOneWidget,
      );
      // Lo demás vive en Servicios, no en el inicio.
      expect(
        find.byKey(const Key('inicio-acceso-/cliente/historial')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('inicio-acceso-/cliente/solicitudes/nueva')),
      );
      expect(destino, '/cliente/solicitudes/nueva');
    });

    testWidgets('«Ver todos» de cada módulo lleva a su pantalla', (
      tester,
    ) async {
      final destinos = <String>[];
      await _montar(tester, onNavegar: destinos.add);

      await tester.tap(find.byKey(const Key('modulo-servicios-ver-todos')));
      await tester.ensureVisible(
        find.byKey(const Key('modulo-cuenta-ver-todos')),
      );
      await tester.tap(find.byKey(const Key('modulo-cuenta-ver-todos')));

      expect(destinos, ['/servicios', '/cuenta']);
    });

    testWidgets('en escritorio el inicio conserva su diseño de siempre', (
      tester,
    ) async {
      await _montar(tester, ancho: 1200);
      expect(find.byKey(const Key('inicio-movil')), findsNothing);
      expect(find.text('Accesos Rápidos'), findsOneWidget);
    });
  });
}
