import 'package:mani/features/auth/domain/entities/user_entity.dart';
import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:mani/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:mani/features/auth/data/models/user_model.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final IAuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserEntity> signInWithEmail({required String email, required String password}) async {
    final user = await remoteDataSource.signInWithEmail(email: email, password: password);
    return UserModel.fromSupabase(user);
  }

  @override
  Future<Map<String, dynamic>> registrarClientePersonaNatural({
    required String email,
    required String password,
    required String nombreCompleto,
    required String tenantId,
    String? telefono,
    String? direccionHogar,
  }) {
    return remoteDataSource.registrarClientePersonaNatural(
      email: email,
      password: password,
      nombreCompleto: nombreCompleto,
      tenantId: tenantId,
      telefono: telefono,
      direccionHogar: direccionHogar,
    );
  }

  @override
  Future<Map<String, dynamic>> registrarAliadoPersonaNatural({
    required String email,
    required String password,
    required String nombreCompleto,
    required String tenantId,
    required String categoriaId,
    required List<Map<String, String>> documentosKYC,
  }) {
    return remoteDataSource.registrarAliadoPersonaNatural(
      email: email,
      password: password,
      nombreCompleto: nombreCompleto,
      tenantId: tenantId,
      categoriaId: categoriaId,
      documentosKYC: documentosKYC,
    );
  }

  @override
  Future<Map<String, dynamic>> registrarAliadoEmpresa({
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
    return remoteDataSource.registrarAliadoEmpresa(
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

  @override
  Future<void> signOut() {
    return remoteDataSource.signOut();
  }
}
