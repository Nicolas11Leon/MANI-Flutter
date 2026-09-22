import 'package:mani/features/auth/domain/entities/user_entity.dart';
import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';

class LoginUseCase {
  final IAuthRepository repository;

  LoginUseCase(this.repository);

  Future<UserEntity> call(String email, String password) {
    return repository.signInWithEmail(email: email, password: password);
  }
}
