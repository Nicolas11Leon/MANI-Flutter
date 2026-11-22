import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/shell/menu_por_rol.dart';
import 'package:mani/features/home/presentation/pages/seccion_menu_page.dart';

List<String> _rutas(List<EntradaMenu> l) => [for (final e in l) e.ruta];

void main() {
  group('SCRUM-1647 — secciones del menú para celular', () {
    test('cliente: servicios, cuenta y atajos', () {
      expect(
        _rutas(entradasServiciosPara(RolUsuario.cliente)),
        unorderedEquals([
          '/cliente/solicitudes/nueva',
          '/cliente/solicitudes',
          // El historial quedó dentro de Mis solicitudes (#152).
          '/cliente/quejas',
        ]),
      );
      expect(
        _rutas(entradasCuentaPara(RolUsuario.cliente)),
        unorderedEquals(['/cliente/sedes', '/perfil/editar']),
      );
      expect(_rutas(atajosPara(RolUsuario.cliente)), [
        '/cliente/solicitudes/nueva',
        '/cliente/solicitudes',
      ]);
    });

    test('aliado: servicios, cuenta y atajos', () {
      expect(
        _rutas(entradasServiciosPara(RolUsuario.aliado)),
        unorderedEquals([
          '/aliado/solicitudes',
          '/aliado/historial',
          '/aliado/cobros',
        ]),
      );
      expect(
        _rutas(entradasCuentaPara(RolUsuario.aliado)),
        unorderedEquals([
          '/aliado/cobertura',
          '/aliado/disponibilidad',
          '/categories',
          '/perfil/editar',
        ]),
      );
      expect(_rutas(atajosPara(RolUsuario.aliado)), [
        '/aliado/solicitudes',
        '/aliado/cobros',
      ]);
    });

    test('administrador de la empresa: la administración va en servicios', () {
      final servicios = _rutas(entradasServiciosPara(RolUsuario.adminTenant));
      expect(servicios, contains('/admin/verificacion-aliados'));
      expect(servicios, contains('/admin/categorias'));
      expect(servicios, isNot(contains('/perfil/editar')));
      expect(servicios, isNot(contains('/perfil/avisos')));
      expect(_rutas(atajosPara(RolUsuario.adminTenant)), [
        '/admin/verificacion-aliados',
        '/admin/quejas',
      ]);
    });

    test('cada entrada del menú de cada rol está en una sola sección', () {
      for (final rol in RolUsuario.values) {
        final todas = _rutas(entradasMenuPara(rol));
        final servicios = _rutas(entradasServiciosPara(rol));
        final cuenta = _rutas(entradasCuentaPara(rol));
        // Ninguna ruta repetida entre secciones.
        expect(
          servicios.toSet().intersection(cuenta.toSet()),
          isEmpty,
          reason: '$rol',
        );
        // Todo lo que no es inicio ni avisos queda en servicios o en cuenta: nada se pierde al pasar a celular.
        final reparto = {...servicios, ...cuenta, '/inicio', '/perfil/avisos'};
        expect(reparto, containsAll(todas), reason: '$rol');
      }
    });

    test('un administrador de plataforma ve lo del rol con el que actúa', () {
      final comoAliado = _rutas(
        entradasServiciosPara(
          RolUsuario.adminPlataforma,
          actuandoComo: RolUsuario.aliado,
        ),
      );
      expect(comoAliado, contains('/aliado/solicitudes'));
      expect(comoAliado, contains('/plataforma/tenants'));
    });

    test('seccionDeLaRuta dice de qué pantalla cuelga cada ruta', () {
      expect(
        seccionDeLaRuta('/cliente/solicitudes', RolUsuario.cliente),
        rutaServicios,
      );
      expect(
        seccionDeLaRuta('/cliente/solicitudes/123', RolUsuario.cliente),
        rutaServicios,
      );
      expect(seccionDeLaRuta('/perfil/editar', RolUsuario.cliente), rutaCuenta);
      expect(seccionDeLaRuta('/cliente/sedes', RolUsuario.cliente), rutaCuenta);
      expect(seccionDeLaRuta('/inicio', RolUsuario.cliente), isNull);
      expect(seccionDeLaRuta('/perfil/avisos', RolUsuario.cliente), isNull);
    });
  });

  group('SCRUM-1647 — pantalla de Servicios y de Perfil', () {
    Future<void> montar(
      WidgetTester tester,
      TipoSeccion tipo, {
      RolUsuario rol = RolUsuario.cliente,
      ValueChanged<String>? onNavegar,
      Future<void> Function()? onCerrarSesion,
    }) => tester.pumpWidget(
      MaterialApp(
        home: SeccionMenuPage(
          tipo: tipo,
          rol: rol,
          onNavegar: onNavegar ?? (_) {},
          onCerrarSesion: onCerrarSesion,
        ),
      ),
    );

    testWidgets('Servicios lista los accesos del rol y navega al tocar uno', (
      tester,
    ) async {
      String? destino;
      await montar(
        tester,
        TipoSeccion.servicios,
        onNavegar: (r) => destino = r,
      );

      expect(find.text('Servicios'), findsOneWidget);
      expect(
        find.byKey(const Key('seccion-acceso-/cliente/solicitudes/nueva')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('seccion-cerrar-sesion')), findsNothing);

      await tester.tap(
        find.byKey(const Key('seccion-acceso-/cliente/solicitudes')),
      );
      expect(destino, '/cliente/solicitudes');
    });

    testWidgets('Perfil lista la cuenta y ofrece cerrar sesión', (
      tester,
    ) async {
      var cerro = false;
      await montar(
        tester,
        TipoSeccion.cuenta,
        onCerrarSesion: () async => cerro = true,
      );

      expect(find.text('Tu cuenta'), findsOneWidget);
      expect(
        find.byKey(const Key('seccion-acceso-/perfil/editar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('seccion-acceso-/cliente/sedes')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('seccion-cerrar-sesion')));
      await tester.pumpAndSettle();
      // Pide confirmación antes de cerrar (SCRUM-1650, QAS-39).
      expect(cerro, isFalse);
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirmacion-confirmar')));
      await tester.pumpAndSettle();
      expect(cerro, isTrue);
    });

    testWidgets('cancelar la confirmación no cierra la sesión', (tester) async {
      var cerro = false;
      await montar(
        tester,
        TipoSeccion.cuenta,
        onCerrarSesion: () async => cerro = true,
      );
      await tester.tap(find.byKey(const Key('seccion-cerrar-sesion')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirmacion-cancelar')));
      await tester.pumpAndSettle();
      expect(cerro, isFalse);
      expect(find.text('Tu cuenta'), findsOneWidget);
    });

    testWidgets('sin cerrar sesión disponible, Perfil no lo muestra', (
      tester,
    ) async {
      await montar(tester, TipoSeccion.cuenta);
      expect(find.byKey(const Key('seccion-cerrar-sesion')), findsNothing);
    });

    testWidgets(
      'un rol sin entradas muestra un mensaje y no una pantalla vacía',
      (tester) async {
        await montar(
          tester,
          TipoSeccion.servicios,
          rol: RolUsuario.desconocido,
        );
        expect(find.byKey(const Key('seccion-vacia')), findsOneWidget);
      },
    );
  });
}
