import 'package:mani/core/network/gateway_exception.dart';

final _prefijoCodigo = RegExp(r'^MANI-[A-Z]{3}-\w+:\s*');

/// Códigos con los que Core avisa que el motor de reglas no responde. Las
/// reglas del tenant usan el de su dominio (`MANI-RGL-503`, SCRUM-1722).
const _rulesNoDisponible = {'RULES_SERVICE_UNAVAILABLE', 'MANI-RGL-503'};

/// Mensaje para el usuario a partir de un error del Gateway (M-10 y M-12).
///
/// En los 400 y 409 se muestra el texto de Core sin su código (`MANI-TAR-400:`),
/// porque dice qué corregir. Un 503 de Rules dice que el motor de reglas no
/// está disponible: la app no calcula nada en su lugar (T2). El resto usa el
/// mensaje genérico de [GatewayException].
String mensajeErrorGateway(Object error) {
  if (error is! GatewayException) {
    return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  }
  final status = error.statusCode;
  final textoCore = error.cuerpo?['error'];
  if ((status == 400 || status == 409) && textoCore is String) {
    return textoCore.replaceFirst(_prefijoCodigo, '');
  }
  if (status == 503 && _rulesNoDisponible.contains(error.cuerpo?['code'])) {
    return 'El motor de reglas no está disponible en este momento. '
        'Inténtalo más tarde.';
  }
  if (status == null) {
    return 'No hay conexión con el servidor. Revisa tu red e inténtalo de nuevo.';
  }
  return error.message;
}
