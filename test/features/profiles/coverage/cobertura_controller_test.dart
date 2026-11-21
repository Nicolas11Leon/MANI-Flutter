import 'package:flutter_test/flutter_test.dart';
import 'package:mani/features/profiles/coverage/domain/failures/cobertura_failure.dart';
import 'package:mani/features/profiles/coverage/presentation/controllers/cobertura_controller.dart';

import 'fakes.dart';

void main() {
  group('CoberturaController', () {
    test(
      'iniciar carga ciudades, cobertura actual y localidades de la ciudad',
      () async {
        final c = CoberturaController(
          FakeCoberturaRepository(coberturaInicial: [chico]),
        );
        await c.iniciar();
        expect(c.carga, EstadoCarga.listo);
        expect(c.ciudad, bogota);
        expect(c.hijasDe('bog'), [chapinero, suba]);
        expect(c.seleccion.ids, {'chi'});
        expect(c.hayCambios, isFalse);
        expect(c.puedeGuardar, isFalse);
      },
    );

    test('primera declaración: no se puede guardar vacío', () async {
      final c = CoberturaController(FakeCoberturaRepository());
      await c.iniciar();
      expect(c.esPrimeraDeclaracion, isTrue);
      expect(c.puedeGuardar, isFalse);
      c.alternar(niza);
      expect(c.puedeGuardar, isTrue);
    });

    test('alternar localidad sobre barrios deja aviso de absorción', () async {
      final c = CoberturaController(
        FakeCoberturaRepository(coberturaInicial: [chico, rosales]),
      );
      await c.iniciar();
      c.alternar(chapinero);
      expect(c.seleccion.ids, {'cha'});
      expect(c.tomarAviso(), contains('reemplaza 2 zonas'));
      expect(c.tomarAviso(), isNull); // un solo uso
    });

    test('guardar con éxito resetea cambios y confirma', () async {
      final repo = FakeCoberturaRepository(coberturaInicial: [chico]);
      final c = CoberturaController(repo);
      await c.iniciar();
      c.alternar(niza);
      expect(await c.guardar(), isTrue);
      expect(repo.guardada, {'chi', 'niz'});
      expect(c.hayCambios, isFalse);
      expect(c.tomarAviso(), contains('Cobertura guardada: 2 zonas'));
    });

    test('guardar con error conserva la selección del usuario', () async {
      final repo = FakeCoberturaRepository(coberturaInicial: [chico])
        ..fallarAlDeclarar = const CoberturaFailure(
          CoberturaErrorTipo.sinConexion,
        );
      final c = CoberturaController(repo);
      await c.iniciar();
      c.alternar(niza);
      expect(await c.guardar(), isFalse);
      expect(c.seleccion.ids, {'chi', 'niz'});
      expect(c.hayCambios, isTrue);
      expect(c.error?.tipo, CoberturaErrorTipo.sinConexion);
    });

    test(
      'no se puede guardar con zonas desactivadas hasta quitarlas',
      () async {
        final c = CoberturaController(
          FakeCoberturaRepository(coberturaInicial: [chico, nizaDesactivada]),
        );
        await c.iniciar();
        c.alternar(rosales);
        expect(c.puedeGuardar, isFalse);
        c.quitarDesactivadas();
        expect(c.seleccion.ids, {'chi', 'ros'});
        expect(c.puedeGuardar, isTrue);
      },
    );

    test('descartarCambios vuelve a lo guardado', () async {
      final c = CoberturaController(
        FakeCoberturaRepository(coberturaInicial: [chico]),
      );
      await c.iniciar();
      c.alternar(niza);
      c.descartarCambios();
      expect(c.seleccion.ids, {'chi'});
      expect(c.hayCambios, isFalse);
    });

    test('error de carga deja estado error y permite reintentar', () async {
      final repo = FakeCoberturaRepository()
        ..fallarAlCargar = const CoberturaFailure(
          CoberturaErrorTipo.sinConexion,
        );
      final c = CoberturaController(repo);
      await c.iniciar();
      expect(c.carga, EstadoCarga.error);
      repo.fallarAlCargar = null;
      await c.iniciar();
      expect(c.carga, EstadoCarga.listo);
    });

    test('buscar con menos de 2 caracteres no consulta', () async {
      final c = CoberturaController(FakeCoberturaRepository());
      await c.iniciar();
      await c.buscar('n');
      expect(c.resultados, isEmpty);
      await c.buscar('ni');
      expect(c.resultados.map((z) => z.id), ['niz']);
    });
  });

  group('zonaDelCatalogo: el mapa solo conoce identificadores', () {
    test('encuentra la ciudad, la localidad y el barrio ya cargados', () async {
      final c = CoberturaController(FakeCoberturaRepository());
      await c.iniciar();

      expect(c.zonaDelCatalogo('bog')?.nombre, 'Bogotá');
      expect(c.zonaDelCatalogo('cha')?.nombre, 'Chapinero');

      // El barrio solo existe tras expandir su localidad.
      expect(c.zonaDelCatalogo('chi'), isNull);
      await c.cargarHijas('cha');
      expect(c.zonaDelCatalogo('chi')?.nombre, isNotNull);
    });

    test('un id desconocido devuelve null y no altera nada', () async {
      final c = CoberturaController(FakeCoberturaRepository());
      await c.iniciar();

      expect(c.zonaDelCatalogo('no-existe'), isNull);
      expect(c.seleccion.ids, isEmpty);
    });
  });
}
