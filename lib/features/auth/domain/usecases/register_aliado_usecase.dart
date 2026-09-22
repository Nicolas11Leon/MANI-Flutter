import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';

class RegisterAliadoUseCase {
  final IAuthRepository repository;

  RegisterAliadoUseCase(this.repository);

  Future<Map<String, dynamic>> call({
    required String email,
    required String password,
    required String nombreCompleto,
    required String tenantId,
    required String categoriaId,
    required List<Map<String, String>> documentosKYC,
  }) {
    return repository.registrarAliadoPersonaNatural(
      email: email,
      password: password,
      nombreCompleto: nombreCompleto,
      tenantId: tenantId,
      categoriaId: categoriaId,
      documentosKYC: documentosKYC,
    );
  }
}
