import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mani/core/network/gateway_exception.dart';
import 'package:mani/core/platform/selector_fotos.dart';
import 'package:mani/features/services/requests/data/datasources/solicitudes_cliente_remote_datasource.dart';
import 'package:mani/features/services/requests/domain/entities/catalogo_solicitud.dart';
import 'package:mani/features/services/requests/domain/entities/foto_adjunta.dart';
import 'package:mani/features/services/requests/domain/entities/nueva_solicitud.dart';
import 'package:mani/features/services/requests/domain/entities/solicitud_publicada.dart';
import 'package:mani/features/services/requests/domain/failures/solicitud_failure.dart';
import 'package:mani/features/services/requests/domain/repositories/solicitudes_cliente_repository.dart';
import 'package:mani/features/services/requests/domain/usecases/solicitud_usecases.dart';
import 'package:mani/features/services/requests/presentation/bloc/crear_solicitud_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------- datos
/// PNG válido de 1×1 px (las miniaturas lo decodifican sin error).
final Uint8List pngMinimo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

ArchivoLocal foto(String nombre, {int? bytes}) => ArchivoLocal(
  nombre: nombre,
  bytes: bytes == null ? pngMinimo : Uint8List(bytes),
);

const plomeria = CategoriaDisponible(
  id: 'cat-plo',
  nombre: 'Plomería',
  modalidad: ModalidadCobro.cotizacionPrevia,
);
const cerrajeria = CategoriaDisponible(
  id: 'cat-cer',
  nombre: 'Cerrajería',
  modalidad: ModalidadCobro.tarifaEstandar,
);
const casa = SitioCliente(
  id: 'sitio-casa',
  direccion: 'Calle Colima 120, Apto 401',
  zona: 'Roma Norte',
  zonaPadre: 'Cuauhtémoc',
);
const romaNorte = ZonaOpcion(
  id: 'z-roma',
  nombre: 'Roma Norte',
  zonaPadre: 'Cuauhtémoc',
);
const polanco = ZonaOpcion(
  id: 'z-polanco',
  nombre: 'Polanco',
  zonaPadre: 'Miguel Hidalgo',
);

const descripcionValida =
    'La tubería debajo del lavaplatos gotea desde ayer y moja el piso.';

// ------------------------------------------------ repositorio en memoria
class FakeSolicitudesClienteRepository implements SolicitudesClienteRepository {
  FakeSolicitudesClienteRepository({
    this.categorias = const [plomeria, cerrajeria],
    this.sitios = const [casa],
    this.zonas = const [romaNorte, polanco],
  });

  List<CategoriaDisponible> categorias;
  List<SitioCliente> sitios;
  List<ZonaOpcion> zonas;

  SolicitudFailure? fallarAlCargar;
  SolicitudFailure? fallarAlPublicar;
  Completer<void>? pausaPublicar;

  int llamadasPublicar = 0;
  int llamadasBuscar = 0;
  final List<NuevaSolicitud> publicadas = [];

  /// Si es `false`, [publicar] devuelve la solicitud sin aviso a los aliados.
  bool avisoAlPublicar = true;
  SolicitudFailure? fallarAlAvisar;
  final List<String> avisos = [];

  @override
  Future<List<CategoriaDisponible>> categoriasDisponibles() async {
    if (fallarAlCargar != null) {
      throw fallarAlCargar!;
    }
    return categorias;
  }

  @override
  Future<List<SitioCliente>> misSitios() async {
    if (fallarAlCargar != null) {
      throw fallarAlCargar!;
    }
    return sitios;
  }

  @override
  Future<List<ZonaOpcion>> buscarZonas(String texto) async {
    llamadasBuscar++;
    final t = texto.toLowerCase();
    return zonas.where((z) => z.nombre.toLowerCase().contains(t)).toList();
  }

  @override
  Future<SolicitudPublicada> publicar(NuevaSolicitud solicitud) async {
    llamadasPublicar++;
    if (pausaPublicar != null) {
      await pausaPublicar!.future;
    }
    if (fallarAlPublicar != null) {
      throw fallarAlPublicar!;
    }
    publicadas.add(solicitud);
    final (direccion, zona, padre) = switch (solicitud.ubicacion) {
      SitioExistente(:final sitio) => (
        sitio.direccion,
        sitio.zona,
        sitio.zonaPadre,
      ),
      NuevaDireccion(:final direccion, :final zona) => (
        direccion,
        zona.nombre,
        zona.zonaPadre,
      ),
    };
    return SolicitudPublicada(
      id: 'sol-${publicadas.length}',
      categoria: solicitud.categoria.nombre,
      modalidad: solicitud.categoria.modalidad,
      descripcion: solicitud.descripcion,
      direccion: direccion,
      zona: zona,
      zonaPadre: padre,
      cantidadFotos: solicitud.fotos.length,
      fechaCreacion: DateTime.now(),
      aliadosAvisados: avisoAlPublicar,
    );
  }

  @override
  Future<void> avisarAliados(String solicitudId) async {
    if (fallarAlAvisar != null) {
      throw fallarAlAvisar!;
    }
    avisos.add(solicitudId);
  }
}

class FakeSelectorFotos implements SelectorFotos {
  FakeSelectorFotos([this.siguiente = const []]);

  /// Lo que "elegirá" el usuario la próxima vez.
  List<ArchivoLocal> siguiente;
  int aperturas = 0;

  @override
  Future<List<ArchivoLocal>> seleccionar() async {
    aperturas++;
    return siguiente;
  }
}

CrearSolicitudCubit crearCubit(
  SolicitudesClienteRepository repo, {
  String Function()? generarClave,
}) {
  var n = 0;
  return CrearSolicitudCubit(
    cargarCatalogo: CargarCatalogoSolicitud(repo),
    buscarZonas: BuscarZonas(repo),
    publicar: PublicarSolicitud(repo),
    avisarAliados: AvisarAliados(repo),
    generarClave:
        generarClave ?? () => '00000000-0000-4000-8000-00000000000${++n}',
  );
}

// ------------------------------------------- servidor Core/Supabase simulado
/// Simula, para un cliente autenticado, las RPC de catálogo de
/// `006_crear_solicitud.sql` y la creación en Core por el Gateway
/// (SCRUM-1072), con el bucket privado `solicitudes`.
class ServidorSolicitudesFake implements SolicitudesClienteRemoteDataSource {
  ServidorSolicitudesFake({
    this.usuario = 'uid-ana',
    this.tenant = 'tenant-a',
    this.esCliente = true,
  });

  String? usuario;
  String tenant;
  bool esCliente;

  /// Categorías de TODOS los tenants: {id, tenant_id, nombre, flujo, estado}.
  final List<Map<String, dynamic>> categorias = [];
  final List<Map<String, dynamic>> sitios = [];
  final List<Map<String, dynamic>> zonas = [];
  final List<Map<String, dynamic>> solicitudes = [];
  final List<Map<String, dynamic>> eventos = [];

  /// Objetos que Core dejó en el bucket `solicitudes`: ruta → bytes.
  final Map<String, Uint8List> storage = {};

  Object? errorDeRed;
  int llamadasCrear = 0;

  /// Avisos a los aliados recibidos (solicitud, Idempotency-Key).
  final List<(String, String)> avisos = [];

  /// Si se asigna, `avisarAliados` falla con esta excepción (Dispatch caído).
  GatewayException? fallarAviso;

  /// Si se asigna, `crear` falla con un 422 cuyo mensaje es este.
  String? fallarCrearCon;

  /// Simula que Core crea la solicitud pero la respuesta se pierde por la red
  /// (una sola vez): el cliente no sabe si se creó.
  bool perderRespuestaUnaVez = false;

  void sembrarBase() {
    categorias.addAll([
      {
        'id': 'cat-plo',
        'tenant_id': 'tenant-a',
        'nombre': 'Plomería',
        'flujo_operativo': 'COTIZACION_PREVIA',
        'estado': 'ACTIVO',
      },
      {
        'id': 'cat-oculta',
        'tenant_id': 'tenant-a',
        'nombre': 'Pintura',
        'flujo_operativo': 'TARIFA_ESTANDAR',
        'estado': 'INACTIVO',
      },
      {
        'id': 'cat-otro-tenant',
        'tenant_id': 'tenant-b',
        'nombre': 'Electricidad MTY',
        'flujo_operativo': 'COTIZACION_PREVIA',
        'estado': 'ACTIVO',
      },
    ]);
    zonas.addAll([
      {
        'id': 'z-roma',
        'nombre': 'Roma Norte',
        'padre': 'Cuauhtémoc',
        'estado': 'ACTIVO',
      },
      {
        'id': 'z-condesa',
        'nombre': 'Condesa',
        'padre': 'Cuauhtémoc',
        'estado': 'ACTIVO',
      },
      {
        'id': 'z-vieja',
        'nombre': 'Roma Vieja',
        'padre': 'Cuauhtémoc',
        'estado': 'INACTIVO',
      },
    ]);
  }

  // ------------------------------------------------------------ utilidades
  void _exigirCliente() {
    if (errorDeRed != null) {
      throw errorDeRed!;
    }
    if (usuario == null) {
      throw const PostgrestException(message: 'MANI-SOL-401: sesión requerida');
    }
    if (!esCliente) {
      throw const PostgrestException(message: 'MANI-SOL-403C: no es cliente');
    }
  }

  Map<String, dynamic>? _zona(String? id) {
    for (final z in zonas) {
      if (z['id'] == id) {
        return z;
      }
    }
    return null;
  }

  Map<String, dynamic> _jsonSolicitud(Map<String, dynamic> s) {
    final sitio = sitios.firstWhere((x) => x['id'] == s['sitio_id']);
    final zona = _zona(sitio['zona_id'] as String)!;
    final cat = categorias.firstWhere((c) => c['id'] == s['categoria_id']);
    return {
      'id': s['id'],
      'estado': s['estado'],
      'categoriaId': s['categoria_id'],
      'categoria': cat['nombre'],
      'flujoOperativo': cat['flujo_operativo'],
      'descripcion': s['descripcion'],
      'sitioId': s['sitio_id'],
      'direccion': sitio['direccion'],
      'zonaId': sitio['zona_id'],
      'zona': zona['nombre'],
      'zonaPadre': zona['padre'],
      'fotos': (s['fotos'] as List).length,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  // ------------------------------------------------------------ datasource
  @override
  Future<List<Map<String, dynamic>>> listarCategorias() async {
    _exigirCliente();
    return categorias
        .where((c) => c['tenant_id'] == tenant && c['estado'] == 'ACTIVO')
        .map(
          (c) => {
            'id': c['id'],
            'nombre': c['nombre'],
            'flujoOperativo': c['flujo_operativo'],
          },
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listarSitios() async {
    _exigirCliente();
    return sitios.where((s) => s['cliente'] == usuario).map((s) {
      final z = _zona(s['zona_id'] as String)!;
      return {
        'id': s['id'],
        'direccion': s['direccion'],
        'zona': z['nombre'],
        'zonaPadre': z['padre'],
      };
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> buscarZonas(String texto) async {
    _exigirCliente();
    final t = texto.trim().toLowerCase();
    if (t.length < 2) {
      return const [];
    }
    return zonas
        .where((z) => z['estado'] == 'ACTIVO')
        .where((z) => (z['nombre'] as String).toLowerCase().contains(t))
        .map(
          (z) => {
            'id': z['id'],
            'nombre': z['nombre'],
            'zonaPadre': z['padre'],
          },
        )
        .toList();
  }

  /// Simula `POST /api/v1/core/solicitudes` (SCRUM-1072): Core sube las
  /// fotos a `{tenant}/{usuario}/...`, crea la solicitud y, si falla o es un
  /// reintento, borra lo que subió. Los errores llegan como los traduce el
  /// GatewayClient.
  @override
  Future<Map<String, dynamic>> crear({
    required String categoriaId,
    required String descripcion,
    required List<FotoAdjunta> fotos,
    required String claveIdempotencia,
    String? sitioId,
    String? direccion,
    String? zonaId,
  }) async {
    llamadasCrear++;
    if (errorDeRed != null) {
      throw const GatewayException(message: 'Sin conexión');
    }
    if (usuario == null) {
      throw GatewayException.fromStatus(401);
    }
    if (!esCliente) {
      // Core responde el 403 de quien no es cliente con su código (SCRUM-1643).
      throw GatewayException.fromStatus(
        403,
        cuerpo: const {'code': 'MANI-SOL-403C'},
      );
    }
    if (fotos.length > 5) {
      throw _rechazo('MANI-SOL-422F: fotos');
    }
    final subidas = <String>[];
    for (final f in fotos) {
      final ruta = '$tenant/$usuario/${++_subidasTotales}-${f.nombre}';
      storage[ruta] = f.bytes;
      subidas.add(ruta);
    }
    try {
      final fila = _crearFila(
        categoriaId: categoriaId,
        descripcion: descripcion,
        claveIdempotencia: claveIdempotencia,
        sitioId: sitioId,
        direccion: direccion,
        zonaId: zonaId,
        fotos: subidas,
      );
      if (fila['fotos'] != subidas) {
        _descartar(subidas); // reintento: Core devuelve la existente
      }
      if (perderRespuestaUnaVez) {
        perderRespuestaUnaVez = false;
        throw const GatewayException(message: 'respuesta perdida');
      }
      return _jsonSolicitud(fila);
    } on GatewayException catch (e) {
      if (e.statusCode != null) {
        _descartar(subidas);
      }
      rethrow;
    }
  }

  @override
  Future<void> avisarAliados(
    String solicitudId, {
    required String clave,
  }) async {
    if (fallarAviso != null) {
      throw fallarAviso!;
    }
    avisos.add((solicitudId, clave));
  }

  int _subidasTotales = 0;

  void _descartar(List<String> rutas) => rutas.forEach(storage.remove);

  GatewayException _rechazo(String mensaje) =>
      GatewayException.fromStatus(422, detalle: mensaje);

  Map<String, dynamic> _crearFila({
    required String categoriaId,
    required String descripcion,
    required String claveIdempotencia,
    required List<String> fotos,
    String? sitioId,
    String? direccion,
    String? zonaId,
  }) {
    if (fallarCrearCon != null) {
      throw _rechazo(fallarCrearCon!);
    }
    for (final s in solicitudes) {
      if (s['cliente'] == usuario && s['clave'] == claveIdempotencia) {
        return s;
      }
    }
    final cat = categorias.where(
      (c) =>
          c['id'] == categoriaId &&
          c['tenant_id'] == tenant &&
          c['estado'] == 'ACTIVO',
    );
    if (cat.isEmpty) {
      throw _rechazo('MANI-SOL-422C: categoría');
    }
    final d = descripcion.trim();
    if (d.length < 20 || d.length > 1000) {
      throw _rechazo('MANI-SOL-422D: descripción');
    }
    String idSitio;
    if (sitioId != null) {
      final s = sitios.where(
        (x) => x['id'] == sitioId && x['cliente'] == usuario,
      );
      if (s.isEmpty) {
        throw _rechazo('MANI-SOL-422S: sitio');
      }
      idSitio = sitioId;
    } else {
      final dir = (direccion ?? '').trim();
      if (dir.length < 5 || dir.length > 200) {
        throw _rechazo('MANI-SOL-422S: dirección');
      }
      final z = _zona(zonaId);
      if (z == null || z['estado'] != 'ACTIVO') {
        throw _rechazo('MANI-SOL-422Z: zona');
      }
      idSitio = 'sitio-${sitios.length + 1}';
      sitios.add({
        'id': idSitio,
        'cliente': usuario,
        'tenant_id': tenant,
        'zona_id': zonaId,
        'direccion': dir,
      });
    }
    final fila = {
      'id': 'sol-${solicitudes.length + 1}',
      'tenant_id': tenant,
      'cliente': usuario,
      'categoria_id': categoriaId,
      'sitio_id': idSitio,
      'estado': 'PENDIENTE',
      'descripcion': d,
      'fotos': fotos,
      'clave': claveIdempotencia,
    };
    solicitudes.add(fila);
    eventos.add({
      'solicitud_id': fila['id'],
      'tipo_evento': 'SOLICITUD_CREADA',
    });
    return fila;
  }

  @override
  String? get usuarioId => usuario;

  @override
  String? get tenantIdSesion => tenant;
}
