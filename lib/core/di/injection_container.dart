import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mani/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:mani/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:mani/features/auth/domain/usecases/login_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_cliente_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_aliado_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_empresa_usecase.dart';
import 'package:mani/features/auth/presentation/bloc/auth_cubit.dart';

final sl = GetIt.instance; // sl = service locator

Future<void> init() async {
  // External
  sl.registerLazySingleton(() => Supabase.instance.client);

  // Core
  // TODO: Network info, etc.

  // Features - Auth
  // Bloc
  sl.registerFactory(() => AuthCubit(
    loginUseCase: sl(),
    registerClienteUseCase: sl(),
    registerAliadoUseCase: sl(),
    registerEmpresaUseCase: sl(),
  ));

  // Use cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterClienteUseCase(sl()));
  sl.registerLazySingleton(() => RegisterAliadoUseCase(sl()));
  sl.registerLazySingleton(() => RegisterEmpresaUseCase(sl()));

  // Repository
  sl.registerLazySingleton<IAuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<IAuthRemoteDataSource>(
    () => AuthRemoteDataSource(client: sl()),
  );
}
