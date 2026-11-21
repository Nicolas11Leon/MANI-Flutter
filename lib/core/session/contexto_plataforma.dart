import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/session/rol_usuario.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, GoTrueClient;

/// Usuario de un tenant con el que el administrador de plataforma puede actuar.
class UsuarioTenant extends Equatable {
  const UsuarioTenant({
    required this.id,
    required this.email,
    required this.rol,
    this.estado = '',
  });

  factory UsuarioTenant.fromJson(Map<String, dynamic> json) => UsuarioTenant(
    id: '${json['id']}',
    email: (json['email'] as String?) ?? '',
    rol: (json['rol'] as String?) ?? '',
    estado: (json['estado'] as String?) ?? '',
  );

  final String id;
  final String email;

  /// Rol en la base (`CLIENTE`, `ALIADO`, `ADMIN_TENANT`).
  final String rol;
  final String estado;

  /// Rol con el que la app pinta el menú cuando se actúa como este usuario.
  RolUsuario get rolApp => switch (rol.toUpperCase()) {
    'CLIENTE' => RolUsuario.cliente,
    'ALIADO' => RolUsuario.aliado,
    'ADMIN_TENANT' => RolUsuario.adminTenant,
    _ => RolUsuario.desconocido,
  };

  @override
  List<Object?> get props => [id, email, rol, estado];
}

/// Consulta los usuarios de un tenant (`GET /api/v1/core/tenants/:id/usuarios`,
/// solo para el permiso de plataforma, SCRUM-901).
abstract interface class FuenteUsuariosTenant {
  Future<List<UsuarioTenant>> listar(String tenantId);
}

class GatewayFuenteUsuariosTenant implements FuenteUsuariosTenant {
  GatewayFuenteUsuariosTenant(this._gateway);

  final GatewayClient _gateway;

  static String ruta(String tenantId) =>
      '/api/v1/core/tenants/${Uri.encodeComponent(tenantId)}/usuarios';

  @override
  Future<List<UsuarioTenant>> listar(String tenantId) async => [
    for (final u
        in ((await _gateway.get(ruta(tenantId)))['usuarios'] as List? ??
            const []))
      if (u is Map) UsuarioTenant.fromJson(Map<String, dynamic>.from(u)),
  ];
}

/// Contexto del administrador de plataforma (SCRUM-901): el tenant que
/// administra y, si lo eligió, el usuario de ese tenant con el que actúa.
///
/// La app lo envía en cada petición (cabeceras `X-Mani-Tenant` y
/// `X-Mani-Actuar-Como`); Core y Dispatch las validan y solo las aceptan para
/// ese permiso. Sin tenant elegido, administra el suyo.
class ContextoPlataforma extends ChangeNotifier {
  /// Con [auth] (la app), el contexto se borra en cada inicio o cierre de
  /// sesión y [cabeceras] solo sale con una sesión de administrador de
  /// plataforma. Sin él (pruebas del shell), no escucha nada.
  ContextoPlataforma({GoTrueClient? auth}) : _auth = auth {
    if (auth != null) {
      escucharSesion(auth.onAuthStateChange.map((cambio) => cambio.event));
    }
  }

  final GoTrueClient? _auth;
  String? _tenantId;
  String? _tenantNombre;
  UsuarioTenant? _actuarComo;
  int _version = 0;

  String? get tenantId => _tenantId;
  String? get tenantNombre => _tenantNombre;
  UsuarioTenant? get actuarComo => _actuarComo;

  /// Cambia con cada contexto nuevo: la app la usa para recargar la pantalla.
  int get version => _version;

  /// Rol de las pantallas que se muestran: el del usuario con el que actúa, o
  /// el de administrador del tenant si no actúa como nadie.
  RolUsuario get rolEfectivo => _actuarComo?.rolApp ?? RolUsuario.adminTenant;

  /// Cabeceras de contexto de cada petición. Con [GoTrueClient] (la app) solo
  /// salen si la sesión vigente es de un administrador de plataforma: Core
  /// rechaza con 403 `MANI-PLA-403` a cualquier otro rol que las mande, y un
  /// contexto que quedó de otra sesión en el mismo navegador no debe bloquear
  /// al cliente o aliado que entró después.
  Map<String, String> get cabeceras {
    final auth = _auth;
    if (auth != null &&
        rolDesdeAccessToken(auth.currentSession?.accessToken) !=
            RolUsuario.adminPlataforma) {
      return const {};
    }
    return {
      'X-Mani-Tenant': ?_tenantId,
      'X-Mani-Actuar-Como': ?_actuarComo?.id,
    };
  }

  /// Administra [tenantId]; deja de actuar como otro usuario.
  void elegirTenant(String tenantId, String nombre) {
    if (_tenantId == tenantId && _actuarComo == null) return;
    _tenantId = tenantId;
    _tenantNombre = nombre;
    _actuarComo = null;
    _cambio();
  }

  /// Actúa como [usuario] del tenant elegido; con null, vuelve a administrar.
  void actuarComoUsuario(UsuarioTenant? usuario) {
    if (_actuarComo == usuario) return;
    _actuarComo = usuario;
    _cambio();
  }

  /// Al cerrar sesión: nada del contexto anterior pasa a la siguiente.
  void limpiar() {
    if (_tenantId == null && _actuarComo == null) return;
    _tenantId = null;
    _tenantNombre = null;
    _actuarComo = null;
    _cambio();
  }

  /// Borra el contexto en cada inicio o cierre de sesión que llegue por
  /// [eventos], por cualquier camino (menú, tarjeta de Inicio, token vencido):
  /// el contexto es de la sesión que lo eligió. Un refresco de token no lo
  /// toca.
  StreamSubscription<AuthChangeEvent> escucharSesion(
    Stream<AuthChangeEvent> eventos,
  ) => eventos.listen((evento) {
    if (evento == AuthChangeEvent.signedIn ||
        evento == AuthChangeEvent.signedOut) {
      limpiar();
    }
  });

  void _cambio() {
    _version++;
    notifyListeners();
  }
}
