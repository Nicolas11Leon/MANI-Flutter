import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/widgets/mani_personaje.dart';
import 'package:mani/features/home/presentation/widgets/saludo_inicio.dart';

Widget _saludo(
  RolUsuario rol,
  List<String> rutas, {
  DateTime? hora,
  double ancho = 360,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: Size(ancho, 800), disableAnimations: true),
    child: Scaffold(
      body: SingleChildScrollView(
        child: SaludoInicio(
          sesion: Future.value(const DatosSesion(nombreUsuario: 'Ana Pérez')),
          subtitulo: '¿Qué arreglamos hoy?',
          accion: accionSaludoPara(rol),
          onNavegar: rutas.add,
          reloj: () => hora ?? DateTime(2026, 11, 16, 9),
        ),
      ),
    ),
  ),
);

void main() {
  test('el antetítulo cambia con la hora', () {
    expect(antetituloPorHora(DateTime(2026, 1, 1, 8)), 'BUENOS DÍAS');
    expect(antetituloPorHora(DateTime(2026, 1, 1, 15)), 'BUENAS TARDES');
    expect(antetituloPorHora(DateTime(2026, 1, 1, 21)), 'BUENAS NOCHES');
  });

  test('cada rol tiene su acción y el rol desconocido no tiene', () {
    expect(
      accionSaludoPara(RolUsuario.cliente)!.ruta,
      '/cliente/solicitudes/nueva',
    );
    expect(accionSaludoPara(RolUsuario.aliado)!.ruta, '/aliado/solicitudes');
    expect(accionSaludoPara(RolUsuario.desconocido), isNull);
  });

  testWidgets('muestra nombre, subtítulo y un solo muñequito', (tester) async {
    await tester.pumpWidget(_saludo(RolUsuario.cliente, []));
    await tester.pump();
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('¿Qué arreglamos hoy?'), findsOneWidget);
    expect(find.text('BUENOS DÍAS'), findsOneWidget);
    expect(find.byType(ManiPersonaje), findsOneWidget);
  });

  testWidgets('el botón lleva a la ruta del rol', (tester) async {
    final rutas = <String>[];
    await tester.pumpWidget(_saludo(RolUsuario.aliado, rutas));
    await tester.pump();
    await tester.tap(find.byKey(const Key('inicio-saludo-accion')));
    expect(rutas, ['/aliado/solicitudes']);
  });

  testWidgets('sin rol no hay botón y en web no desborda', (tester) async {
    await tester.pumpWidget(_saludo(RolUsuario.desconocido, [], ancho: 1000));
    await tester.pump();
    expect(find.byKey(const Key('inicio-saludo-accion')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
