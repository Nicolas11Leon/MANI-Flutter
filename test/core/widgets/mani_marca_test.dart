import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/widgets/mani_esqueleto.dart';
import 'package:mani/core/widgets/mani_estados.dart';
import 'package:mani/core/widgets/mani_personaje.dart';

Widget _en(Widget hijo, {double ancho = 360, bool sinAnimar = false}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(ancho, 640),
          disableAnimations: sinAnimar,
        ),
        child: Scaffold(body: SingleChildScrollView(child: hijo)),
      ),
    );

void main() {
  group('ManiPersonaje', () {
    testWidgets('una pose sin archivo lleva insignia', (tester) async {
      await tester.pumpWidget(
        _en(const ManiPersonaje(pose: PoseMani.ups), sinAnimar: true),
      );
      expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
    });

    testWidgets('la pose declarada como disponible no lleva insignia', (
      tester,
    ) async {
      await tester.pumpWidget(
        _en(const ManiPersonaje(pose: PoseMani.saludo), sinAnimar: true),
      );
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('con reducir movimiento no anima', (tester) async {
      await tester.pumpWidget(_en(const ManiPersonaje(), sinAnimar: true));
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });
  });

  group('Estados', () {
    testWidgets('el vacío muestra título, texto y acción', (tester) async {
      await tester.pumpWidget(
        _en(
          const ManiEstadoVacio(
            titulo: 'Aún no tienes pedidos',
            texto: 'Cuéntanos qué necesitas.',
            accion: Text('Pedir un servicio'),
          ),
          sinAnimar: true,
        ),
      );
      expect(find.text('Aún no tienes pedidos'), findsOneWidget);
      expect(find.text('Cuéntanos qué necesitas.'), findsOneWidget);
      expect(find.text('Pedir un servicio'), findsOneWidget);
    });

    testWidgets('el error llama a alReintentar', (tester) async {
      var veces = 0;
      await tester.pumpWidget(
        _en(
          ManiEstadoError(texto: 'Falló', alReintentar: () => veces++),
          sinAnimar: true,
        ),
      );
      expect(find.text('Algo no salió bien'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(veces, 1);
    });

    testWidgets('sin conexión cambia el título y el texto', (tester) async {
      await tester.pumpWidget(
        _en(
          ManiEstadoError(texto: 'x', alReintentar: () {}, sinConexion: true),
          sinAnimar: true,
        ),
      );
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(
        find.text('Revisa tu internet y vuelve a intentar.'),
        findsOneWidget,
      );
    });

    testWidgets('la forma compacta no desborda a 320 px', (tester) async {
      await tester.pumpWidget(
        _en(
          const ManiEstadoVacio(
            titulo: 'Sin avisos',
            texto: 'No tienes avisos nuevos por ahora, vuelve más tarde.',
            compacto: true,
            pose: PoseMani.descansando,
          ),
          ancho: 320,
          sinAnimar: true,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('el esqueleto se construye sin desbordar', (tester) async {
    await tester.pumpWidget(_en(ManiEsqueleto.lista(), sinAnimar: true));
    expect(find.byType(ManiEsqueleto), findsOneWidget);
    await tester.pumpWidget(_en(ManiEsqueleto.detalle(), sinAnimar: true));
    await tester.pumpWidget(_en(ManiEsqueleto.tarjetas(), sinAnimar: true));
    expect(tester.takeException(), isNull);
  });
}
