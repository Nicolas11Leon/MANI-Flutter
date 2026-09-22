import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:mani/features/auth/domain/entities/user_entity.dart';
import 'package:mani/features/auth/domain/usecases/login_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_cliente_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_aliado_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_empresa_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase loginUseCase;
  final RegisterClienteUseCase registerClienteUseCase;
  final RegisterAliadoUseCase registerAliadoUseCase;
  final RegisterEmpresaUseCase registerEmpresaUseCase;

  AuthCubit({
    required this.loginUseCase,
    required this.registerClienteUseCase,
    required this.registerAliadoUseCase,
    required this.registerEmpresaUseCase,
  }) : super(AuthInitial());

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      final user = await loginUseCase(email, password);
      emit(AuthAuthenticated(user: user));
    } on AuthException catch (e) {
      emit(AuthError(message: _mapAuthError(e.message)));
    } catch (e) {
      emit(const AuthError(message: 'Error inesperado de conexión.'));
    }
  }

  String _mapAuthError(String message) {
    if (message.contains('Invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return 'Email o contraseña incorrectos.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Por favor confirma tu email antes de ingresar.';
    }
    if (message.contains('Too many requests')) {
      return 'Demasiados intentos. Espera un momento.';
    }
    return 'Error: $message';
  }
}
