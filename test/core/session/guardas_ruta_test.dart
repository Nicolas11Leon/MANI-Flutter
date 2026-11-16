import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/session/guardas_ruta.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:mani/core/session/sesion_expirada.dart';
import 'package:mani/core/shell/menu_por_rol.dart';

String? _redirigir(
  String ubicacion, {
  RolUsuario rol = RolUsuario.cliente,
  bool haySesion = true,
  bool esPublica = false,
}) => resolverRedireccion(
  ubicacion: ubicacion,
  esPublica: esPublica,
  haySesion: haySesion,
  rol: rol,
);

void main() {
  group('US-11.2.2 (SCRUM-1445) — guardas de sesión', () {
    test('sin sesión, una ruta con sesión lleva al login', () {
      expect(_redirigir('/aliado/solicitudes', haySesion: false), rutaLogin);
      expect(_redirigir('/perfil/editar', haySesion: false), rutaLogin);
    });

    test('los registros no se redirigen, haya o no sesión', () {
      expect(_redirigir('/login', esPublica: true, haySesion: false), isNull);
      expect(_redirigir('/register-cliente', esPublica: true), isNull);
      expect(
        _redirigir('/register-cliente', esPublica: true, haySesion: false),
        isNull,
      );
    });

    test('con sesión, el login lleva al inicio (SCRUM-1446)', () {
      for (final rol in RolUsuario.values) {
        expect(
          _redirigir(rutaLogin, esPublica: true, rol: rol),
          rutaInicio,
          reason: '$rol',
        );
      }
    });
  });

  group('US-11.2.2 (SCRUM-1445) — guardas por rol', () {
    test('un cliente que abre una ruta de admin vuelve a su inicio', () {
      expect(rutaInicioPara(RolUsuario.cliente), rutaInicio);
      expect(
        _redirigir('/admin/categorias', rol: RolUsuario.cliente),
        rutaInicio,
      );
    });

    test('un aliado no abre rutas de admin ni de cliente', () {
      expect(
        _redirigir('/admin/verificacion-aliados', rol: RolUsuario.aliado),
        rutaInicio,
      );
      expect(_redirigir('/cliente/sedes', rol: RolUsuario.aliado), rutaInicio);
    });

    test('el admin del tenant solo abre la administración de su empresa', () {
      for (final ruta in [
        '/aliado/cobertura',
        '/categories',
        '/cliente/solicitudes',
        '/cliente/sedes',
        '/plataforma/tenants',
      ]) {
        expect(
          _redirigir(ruta, rol: RolUsuario.adminTenant),
          rutaInicio,
          reason: ruta,
        );
      }
      expect(_redirigir('/admin/quejas', rol: RolUsuario.adminTenant), isNull);
    });

    test('el admin de plataforma abre todas las pantallas', () {
      for (final ruta in [
        '/plataforma/tenants',
        '/admin/quejas',
        '/admin/categorias',
        '/aliado/cobertura',
        '/categories',
        '/cliente/solicitudes',
        '/cliente/sedes',
        '/sitios/s-1/reglas',
        '/perfil/editar',
      ]) {
        expect(
          _redirigir(ruta, rol: RolUsuario.adminPlataforma),
          isNull,
          reason: ruta,
        );
      }
    });

    test('sin rol reconocible solo se llega al inicio y al perfil', () {
      expect(
        _redirigir('/admin/categorias', rol: RolUsuario.desconocido),
        rutaInicio,
      );
      expect(_redirigir(rutaInicio, rol: RolUsuario.desconocido), isNull);
      expect(_redirigir('/perfil/editar', rol: RolUsuario.desconocido), isNull);
    });

    test('las reglas del sitio las abren cliente, aliado y admin', () {
      for (final rol in [
        RolUsuario.cliente,
        RolUsuario.aliado,
        RolUsuario.adminTenant,
      ]) {
        expect(_redirigir('/sitios/s-1/reglas', rol: rol), isNull);
      }
      expect(
        _redirigir('/sitios/s-1/reglas', rol: RolUsuario.desconocido),
        rutaInicio,
      );
    });

    test('una ruta con sesión que no está en la tabla se niega', () {
      expect(rolPuedeAbrir(RolUsuario.adminTenant, '/nueva-pantalla'), isFalse);
      expect(_redirigir('/nueva-pantalla', rol: RolUsuario.aliado), rutaInicio);
    });

    test('cada rol puede abrir todas las entradas de su propio menú', () {
      for (final rol in RolUsuario.values) {
        for (final e in entradasMenuPara(rol)) {
          expect(rolPuedeAbrir(rol, e.ruta), isTrue, reason: '$rol ${e.ruta}');
        }
      }
    });

    test('el inicio de cada rol es una ruta que ese rol puede abrir', () {
      for (final rol in RolUsuario.values) {
        expect(rolPuedeAbrir(rol, rutaInicioPara(rol)), isTrue, reason: '$rol');
      }
    });

    test(
      'cada destino de la barra inferior del celular se abre sin redirección, para todo rol',
      () {
        // SCRUM-1647: sin estas entradas en la tabla, «Servicios» y «Perfil» llevaban al inicio y parecían rotos.
        const destinos = [
          '/inicio',
          rutaServicios,
          '/perfil/avisos',
          rutaCuenta,
        ];
        for (final rol in RolUsuario.values) {
          for (final ruta in destinos) {
            expect(rolPuedeAbrir(rol, ruta), isTrue, reason: '$rol $ruta');
            expect(_redirigir(ruta, rol: rol), isNull, reason: '$rol $ruta');
          }
        }
      },
    );

    test('las pantallas de Servicios y Perfil siguen exigiendo sesión', () {
      for (final ruta in const [rutaServicios, rutaCuenta]) {
        expect(_redirigir(ruta, haySesion: false), rutaLogin, reason: ruta);
      }
    });

    test('lo que lista cada sección es abrible por el rol que la ve', () {
      for (final rol in RolUsuario.values) {
        for (final e in [
          ...entradasServiciosPara(rol),
          ...entradasCuentaPara(rol),
          ...atajosPara(rol),
        ]) {
          expect(rolPuedeAbrir(rol, e.ruta), isTrue, reason: '$rol ${e.ruta}');
        }
      }
    });
  });

  group('US-11.2.2 (SCRUM-1445) — sesión expirada (401)', () {
    test(
      'si el refresco da sesión nueva, se reintenta y no se cierra',
      () async {
        var cierres = 0;
        final reintentar = await refrescarOCerrar(
          refrescar: () async => true,
          cerrar: () async => cierres++,
        );
        expect(reintentar, isTrue);
        expect(cierres, 0);
      },
    );

    test('si el refresco no da sesión, se cierra y no se reintenta', () async {
      var cierres = 0;
      final reintentar = await refrescarOCerrar(
        refrescar: () async => false,
        cerrar: () async => cierres++,
      );
      expect(reintentar, isFalse);
      expect(cierres, 1);
    });

    test('si el refresco lanza, también se cierra la sesión', () async {
      var cierres = 0;
      final reintentar = await refrescarOCerrar(
        refrescar: () async => throw Exception('refresh token vencido'),
        cerrar: () async => cierres++,
      );
      expect(reintentar, isFalse);
      expect(cierres, 1);
    });

    test('un fallo al cerrar no se propaga al cliente HTTP', () async {
      final reintentar = await refrescarOCerrar(
        refrescar: () async => false,
        cerrar: () async => throw Exception('almacenamiento no disponible'),
      );
      expect(reintentar, isFalse);
    });
  });
}
