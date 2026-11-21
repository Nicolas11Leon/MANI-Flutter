import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/logging/structured_logger.dart';
import 'package:mani/core/network/gateway_exception.dart';
import 'package:mani/features/services/requests/data/repositories/solicitudes_cliente_repository_impl.dart';
import 'package:mani/features/services/requests/domain/entities/catalogo_solicitud.dart';
import 'package:mani/features/services/requests/domain/entities/foto_adjunta.dart';
import 'package:mani/features/services/requests/domain/entities/nueva_solicitud.dart';
import 'package:mani/features/services/requests/domain/failures/solicitud_failure.dart';

import '../fakes.dart';

Matcher _falla(SolicitudErrorTipo tipo) =>
    throwsA(isA<SolicitudFailure>().having((f) => f.tipo, 'tipo', tipo));

NuevaSolicitud _nueva({
  String categoriaId = 'cat-plo',
  int fotos = 0,
  UbicacionSolicitud? ubicacion,
  String clave = 'clave-1',
  String descripcion = descripcionValida,
}) => NuevaSolicitud.crear(
  categoria: CategoriaDisponible(id: categoriaId, nombre: 'X'),
  descripcion: descripcion,
  fotos: [
    for (var i = 0; i < fotos; i++)
      FotoAdjunta.crear(
        nombre: 'f$i.${i.isEven ? 'jpg' : 'png'}',
        bytes: pngMinimo,
      ),
  ],
  ubicacion:
      ubicacion ??
      NuevaDireccion.crear(direccion: 'Calle Colima 120', zona: romaNorte),
  claveIdempotencia: clave,
);

void main() {
  late ServidorSolicitudesFake servidor;
  late List<Map<String, dynamic>> logs;
  late SolicitudesClienteRepositoryImpl repo;

  setUp(() {
    servidor = ServidorSolicitudesFake()..sembrarBase();
    logs = [];
    repo = SolicitudesClienteRepositoryImpl(
      servidor,
      logger: StructuredLogger(
        canal: 'test',
        sink: (l) => logs.add(jsonDecode(l) as Map<String, dynamic>),
      ),
    );
  });

  group('Catálogo', () {
    test('solo categorías ACTIVAS del tenant del cliente', () async {
      final c = await repo.categoriasDisponibles();
      expect(c.map((x) => x.nombre), ['Plomería']);
      expect(c.single.modalidad, ModalidadCobro.cotizacionPrevia);
    });

    test('la búsqueda de zonas excluye las inactivas', () async {
      final z = await repo.buscarZonas('roma');
      expect(z.map((x) => x.nombre), ['Roma Norte']);
      expect(z.single.zonaPadre, 'Cuauhtémoc');
    });

    test('solo mis sitios', () async {
      servidor.sitios.addAll([
        {
          'id': 's1',
          'cliente': 'uid-ana',
          'zona_id': 'z-roma',
          'direccion': 'Mía 1',
        },
        {
          'id': 's2',
          'cliente': 'uid-otro',
          'zona_id': 'z-roma',
          'direccion': 'Ajena',
        },
      ]);
      final s = await repo.misSitios();
      expect(s.map((x) => x.direccion), ['Mía 1']);
    });
  });

  group('Publicar', () {
    test('envía las fotos a Core, que las guarda en la carpeta del tenant y '
        'del usuario, y crea la solicitud', () async {
      final p = await repo.publicar(_nueva(fotos: 2));

      expect(servidor.llamadasCrear, 1, reason: 'una sola petición');
      expect(servidor.storage.keys, [
        'tenant-a/uid-ana/1-f0.jpg',
        'tenant-a/uid-ana/2-f1.png',
      ]);
      final fila = servidor.solicitudes.single;
      expect(fila['estado'], 'PENDIENTE');
      expect(fila['descripcion'], descripcionValida);
      expect(fila['fotos'], servidor.storage.keys.toList());
      expect(p.cantidadFotos, 2);
      expect(p.direccion, 'Calle Colima 120');
      expect(servidor.eventos.single['tipo_evento'], 'SOLICITUD_CREADA');
    });

    test(
      'una dirección nueva crea el sitio y queda disponible después',
      () async {
        await repo.publicar(_nueva());
        final sitios = await repo.misSitios();
        expect(sitios.single.direccion, 'Calle Colima 120');

        await repo.publicar(
          _nueva(ubicacion: SitioExistente(sitios.single), clave: 'clave-2'),
        );
        expect(servidor.sitios, hasLength(1), reason: 'reutiliza el sitio');
      },
    );

    test('el reintento con la misma clave NO duplica la solicitud', () async {
      final primera = await repo.publicar(_nueva(fotos: 1));
      final reintento = await repo.publicar(_nueva(fotos: 1));

      expect(reintento.id, primera.id);
      expect(servidor.solicitudes, hasLength(1));
      expect(
        servidor.storage,
        hasLength(1),
        reason: 'Core descarta las fotos del reintento',
      );
      expect(servidor.eventos, hasLength(1));
    });

    test('si Core rechaza la solicitud no quedan fotos huérfanas', () async {
      servidor.fallarCrearCon = 'MANI-SOL-422Z: zona';

      await expectLater(
        repo.publicar(_nueva(fotos: 3)),
        _falla(SolicitudErrorTipo.zonaInvalida),
      );
      expect(servidor.storage, isEmpty);
      expect(servidor.solicitudes, isEmpty);
    });

    test('si la respuesta se pierde las fotos se conservan y el reintento '
        'recupera la misma solicitud', () async {
      servidor.perderRespuestaUnaVez = true;

      await expectLater(
        repo.publicar(_nueva(fotos: 2)),
        _falla(SolicitudErrorTipo.sinConexion),
      );
      expect(servidor.solicitudes, hasLength(1), reason: 'sí se creó');
      expect(servidor.storage, hasLength(2), reason: 'fotos intactas');

      final reintento = await repo.publicar(_nueva(fotos: 2));

      expect(reintento.id, servidor.solicitudes.single['id']);
      expect(servidor.solicitudes, hasLength(1));
      expect(servidor.storage.keys, servidor.solicitudes.single['fotos']);
    });

    test('una categoría de otro tenant o inactiva se rechaza', () async {
      await expectLater(
        repo.publicar(_nueva(categoriaId: 'cat-otro-tenant')),
        _falla(SolicitudErrorTipo.categoriaInvalida),
      );
      await expectLater(
        repo.publicar(_nueva(categoriaId: 'cat-oculta', clave: 'c2')),
        _falla(SolicitudErrorTipo.categoriaInvalida),
      );
    });

    test('no se puede usar el sitio de otro cliente', () async {
      servidor.sitios.add({
        'id': 'ajeno',
        'cliente': 'uid-otro',
        'zona_id': 'z-roma',
        'direccion': 'Ajena',
      });
      await expectLater(
        repo.publicar(
          _nueva(
            ubicacion: const SitioExistente(
              SitioCliente(id: 'ajeno', direccion: 'Ajena', zona: 'Roma'),
            ),
          ),
        ),
        _falla(SolicitudErrorTipo.ubicacionInvalida),
      );
    });

    test('sin sesión no envía nada a Core', () async {
      servidor.usuario = null;
      await expectLater(
        repo.publicar(_nueva(fotos: 1)),
        _falla(SolicitudErrorTipo.sinSesion),
      );
      expect(servidor.llamadasCrear, 0);
      expect(servidor.storage, isEmpty);
    });

    test('un usuario que no es cliente no puede publicar', () async {
      servidor.esCliente = false;
      await expectLater(
        repo.publicar(_nueva()),
        _falla(SolicitudErrorTipo.noEsCliente),
      );
    });

    test('errores de red se traducen a sinConexion', () async {
      servidor.errorDeRed = TimeoutException('lento');
      await expectLater(
        repo.categoriasDisponibles(),
        _falla(SolicitudErrorTipo.sinConexion),
      );
    });
  });

  group('Aviso a los aliados (SCRUM-1402)', () {
    test(
      'tras crear, orquesta el despacho con la clave de la creación',
      () async {
        final p = await repo.publicar(_nueva(clave: 'clave-xyz'));

        expect(p.aliadosAvisados, isTrue);
        expect(servidor.avisos.single, (p.id, 'clave-xyz'));
      },
    );

    test(
      'si Dispatch falla, la solicitud igual queda publicada sin aviso',
      () async {
        servidor.fallarAviso = GatewayException.fromStatus(503);

        final p = await repo.publicar(_nueva());

        expect(p.aliadosAvisados, isFalse);
        expect(servidor.solicitudes, hasLength(1));
        final log = logs.firstWhere(
          (l) => l['message'] == 'aliados_no_avisados',
        );
        expect(log['level'], 'ERROR');
        expect(log['error'], '503');
        expect(
          logs.firstWhere(
            (l) => l['message'] == 'solicitud_creada',
          )['aliados_avisados'],
          isFalse,
        );
      },
    );

    test('reintentar el aviso usa una clave nueva y traduce errores', () async {
      final p = await repo.publicar(_nueva(clave: 'clave-1'));

      await repo.avisarAliados(p.id);
      expect(servidor.avisos, hasLength(2));
      expect(servidor.avisos.last.$1, p.id);
      expect(servidor.avisos.last.$2, isNot('clave-1'));

      servidor.fallarAviso = const GatewayException(message: 'sin red');
      await expectLater(
        repo.avisarAliados(p.id),
        _falla(SolicitudErrorTipo.sinConexion),
      );
    });
  });

  group('Trazabilidad', () {
    test('log INFO con campos acordados y SIN la descripción', () async {
      await repo.publicar(_nueva(fotos: 1));

      final log = logs.single;
      for (final campo in [
        'timestamp',
        'level',
        'service_id',
        'trace_id',
        'tenant_id',
        'message',
      ]) {
        expect(log.containsKey(campo), isTrue, reason: campo);
      }
      expect(log['event'], 'US-04.1.1.crear_solicitud');
      expect(log['fotos'], 1);
      expect(log['sitio_nuevo'], isTrue);
      expect(jsonEncode(log), isNot(contains('lavaplatos')));
    });

    test('log ERROR al fallar', () async {
      servidor.fallarCrearCon = 'MANI-SOL-422D: descripción';
      await expectLater(
        repo.publicar(_nueva()),
        _falla(SolicitudErrorTipo.descripcionInvalida),
      );
      expect(logs.single['level'], 'ERROR');
      expect(logs.single['error'], 'descripcionInvalida');
    });
  });

  test('mapearGateway traduce el status y el código MANI-SOL de Core', () {
    final casos = <GatewayException, SolicitudErrorTipo>{
      const GatewayException(message: 'sin red'):
          SolicitudErrorTipo.sinConexion,
      GatewayException.fromStatus(401): SolicitudErrorTipo.sinSesion,
      // SCRUM-1643: un 403 sin código ya no se explica como «solo clientes».
      GatewayException.fromStatus(403): SolicitudErrorTipo.sinPermiso,
      GatewayException.fromStatus(413): SolicitudErrorTipo.fotoMuyPesada,
      GatewayException.fromStatus(422, detalle: 'MANI-SOL-422Z: zona'):
          SolicitudErrorTipo.zonaInvalida,
      GatewayException.fromStatus(400, detalle: 'File too large'):
          SolicitudErrorTipo.desconocido,
      GatewayException.fromStatus(503): SolicitudErrorTipo.desconocido,
    };
    casos.forEach((e, tipo) {
      expect(
        SolicitudesClienteRepositoryImpl.mapearGateway(e).tipo,
        tipo,
        reason: e.toString(),
      );
    });
  });

  test('mapearMensaje traduce cada código MANI-SOL', () {
    const casos = {
      'MANI-SOL-401: x': SolicitudErrorTipo.sinSesion,
      'MANI-SOL-403C: x': SolicitudErrorTipo.noEsCliente,
      'MANI-SOL-422C: x': SolicitudErrorTipo.categoriaInvalida,
      'MANI-SOL-422D: x': SolicitudErrorTipo.descripcionInvalida,
      'MANI-SOL-422F: x': SolicitudErrorTipo.fotosInvalidas,
      'MANI-SOL-422S: x': SolicitudErrorTipo.ubicacionInvalida,
      'MANI-SOL-422Z: x': SolicitudErrorTipo.zonaInvalida,
      'JWT expired': SolicitudErrorTipo.sinSesion,
      'algo raro': SolicitudErrorTipo.desconocido,
    };
    casos.forEach((m, tipo) {
      expect(
        SolicitudesClienteRepositoryImpl.mapearMensaje(m).tipo,
        tipo,
        reason: m,
      );
    });
  });
}
