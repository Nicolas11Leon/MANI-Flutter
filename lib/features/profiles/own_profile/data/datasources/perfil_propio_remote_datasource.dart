import 'dart:typed_data';

import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/network/gateway_exception.dart';
import 'package:mani/features/profiles/own_profile/domain/entities/perfil_propio.dart';

/// La foto de perfil no cumple el formato o el tamaño acordados por el PO
/// (SCRUM-1389: JPG o PNG de hasta 5 MB). [toString] devuelve solo el mensaje
/// porque la pantalla lo muestra tal cual.
class FotoPerfilInvalidaException implements Exception {
  const FotoPerfilInvalidaException();

  static const mensaje = 'La foto debe ser JPG o PNG de hasta 5 MB';

  @override
  String toString() => mensaje;
}

abstract interface class PerfilPropioRemoteDataSource {
  Future<PerfilPropio> obtenerPerfilPropio();

  Future<PerfilPropio> actualizarPerfilPropio({
    required String fullName,
    required String phone,
    required String address,
  });

  Future<PerfilPropio> subirFotoPerfil({
    required String nombreArchivo,
    required Uint8List bytes,
  });
}

/// Adaptador HTTP hacia el NGINX API Gateway para `US-02.3.1` (`SCRUM-854`).
class GatewayPerfilPropioDataSource implements PerfilPropioRemoteDataSource {
  GatewayPerfilPropioDataSource(this._gatewayClient);

  final GatewayClient _gatewayClient;

  static const _formatosSoportados = ['.png', '.jpg', '.jpeg'];

  /// Mismo tope que Core (multer `fileSize` en `profiles.routes.js`).
  static const tamanoMaximoFoto = 5 * 1024 * 1024;

  static bool esFormatoImagenSoportado(String nombreArchivo) {
    final lower = nombreArchivo.trim().toLowerCase();
    return _formatosSoportados.any(lower.endsWith);
  }

  /// MIME de la parte `photo`. Core valida el tipo declarado de la parte
  /// (`UpdateOwnProfileUseCase`); sin él, `http` envía
  /// `application/octet-stream` y Core rechaza un PNG válido con 400
  /// (SCRUM-1634).
  static String tipoContenidoFoto(String nombreArchivo) =>
      nombreArchivo.trim().toLowerCase().endsWith('.png')
      ? 'image/png'
      : 'image/jpeg';

  /// `true` si la foto puede enviarse: formato admitido y a lo sumo 5 MB.
  static bool esFotoValida(String nombreArchivo, Uint8List bytes) =>
      esFormatoImagenSoportado(nombreArchivo) &&
      bytes.lengthInBytes <= tamanoMaximoFoto;

  @override
  Future<PerfilPropio> obtenerPerfilPropio() async {
    final res = await _gatewayClient.get('/api/v1/core/profiles/me');
    return PerfilPropio.fromJson(res);
  }

  @override
  Future<PerfilPropio> actualizarPerfilPropio({
    required String fullName,
    required String phone,
    required String address,
  }) async {
    final res = await _gatewayClient.patch('/api/v1/core/profiles/me', {
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
    });
    return PerfilPropio.fromJson(res);
  }

  @override
  Future<PerfilPropio> subirFotoPerfil({
    required String nombreArchivo,
    required Uint8List bytes,
  }) async {
    // Se valida antes de enviar: un archivo inválido nunca llega al Gateway.
    if (!esFotoValida(nombreArchivo, bytes)) {
      throw const FotoPerfilInvalidaException();
    }
    try {
      final res = await _gatewayClient.postMultipart(
        '/api/v1/core/profiles/me/photo',
        campos: const {},
        archivos: [
          ArchivoMultipart(
            campo: 'photo',
            nombre: nombreArchivo,
            bytes: bytes,
            tipoContenido: tipoContenidoFoto(nombreArchivo),
          ),
        ],
      );
      return PerfilPropio.fromJson(res);
    } on GatewayException catch (e) {
      // 413 lo emite NGINX por tamaño; 400 lo emite Core (multer o MIME).
      if (e.statusCode == 413 || e.statusCode == 400) {
        throw const FotoPerfilInvalidaException();
      }
      rethrow;
    }
  }
}
