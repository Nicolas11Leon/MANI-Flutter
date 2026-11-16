import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mani/core/di/injection_container.dart';
import 'package:mani/core/widgets/mani_logo.dart';
import 'package:mani/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:mani/features/auth/domain/usecases/login_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_aliado_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_cliente_empresa_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_cliente_usecase.dart';
import 'package:mani/features/auth/domain/usecases/register_empresa_usecase.dart';
import 'package:mani/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:mani/features/auth/presentation/pages/registro_aliado_empresa_page.dart';
import 'package:mani/features/auth/presentation/pages/registro_aliado_page.dart';
import 'package:mani/features/auth/presentation/pages/registro_cliente_page.dart';

class _Repo implements IAuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

AuthCubit _cubit() {
  final repo = _Repo();
  return AuthCubit(
    loginUseCase: LoginUseCase(repo),
    registerClienteUseCase: RegisterClienteUseCase(repo),
    registerAliadoUseCase: RegisterAliadoUseCase(repo),
    registerEmpresaUseCase: RegisterEmpresaUseCase(repo),
    registerClienteEmpresaUseCase: RegisterClienteEmpresaUseCase(repo),
  );
}

/// La barra superior de los registros lleva el sello de MANI (SCRUM-1646): una sola pieza compartida, no una copia
/// dibujada a mano en cada pantalla.
void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'TENANT_SLUG=plomeria-express');
    sl.registerFactory<AuthCubit>(_cubit);
  });
  tearDown(() async => GetIt.instance.reset());

  Future<void> montar(WidgetTester tester, Widget pagina) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Estas pantallas largas desbordan con la tipografía cuadrada de las pruebas; aquí solo importa la cabecera.
    final original = FlutterError.onError;
    FlutterError.onError = (detalles) {
      if (!detalles.toString().contains('overflowed')) original?.call(detalles);
    };
    addTearDown(() => FlutterError.onError = original);
    await tester.pumpWidget(MaterialApp(home: pagina));
    await tester.pump();
  }

  final paginas = <String, Widget Function()>{
    'registro de cliente': () => const RegistroClientePage(),
    'registro de aliado': () => const RegistroAliadoPage(),
    'registro de empresa aliada': () => const RegistroAliadoEmpresaPage(),
  };

  for (final e in paginas.entries) {
    testWidgets('${e.key}: la barra superior usa el sello de MANI', (
      tester,
    ) async {
      await montar(tester, e.value());
      expect(find.byType(ManiLogo), findsWidgets);
      expect(find.text('MANI Services'), findsOneWidget);
    });
  }
}
