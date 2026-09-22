import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';

class RegisterEmpresaUseCase {
  final IAuthRepository repository;

  RegisterEmpresaUseCase(this.repository);

  Future<Map<String, dynamic>> call({
    required String email,
    required String password,
    required String razonSocial,
    required String nit,
    required String tenantId,
    required String nombreRepresentante,
    String? docRepresentante,
    String? telefonoContacto,
    String? categoriaId,
    required List<Map<String, String>> documentosKYC,
  }) {
    return repository.registrarAliadoEmpresa(
      email: email,
      password: password,
      razonSocial: razonSocial,
      nit: nit,
      tenantId: tenantId,
      nombreRepresentante: nombreRepresentante,
      docRepresentante: docRepresentante,
      telefonoContacto: telefonoContacto,
      categoriaId: categoriaId,
      documentosKYC: documentosKYC,
    );
  }
}
