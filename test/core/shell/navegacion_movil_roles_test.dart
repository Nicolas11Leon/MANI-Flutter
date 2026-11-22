import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/app_shell.dart';
import 'package:mani/core/shell/datos_sesion.dart';
import 'package:mani/core/shell/navegacion_movil.dart';
import 'package:mani/core/shell/sin_deslizar_menus.dart';
import 'package:mani/features/home/presentation/pages/seccion_menu_page.dart';

class _Sesion implements FuenteDatosSesion {
  @override
  Future<DatosSesion> cargar() async =>
      const DatosSesion(nombreUsuario: 'Ana Pérez', nombreTenant: 'Tenant A');
}

Future<void> _montar(
  WidgetTester tester, {
  required RolUsuario rol,
  required String ubicacion,
  double ancho = 390,
  ValueChanged<String>? onNavegar,
  Widget child = const Text('contenido de la pantalla'),
}) async {
  tester.view.physicalSize = Size(ancho, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AppShell(
        rol: rol,
        ubicacion: ubicacion,
        fuenteDatos: _Sesion(),
        onNavegar: onNavegar ?? (_) {},
        onCerrarSesion: () async {},
        child: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  /// Rutas de los cinco destinos, de izquierda a derecha, y su etiqueta.
  const aliado = [
    '/aliado/solicitudes',
    '/aliado/cobros',
    '/inicio',
    '/servicios',
    '/cuenta',
  ];
  const admin = [
    '/admin/verificacion-aliados',
    '/admin/quejas',
    '/inicio',
    '/servicios',
    '/cuenta',
  ];

  double x(WidgetTester tester, String ruta) =>
      tester.getCenter(find.byKey(Key('menu-entrada-$ruta'))).dx;

  Future<List<bool>> marcas(
    WidgetTester tester,
    RolUsuario rol,
    String ubicacion,
    List<String> destinos,
  ) async {
    await _montar(tester, rol: rol, ubicacion: ubicacion);
    return [
      for (final r in destinos)
        tester
                .getSemantics(find.byKey(Key('menu-entrada-$r')))
                .flagsCollection
                .isSelected ==
            Tristate.isTrue,
    ];
  }

  group('SCRUM-1647 — navegación móvil del aliado', () {
    testWidgets('cinco destinos con Inicio al centro y la campana arriba', (
      tester,
    ) async {
      await _montar(tester, rol: RolUsuario.aliado, ubicacion: '/inicio');

      for (final r in aliado) {
        expect(find.byKey(Key('menu-entrada-$r')), findsOneWidget, reason: r);
      }
      final orden = [for (final r in aliado) x(tester, r)];
      expect([...orden]..sort(), orden);
      expect(x(tester, '/inicio'), closeTo(390 / 2, 1));
      expect(find.byKey(const Key('menu-avisos')), findsOneWidget);
      expect(
        find.byKey(const Key('menu-entrada-/perfil/avisos')),
        findsNothing,
      );
      expect(find.byKey(const Key('menu-cerrar-sesion')), findsNothing);
    });

    testWidgets('el destino activo sigue a la pantalla', (tester) async {
      // Solicitudes, Cobros, Inicio, Servicios, Perfil
      Future<List<bool>> m(String u) =>
          marcas(tester, RolUsuario.aliado, u, aliado);
      expect(await m('/aliado/solicitudes'), [
        true,
        false,
        false,
        false,
        false,
      ]);
      expect(await m('/aliado/solicitudes/123/cotizacion'), [
        true,
        false,
        false,
        false,
        false,
      ]);
      expect(await m('/aliado/cobros'), [false, true, false, false, false]);
      expect(await m('/inicio'), [false, false, true, false, false]);
      expect(await m('/servicios'), [false, false, false, true, false]);
      expect(await m('/aliado/historial'), [false, false, false, true, false]);
      expect(await m('/cuenta'), [false, false, false, false, true]);
      expect(await m('/aliado/disponibilidad'), [
        false,
        false,
        false,
        false,
        true,
      ]);
    });

    testWidgets(
      'volver: una opción regresa a su sección y una sección, al inicio',
      (tester) async {
        final destinos = <String>[];
        Future<void> volverDesde(String ubicacion) async {
          destinos.clear();
          await _montar(
            tester,
            rol: RolUsuario.aliado,
            ubicacion: ubicacion,
            onNavegar: destinos.add,
          );
          await tester.tap(find.byKey(const Key('menu-atras')));
          await tester.pumpAndSettle();
        }

        await volverDesde('/aliado/historial');
        expect(destinos, ['/servicios']);
        await volverDesde('/aliado/cobertura');
        expect(destinos, ['/cuenta']);
        await volverDesde('/aliado/solicitudes/123/cotizacion');
        expect(destinos, ['/aliado/solicitudes']);

        for (final raiz in const ['/aliado/solicitudes', '/aliado/cobros']) {
          await _montar(tester, rol: RolUsuario.aliado, ubicacion: raiz);
          expect(
            find.byKey(const Key('menu-atras')),
            findsNothing,
            reason: raiz,
          );
        }
      },
    );

    testWidgets(
      'la cobertura es un flujo: sin barra de menú y la flecha sale a Perfil',
      (tester) async {
        String? destino;
        await _montar(
          tester,
          rol: RolUsuario.aliado,
          ubicacion: '/aliado/cobertura',
          onNavegar: (r) => destino = r,
        );

        // Esa pantalla trae su propio resumen abajo: una sola barra, no dos apiladas.
        expect(find.byKey(const Key('barra-inferior')), findsNothing);
        expect(find.byKey(const Key('deslizar-menus')), findsNothing);
        await tester.tap(find.byKey(const Key('menu-atras')));
        await tester.pumpAndSettle();
        expect(destino, '/cuenta');
      },
    );

    testWidgets('deslizar recorre los cinco menús en el orden de la barra', (
      tester,
    ) async {
      final destinos = <String>[];
      await _montar(
        tester,
        rol: RolUsuario.aliado,
        ubicacion: '/inicio',
        onNavegar: destinos.add,
      );
      await tester.fling(
        find.byKey(const Key('deslizar-menus')),
        const Offset(-300, 0),
        1500,
      );
      await tester.pumpAndSettle();
      await tester.fling(
        find.byKey(const Key('deslizar-menus')),
        const Offset(300, 0),
        1500,
      );
      await tester.pumpAndSettle();
      expect(destinos, ['/servicios', '/aliado/cobros']);
    });

    group('el gesto de deslizar entre menús', () {
      testWidgets('un arrastre en diagonal no cambia de menú', (tester) async {
        final destinos = <String>[];
        await _montar(
          tester,
          rol: RolUsuario.aliado,
          ubicacion: '/inicio',
          onNavegar: destinos.add,
        );
        await tester.fling(
          find.byKey(const Key('deslizar-menus')),
          const Offset(-200, 180),
          1500,
        );
        await tester.pumpAndSettle();
        expect(destinos, isEmpty);
      });

      testWidgets('un arrastre corto no cambia de menú', (tester) async {
        final destinos = <String>[];
        await _montar(
          tester,
          rol: RolUsuario.aliado,
          ubicacion: '/inicio',
          onNavegar: destinos.add,
        );
        await tester.fling(
          find.byKey(const Key('deslizar-menus')),
          const Offset(-40, 0),
          1500,
        );
        await tester.pumpAndSettle();
        expect(destinos, isEmpty);
      });

      testWidgets('uno que empieza a 10 px del borde no cambia de menú', (
        tester,
      ) async {
        final destinos = <String>[];
        await _montar(
          tester,
          rol: RolUsuario.aliado,
          ubicacion: '/inicio',
          onNavegar: destinos.add,
        );
        await tester.flingFrom(
          const Offset(10, 300),
          const Offset(300, 0),
          1500,
        );
        await tester.pumpAndSettle();
        expect(destinos, isEmpty);
      });

      testWidgets('dentro de SinDeslizarMenus no cambia de menú', (
        tester,
      ) async {
        final destinos = <String>[];
        await _montar(
          tester,
          rol: RolUsuario.aliado,
          ubicacion: '/inicio',
          onNavegar: destinos.add,
          child: const SinDeslizarMenus(
            child: SizedBox(
              key: Key('zona-sin-deslizar'),
              width: 300,
              height: 300,
            ),
          ),
        );
        await tester.fling(
          find.byKey(const Key('zona-sin-deslizar')),
          const Offset(-200, 0),
          1500,
        );
        await tester.pumpAndSettle();
        expect(destinos, isEmpty);
      });
    });

    test('los vecinos y los extremos', () {
      String? v(String u, bool adelante) => menuVecinoAlDeslizar(
        u,
        haciaAdelante: adelante,
        rol: RolUsuario.aliado,
      );
      expect(v('/aliado/solicitudes', true), '/aliado/cobros');
      expect(v('/aliado/solicitudes', false), isNull);
      expect(v('/inicio', false), '/aliado/cobros');
      expect(v('/inicio', true), '/servicios');
      expect(v('/cuenta', true), isNull);
      expect(v('/aliado/historial', true), isNull);
    });
  });

  group('SCRUM-1647 — navegación móvil del administrador', () {
    testWidgets(
      'cinco destinos con Inicio al centro y «Gestión» en lugar de Servicios',
      (tester) async {
        await _montar(
          tester,
          rol: RolUsuario.adminTenant,
          ubicacion: '/inicio',
        );

        for (final r in admin) {
          expect(find.byKey(Key('menu-entrada-$r')), findsOneWidget, reason: r);
        }
        final orden = [for (final r in admin) x(tester, r)];
        expect([...orden]..sort(), orden);
        expect(x(tester, '/inicio'), closeTo(390 / 2, 1));
        expect(find.text('Gestión'), findsOneWidget);
        expect(find.text('Verificación'), findsOneWidget);
        expect(find.text('Quejas'), findsOneWidget);
        expect(find.byKey(const Key('menu-avisos')), findsOneWidget);
      },
    );

    testWidgets(
      'el destino activo sigue a la pantalla; la administración cuelga de Gestión',
      (tester) async {
        // Verificación, Quejas, Inicio, Gestión, Perfil
        Future<List<bool>> m(String u) =>
            marcas(tester, RolUsuario.adminTenant, u, admin);
        expect(await m('/admin/verificacion-aliados'), [
          true,
          false,
          false,
          false,
          false,
        ]);
        expect(await m('/admin/quejas'), [false, true, false, false, false]);
        expect(await m('/inicio'), [false, false, true, false, false]);
        expect(await m('/servicios'), [false, false, false, true, false]);
        for (final r in const [
          '/admin/categorias',
          '/admin/tarifas',
          '/admin/reglas',
          '/admin/metricas',
          '/admin/auditoria-transacciones',
        ]) {
          expect(await m(r), [false, false, false, true, false], reason: r);
        }
        expect(await m('/perfil/editar'), [false, false, false, false, true]);
      },
    );

    testWidgets('volver desde una pantalla de gestión regresa a Gestión', (
      tester,
    ) async {
      String? destino;
      await _montar(
        tester,
        rol: RolUsuario.adminTenant,
        ubicacion: '/admin/categorias',
        onNavegar: (r) => destino = r,
      );
      await tester.tap(find.byKey(const Key('menu-atras')));
      await tester.pumpAndSettle();
      expect(destino, '/servicios');
    });

    testWidgets(
      'la pantalla de Gestión se titula así y lista toda la administración',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SeccionMenuPage(
              tipo: TipoSeccion.servicios,
              rol: RolUsuario.adminTenant,
              onNavegar: (_) {},
            ),
          ),
        );
        expect(find.text('Gestión'), findsOneWidget);
        expect(find.text('Servicios'), findsNothing);
        for (final r in const [
          '/admin/verificacion-aliados',
          '/admin/categorias',
          '/admin/tarifas',
          '/admin/reglas',
          '/admin/metricas',
        ]) {
          await tester.scrollUntilVisible(
            find.byKey(Key('seccion-acceso-$r')),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            find.byKey(Key('seccion-acceso-$r')),
            findsOneWidget,
            reason: r,
          );
        }
      },
    );

    test('los vecinos y los extremos', () {
      String? v(String u, bool adelante) => menuVecinoAlDeslizar(
        u,
        haciaAdelante: adelante,
        rol: RolUsuario.adminTenant,
      );
      expect(v('/admin/verificacion-aliados', true), '/admin/quejas');
      expect(v('/admin/quejas', true), '/inicio');
      expect(v('/inicio', true), '/servicios');
      expect(v('/cuenta', true), isNull);
      expect(v('/admin/categorias', true), isNull);
    });
  });

  group('SCRUM-1647 — roles que no usan la navegación de celular', () {
    test(
      'solo el cliente, el aliado y el administrador de la empresa la tienen',
      () {
        expect(navegacionMovilPara(RolUsuario.cliente), isNotNull);
        expect(navegacionMovilPara(RolUsuario.aliado), isNotNull);
        expect(navegacionMovilPara(RolUsuario.adminTenant), isNotNull);
        expect(navegacionMovilPara(RolUsuario.adminPlataforma), isNull);
        expect(navegacionMovilPara(RolUsuario.desconocido), isNull);
      },
    );

    test(
      'todos los destinos de los tres roles están entre sus rutas conocidas',
      () {
        for (final rol in const [
          RolUsuario.cliente,
          RolUsuario.aliado,
          RolUsuario.adminTenant,
        ]) {
          final nav = navegacionMovilPara(rol)!;
          expect(nav.izquierda, hasLength(2), reason: '$rol');
          expect(nav.derecha, hasLength(2), reason: '$rol');
          // Inicio siempre al centro; Perfil siempre a la derecha del todo.
          expect(nav.todos[2].ruta, '/inicio', reason: '$rol');
          expect(nav.todos.last.ruta, '/cuenta', reason: '$rol');
        }
      },
    );

    testWidgets(
      'el escritorio no tiene barra inferior en ninguno de los tres roles',
      (tester) async {
        for (final rol in const [
          RolUsuario.cliente,
          RolUsuario.aliado,
          RolUsuario.adminTenant,
        ]) {
          await _montar(tester, rol: rol, ubicacion: '/inicio', ancho: 1200);
          expect(
            find.byKey(const Key('barra-inferior')),
            findsNothing,
            reason: '$rol',
          );
          expect(
            find.byKey(const Key('menu-avisos')),
            findsNothing,
            reason: '$rol',
          );
          expect(
            find.byKey(const Key('deslizar-menus')),
            findsNothing,
            reason: '$rol',
          );
        }
      },
    );
  });
}
