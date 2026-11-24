import 'package:mani/features/profiles/company_sites/domain/entities/sede_empresa.dart';

class SedeEmpresaFailure implements Exception {
  const SedeEmpresaFailure(this.message, {this.soloClientesEmpresa = false});
  final String message;

  /// Core respondió que la cuenta no es de un cliente empresa: la pantalla no aplica, no es un fallo transitorio.
  final bool soloClientesEmpresa;

  @override
  String toString() => message;
}

/// Sedes del cliente empresa de la sesión. Ningún método recibe el id del
/// cliente: Core lo resuelve por el usuario del token con el alias `me`
/// (SCRUM-1387), así que la app no puede pedir las sedes de otro cliente.
abstract class ISedesEmpresaRepository {
  Future<List<SedeEmpresa>> listarSedes();
  Future<SedeEmpresa> agregarSede(NuevaSedeEmpresa sede);
  Future<SedeEmpresa> editarSede(String sedeId, Map<String, dynamic> cambios);

  /// Zonas del catálogo de Core (SCRUM-1393), también las no seleccionables,
  /// para poder nombrar la zona padre.
  Future<List<ZonaSede>> listarZonas();
}

class ListarSedesEmpresaUseCase {
  const ListarSedesEmpresaUseCase(this.repository);
  final ISedesEmpresaRepository repository;

  Future<List<SedeEmpresa>> call() => repository.listarSedes();
}

class ListarZonasSedeUseCase {
  const ListarZonasSedeUseCase(this.repository);
  final ISedesEmpresaRepository repository;

  Future<List<ZonaSede>> call() => repository.listarZonas();
}

class AgregarSedeEmpresaUseCase {
  const AgregarSedeEmpresaUseCase(this.repository);
  final ISedesEmpresaRepository repository;

  Future<SedeEmpresa> call(NuevaSedeEmpresa sede) {
    _validar(sede);
    return repository.agregarSede(sede);
  }
}

/// Edición parcial (PATCH): solo viaja lo que cambió. Core vuelve a validar la
/// sede completa y responde 400 si la zona no existe (RF-09).
class EditarSedeEmpresaUseCase {
  const EditarSedeEmpresaUseCase(this.repository);
  final ISedesEmpresaRepository repository;

  Future<SedeEmpresa> call(SedeEmpresa actual, NuevaSedeEmpresa datos) {
    _validar(datos);
    final cambios = <String, dynamic>{
      if (datos.nombre.trim() != actual.nombre) 'nombre': datos.nombre.trim(),
      if (datos.direccion.trim() != actual.direccion)
        'direccion': datos.direccion.trim(),
      if (datos.zonaId.trim() != actual.zonaId) 'zonaId': datos.zonaId.trim(),
      if (_opcional(datos.contactoNombre) != actual.contactoNombre)
        'contactoNombre': _opcional(datos.contactoNombre),
      if (_opcional(datos.contactoTelefono) != actual.contactoTelefono)
        'contactoTelefono': _opcional(datos.contactoTelefono),
    };
    if (cambios.isEmpty) {
      throw const SedeEmpresaFailure('No hay cambios para guardar.');
    }
    return repository.editarSede(actual.id, cambios);
  }
}

/// Texto opcional normalizado: vacío equivale a no tenerlo.
String? _opcional(String? valor) {
  final limpio = valor?.trim() ?? '';
  return limpio.isEmpty ? null : limpio;
}

void _validar(NuevaSedeEmpresa sede) {
  if (sede.nombre.trim().isEmpty) {
    throw const SedeEmpresaFailure('El nombre de la sede es obligatorio.');
  }
  if (sede.direccion.trim().isEmpty) {
    throw const SedeEmpresaFailure('La dirección de la sede es obligatoria.');
  }
  if (sede.zonaId.trim().isEmpty) {
    throw const SedeEmpresaFailure(
      'La zona geográfica de la sede es obligatoria.',
    );
  }
}
