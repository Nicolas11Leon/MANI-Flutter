import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';

class RegisterClienteUseCase {
  final IAuthRepository repository;

  RegisterClienteUseCase(this.repository);

  Future<Map<String, dynamic>> call({
    required String email,
    required String password,
    required String nombreCompleto,
    required String tenantId,
    String? telefono,
    String? direccionHogar,
  }) {
    return repository.registrarClientePersonaNatural(
      email: email,
      password: password,
      nombreCompleto: nombreCompleto,
      tenantId: tenantId,
      telefono: telefono,
      direccionHogar: direccionHogar,
    );
  }
}
