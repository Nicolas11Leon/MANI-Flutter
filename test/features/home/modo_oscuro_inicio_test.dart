import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/shell/navegacion_movil.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/features/home/data/resumen_inicio.dart';
import 'package:mani/features/home/presentation/pages/inicio_page.dart';
import 'package:mani/features/home/presentation/widgets/saludo_inicio.dart';

/// El inicio del celular y la barra inferior siguen el tema: en modo oscuro el texto no se queda con el color del
/// modo claro (texto oscuro sobre tarjeta oscura, casi ilegible) y los fondos tampoco.

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

Future<void> _montarInicio(WidgetTester tester, ThemeData tema) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: tema,
      home: InicioPage(
        rol: RolUsuario.cliente,
        fuenteSesion: _Sesion(),
        fuenteResumen: _Resumen(),
        onNavegar: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _montarBarra(WidgetTester tester, ThemeData tema) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: tema,
      home: Scaffold(
        bottomNavigationBar: BarraInferiorMovil(
          navegacion: navegacionCliente,
          ubicacion: '/inicio',
          seccion: null,
          onNavegar: (_) {},
        ),
      ),
    ),
  );
}

Color? _colorDelTexto(WidgetTester tester, String texto) =>
    tester.widget<Text>(find.text(texto).first).style?.color;

void main() {
  group('Inicio del celular', () {
    testWidgets(
      'modo oscuro: el texto usa la tinta clara y el saludo la tinta de marca',
      (tester) async {
        await _montarInicio(tester, AppTheme.dark);

        expect(
          _colorDelTexto(tester, 'Sedes registradas'),
          ManiDarkColors.inkMuted,
        );
        // El saludo va sobre la tarjeta de marca, que es clara en los dos modos: su texto es oscuro en los dos.
        expect(_colorDelTexto(tester, 'Ana Pérez'), ManiDarkColors.onBrand);
        expect(
          _colorDelTexto(tester, '¿Qué arreglamos hoy?'),
          ManiDarkColors.onBrand,
        );
      },
    );

    testWidgets('modo claro: sigue como antes', (tester) async {
      await _montarInicio(tester, AppTheme.light);

      expect(_colorDelTexto(tester, 'Sedes registradas'), ManiColors.inkMuted);
      expect(_colorDelTexto(tester, 'Ana Pérez'), ManiColors.onBrand);
    });

    testWidgets(
      'modo oscuro: ningún texto del inicio conserva la tinta del modo claro sobre fondo oscuro',
      (tester) async {
        await _montarInicio(tester, AppTheme.dark);

        final tintaClara = ManiColors.ink;
        final oscuros = <String>[];
        for (final texto in tester.widgetList<Text>(find.byType(Text))) {
          final color = texto.style?.color;
          final etiqueta = texto.data ?? texto.textSpan?.toPlainText() ?? '';
          // El saludo es la excepción: va sobre la tarjeta de marca y su texto es oscuro a propósito.
          if (color == tintaClara &&
              etiqueta != 'Ana Pérez' &&
              etiqueta != '¿Qué arreglamos hoy?' &&
              !etiqueta.startsWith('BUEN')) {
            oscuros.add(etiqueta);
          }
        }
        expect(
          oscuros,
          isEmpty,
          reason: 'textos con la tinta del modo claro: $oscuros',
        );
      },
    );
  });

  group('Barra inferior del celular', () {
    testWidgets('modo oscuro: fondo oscuro y etiquetas claras', (tester) async {
      await _montarBarra(tester, AppTheme.dark);

      final fondo = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(const Key('barra-inferior')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((fondo.decoration as BoxDecoration).color, ManiDarkColors.surface);
      expect(_colorDelTexto(tester, 'Servicios'), ManiDarkColors.ink);
      expect(_colorDelTexto(tester, 'Perfil'), ManiDarkColors.ink);
    });

    testWidgets('modo claro: fondo claro y etiquetas oscuras', (tester) async {
      await _montarBarra(tester, AppTheme.light);

      final fondo = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(const Key('barra-inferior')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((fondo.decoration as BoxDecoration).color, ManiColors.surface);
      expect(_colorDelTexto(tester, 'Perfil'), ManiColors.ink);
    });
  });

  group('Botón del saludo', () {
    Future<Color?> relleno(WidgetTester tester, ThemeData tema) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: tema,
          home: Scaffold(
            body: SaludoInicio(
              sesion: Future.value(const DatosSesion(nombreUsuario: 'Ana')),
              subtitulo: '¿Qué arreglamos hoy?',
              accion: accionSaludoPara(RolUsuario.cliente),
              onNavegar: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fondo = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byKey(const Key('inicio-saludo-accion')),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      return (fondo.decoration as BoxDecoration).color;
    }

    testWidgets('modo claro: relleno oscuro sobre la tarjeta de marca', (
      tester,
    ) async {
      final color = await relleno(tester, AppTheme.light);

      expect(color, ManiColors.onBrand);
      expect(color!.computeLuminance(), lessThan(0.2));
    });

    testWidgets(
      'modo oscuro: sigue siendo oscuro y no se funde con el amarillo',
      (tester) async {
        final color = await relleno(tester, AppTheme.dark);

        expect(color, ManiDarkColors.onBrand);
        expect(color!.computeLuminance(), lessThan(0.2));
      },
    );
  });
}
