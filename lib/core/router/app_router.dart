import 'package:go_router/go_router.dart';
import 'package:mani/features/auth/login_page.dart';
import 'package:mani/features/auth/registro_cliente_page.dart';
import 'package:mani/features/auth/registro_aliado_page.dart';
import 'package:mani/features/auth/registro_aliado_empresa_page.dart';

/// Configuración de rutas declarativas limpias para MANI Web (sin hash #).
/// - `/login`: Pantalla de inicio de sesión
/// - `/register-cliente`: Pantalla independiente de registro para clientes (US-02.2.1)
/// - `/register-aliado`: Pantalla independiente de registro para aliados técnicos (US-02.1.1)
/// - `/register-empresa`: Pantalla independiente de registro para aliados empresas (US-02.1.2)
final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/login'),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    // Ruta independiente: Registro de Cliente (US-02.2.1)
    GoRoute(
      path: '/register-cliente',
      name: 'register-cliente',
      builder: (context, state) => const RegistroClientePage(),
    ),
    GoRoute(
      path: '/registro-cliente',
      redirect: (context, state) => '/register-cliente',
    ),
    // Ruta independiente: Registro de Aliado Técnico (US-02.1.1)
    GoRoute(
      path: '/register-aliado',
      name: 'register-aliado',
      builder: (context, state) => const RegistroAliadoPage(),
    ),
    GoRoute(
      path: '/registro-aliado',
      redirect: (context, state) => '/register-aliado',
    ),
    // Ruta independiente: Registro de Aliado Empresa (US-02.1.2)
    GoRoute(
      path: '/register-empresa',
      name: 'register-empresa',
      builder: (context, state) => const RegistroAliadoEmpresaPage(),
    ),
    GoRoute(
      path: '/registro-empresa',
      redirect: (context, state) => '/register-empresa',
    ),
    // Redirecciones por compatibilidad
    GoRoute(
      path: '/register',
      redirect: (context, state) {
        final rolParam = state.uri.queryParameters['rol']?.toLowerCase();
        if (rolParam == 'empresa') return '/register-empresa';
        if (rolParam == 'aliado') return '/register-aliado';
        return '/register-cliente';
      },
    ),
    GoRoute(
      path: '/registro',
      redirect: (context, state) => '/register-cliente',
    ),
  ],
);
