import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/app_shell.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';

class _FuenteFija implements FuenteDatosSesion {
  @override
  Future<DatosSesion> cargar() async => const DatosSesion(
    nombreUsuario: 'Ana Pérez',
    nombreTenant: 'Plomería Express',
  );
}

/// Una pantalla como las de la app: su propio andamio y su título.
class _Pantalla extends StatelessWidget {
  const _Pantalla(this.titulo);
  final String titulo;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: barraDePantalla(context, titulo: titulo),
    body: const Text('contenido'),
  );
}

Future<void> _montar(
  WidgetTester tester, {
  required double ancho,
  required Widget child,
  String ubicacion = '/perfil/avisos',
  RolUsuario rol = RolUsuario.cliente,
  bool Function()? puedeVolver,
}) async {
  tester.view.physicalSize = Size(ancho, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AppShell(
        rol: rol,
        ubicacion: ubicacion,
        fuenteDatos: _FuenteFija(),
        onNavegar: (_) {},
        onCerrarSesion: () async {},
        puedeVolver: puedeVolver,
        onVolver: () {},
        child: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SCRUM-1647 — una sola barra superior en celular', () {
    testWidgets('en celular la pantalla no dibuja barra: el título va en la '
        'del armazón', (tester) async {
      await _montar(tester, ancho: 360, child: const _Pantalla('Avisos'));

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Avisos'), findsOneWidget);
      final titulo = tester.widget<Text>(
        find.byKey(const Key('menu-titulo-seccion')),
      );
      expect(titulo.data, 'Avisos');
      expect(find.byKey(const Key('menu-atras')), findsOneWidget);
    });

    testWidgets('el título de la pantalla le gana al de la sección', (
      tester,
    ) async {
      await _montar(
        tester,
        ancho: 360,
        ubicacion: '/cliente/solicitudes/abc/chat',
        child: const _Pantalla('Mensajes del servicio'),
      );
      final titulo = tester.widget<Text>(
        find.byKey(const Key('menu-titulo-seccion')),
      );
      expect(titulo.data, 'Mensajes del servicio');
    });

    testWidgets(
      'una pantalla principal muestra su título sin flecha de volver',
      (tester) async {
        await _montar(
          tester,
          ancho: 360,
          rol: RolUsuario.aliado,
          ubicacion: '/aliado/cobros',
          child: const _Pantalla('Mis cobros'),
        );
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text('Mis cobros'), findsOneWidget);
        expect(find.byKey(const Key('menu-atras')), findsNothing);
      },
    );

    testWidgets(
      'con otra pantalla abierta encima, la principal sí ofrece volver',
      (tester) async {
        await _montar(
          tester,
          ancho: 360,
          rol: RolUsuario.aliado,
          ubicacion: '/aliado/cobros',
          puedeVolver: () => true,
          child: const _Pantalla('Detalle'),
        );
        expect(find.byKey(const Key('menu-atras')), findsOneWidget);
      },
    );

    testWidgets(
      'al cerrarse la pantalla, la barra vuelve al título de la sección',
      (tester) async {
        await _montar(
          tester,
          ancho: 360,
          child: const _Pantalla('Otro título'),
        );
        await _montar(
          tester,
          ancho: 360,
          child: const Text('sin título propio'),
        );
        expect(find.text('Otro título'), findsNothing);
        expect(titulosDePantalla.actual, isNull);
      },
    );

    testWidgets('una pantalla tapada u oculta no impone su título', (
      tester,
    ) async {
      final titulos = TitulosDePantalla();
      Widget arbol({required bool seVe}) => MaterialApp(
        home: TickerMode(
          enabled: seVe,
          child: TituloDePantalla(titulo: 'Bandeja', titulos: titulos),
        ),
      );
      await tester.pumpWidget(arbol(seVe: true));
      expect(titulos.actual, 'Bandeja');
      await tester.pumpWidget(arbol(seVe: false));
      expect(titulos.actual, isNull);
      await tester.pumpWidget(arbol(seVe: true));
      expect(titulos.actual, 'Bandeja');
    });

    testWidgets('manda el título de la última pantalla abierta', (
      tester,
    ) async {
      final titulos = TitulosDePantalla();
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              TituloDePantalla(titulo: 'Lista', titulos: titulos),
              TituloDePantalla(titulo: 'Detalle', titulos: titulos),
            ],
          ),
        ),
      );
      expect(titulos.actual, 'Detalle');
    });

    testWidgets('en escritorio la pantalla conserva su barra con el título', (
      tester,
    ) async {
      await _montar(tester, ancho: 1280, child: const _Pantalla('Avisos'));
      expect(find.byType(AppBar), findsNWidgets(2));
      expect(find.text('Avisos'), findsWidgets);
      expect(find.byKey(const Key('menu-titulo-seccion')), findsNothing);
    });

    testWidgets('fuera del armazón la pantalla lleva su barra de siempre', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: _Pantalla('Avisos')));
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Avisos'), findsOneWidget);
    });
  });
}
