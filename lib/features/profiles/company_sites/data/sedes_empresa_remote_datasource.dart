import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/network/gateway_exception.dart';
import 'package:mani/features/profiles/company_sites/domain/entities/sede_empresa.dart';
import 'package:mani/features/profiles/company_sites/domain/usecases/sedes_empresa_usecases.dart';

abstract class ISedesEmpresaRemoteDataSource {
  Future<List<SedeEmpresa>> listarSedes();
  Future<SedeEmpresa> agregarSede(NuevaSedeEmpresa sede);
  Future<SedeEmpresa> editarSede(String sedeId, Map<String, dynamic> cambios);
  Future<List<ZonaSede>> listarZonas();
}

/// Datasource HTTP de las sedes del cliente empresa de la sesión por el API
/// Gateway (US-02.2.2 / SCRUM-852, SCRUM-1387). Usa el alias `me`
/// (MANI-Node#60): Core resuelve el cliente por el usuario del token. El id del
/// usuario no es el id del cliente en Core y con él respondía 404.
class SedesEmpresaRemoteDataSource implements ISedesEmpresaRemoteDataSource {
  const SedesEmpresaRemoteDataSource({required this.gateway});

  final GatewayClient gateway;

  static const rutaSedes = '/api/v1/core/clients/me/sites';
  static const rutaZonas = '/api/v1/core/catalog/zones';

  static String rutaSede(String sedeId) => '$rutaSedes/$sedeId';

  @override
  Future<List<SedeEmpresa>> listarSedes() async {
    final respuesta = await gateway.get(rutaSedes);
    final raw = respuesta['sitios'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(SedeEmpresa.fromJson)
          .toList();
    }
    return const [];
  }

  @override
  Future<SedeEmpresa> agregarSede(NuevaSedeEmpresa sede) async {
    final payload = <String, dynamic>{
      'nombre': sede.nombre.trim(),
      'direccion': sede.direccion.trim(),
      'zonaId': sede.zonaId.trim(),
      'reglas': <String, dynamic>{},
      if (sede.contactoNombre != null && sede.contactoNombre!.trim().isNotEmpty)
        'contactoNombre': sede.contactoNombre!.trim(),
      if (sede.contactoTelefono != null &&
          sede.contactoTelefono!.trim().isNotEmpty)
        'contactoTelefono': sede.contactoTelefono!.trim(),
    };
    return _sitio(await gateway.postJson(rutaSedes, payload));
  }

  @override
  Future<SedeEmpresa> editarSede(
    String sedeId,
    Map<String, dynamic> cambios,
  ) async {
    return _sitio(await gateway.patch(rutaSede(sedeId), cambios));
  }

  @override
  Future<List<ZonaSede>> listarZonas() async {
    final respuesta = await gateway.get(rutaZonas);
    final raw = respuesta['zones'];
    if (raw is! List) {
      throw const GatewayException(message: 'Respuesta de Core sin "zones"');
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ZonaSede.fromJson)
        .toList();
  }

  /// Core responde la sede en `sitio` (201 al crear, 200 al editar).
  SedeEmpresa _sitio(Map<String, dynamic> respuesta) {
    final sitio = respuesta['sitio'];
    if (sitio is! Map<String, dynamic>) {
      throw const GatewayException(message: 'Respuesta de Core sin "sitio"');
    }
    return SedeEmpresa.fromJson(sitio);
  }
}

class SedesEmpresaRepositoryImpl implements ISedesEmpresaRepository {
  const SedesEmpresaRepositoryImpl({required this.remoteDataSource});

  final ISedesEmpresaRemoteDataSource remoteDataSource;

  @override
  Future<List<SedeEmpresa>> listarSedes() => _traducir(
    remoteDataSource.listarSedes,
    'No se pudieron consultar las sedes de la empresa.',
  );

  @override
  Future<SedeEmpresa> agregarSede(NuevaSedeEmpresa sede) => _traducir(
    () => remoteDataSource.agregarSede(sede),
    'No se pudo registrar la nueva sede.',
  );

  @override
  Future<SedeEmpresa> editarSede(String sedeId, Map<String, dynamic> cambios) =>
      _traducir(
        () => remoteDataSource.editarSede(sedeId, cambios),
        'No se pudo guardar el cambio de la sede.',
      );

  @override
  Future<List<ZonaSede>> listarZonas() => _traducir(
    remoteDataSource.listarZonas,
    'No se pudieron cargar las zonas.',
  );

  /// Traduce el error del Gateway a un mensaje para la pantalla. Los 404 de
  /// Core se distinguen por `code`: sin cliente empresa en la sesión o sede que
  /// no es de este cliente. El texto de Core no se muestra porque trae ids.
  Future<T> _traducir<T>(Future<T> Function() accion, String porDefecto) async {
    try {
      return await accion();
    } on GatewayException catch (e) {
      final code = e.cuerpo?['code'];
      if (code == 'CLIENT_NOT_FOUND') {
        throw const SedeEmpresaFailure(
          'Las sedes son para clientes empresa. Tu cuenta no tiene una '
          'empresa registrada.',
          soloClientesEmpresa: true,
        );
      }
      if (code == 'SITE_NOT_FOUND') {
        throw const SedeEmpresaFailure(
          'Esa sede no existe o no es de tu empresa. Actualiza la lista.',
        );
      }
      if (e.statusCode == 404) throw SedeEmpresaFailure(porDefecto);
      throw SedeEmpresaFailure(e.message);
    } catch (_) {
      throw SedeEmpresaFailure(porDefecto);
    }
  }
}
