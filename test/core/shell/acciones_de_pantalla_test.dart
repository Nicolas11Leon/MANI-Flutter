import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';

AccionDePantalla _a(String etiqueta, List<String> toques) => AccionDePantalla(
  icono: Icons.history,
  etiqueta: etiqueta,
  alTocar: () => toques.add(etiqueta),
);

Widget _barra(List<AccionDePantalla> acciones) => MaterialApp(
  home: Scaffold(appBar: AppBar(actions: botonesDeAcciones(acciones))),
);

void main() {
  testWidgets('una acción se ve como un botón de icono con su etiqueta', (
    tester,
  ) async {
    final toques = <String>[];
    await tester.pumpWidget(_barra([_a('Historial', toques)]));
    expect(find.byTooltip('Historial'), findsOneWidget);
    await tester.tap(find.byTooltip('Historial'));
    expect(toques, ['Historial']);
  });

  testWidgets('tres acciones van bajo «⋮» con icono y texto', (tester) async {
    final toques = <String>[];
    await tester.pumpWidget(
      _barra([
        _a('Mis zonas', toques),
        _a('Mis especialidades', toques),
        _a('Historial', toques),
      ]),
    );
    expect(find.byTooltip('Más opciones'), findsOneWidget);
    expect(find.text('Mis zonas'), findsNothing);
    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    expect(find.text('Mis especialidades'), findsOneWidget);
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(toques, ['Historial']);
  });

  test('sin acciones no hay botones', () {
    expect(botonesDeAcciones(const []), isEmpty);
  });

  testWidgets('una pantalla oculta no deja sus acciones en la barra', (
    tester,
  ) async {
    final titulos = TitulosDePantalla();
    Widget pantalla(bool visible) => MaterialApp(
      home: TickerMode(
        enabled: visible,
        child: TituloDePantalla(
          titulo: 'Solicitudes',
          titulos: titulos,
          acciones: [_a('Historial', [])],
        ),
      ),
    );
    await tester.pumpWidget(pantalla(true));
    await tester.pump();
    expect(titulos.acciones.length, 1);

    await tester.pumpWidget(pantalla(false));
    await tester.pump();
    expect(titulos.acciones, isEmpty);
    expect(titulos.actual, isNull);
  });
}
