import 'dart:convert';

import 'package:mani/core/logging/structured_logger.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/network/gateway_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mani/features/auth/domain/entities/registro_cliente_empresa.dart';

abstract class IAuthRemoteDataSource {
  Future<User> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Map<String, dynamic>> registrarClientePersonaNatural({
    required String email,
    required String password,
    required String nombreCompleto,
    required String tenantId,
    String? telefono,
    String? direccionHogar,
  });

  Future<Map<String, dynamic>> registrarClienteEmpresa(
    RegistroClienteEmpresa datos,
  );

  Future<Map<String, dynamic>> registrarAliadoPersonaNatural({
    required String email,
    required String password,
    required String nombreCompleto,
    required String tenantId,
    required String categoriaId,
    required List<Map<String, String>> documentosKYC,
  });

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
  });

  Future<List<Map<String, dynamic>>> obtenerDocumentosLegalesActivos({
    String? tenantSlug,
  });

  Future<void> registrarConsentimientoLegal({
    List<String>? documentoLegalIds,
    String? token,
  });

  Future<void> signOut();
}

class AuthRemoteDataSource implements IAuthRemoteDataSource {
  final SupabaseClient client;
  final GatewayClient gateway;

  AuthRemoteDataSource({
    required this.client,
    required this.gateway,
    StructuredLogger? logger,
  }) : _log = logger ?? StructuredLogger(canal: 'mani.consentimiento');

  final StructuredLogger _log;

  /// Registro de aliado empresa en Core Node, a través del Gateway
  /// (US-02.1.2-M2). Ruta y nombres de campo definidos por el contrato
  /// OpenAPI de Core (`RegisterAllyCompanyRequest` en core.yaml).
  static const rutaRegistroEmpresa = '/api/v1/core/auth/register/ally/company';

  /// Registro de aliado persona natural en Core Node, a través del Gateway
  /// (US-02.1.1-M2). Ruta y nombres de campo definidos por el contrato
  /// OpenAPI de CFG-16 (MANI-APIGateway/docs/openapi/core.yaml).
  static const rutaRegistroPersonaNatural = '/api/v1/core/auth/register/ally';

  /// Registro de cliente persona natural en Core Node, a través del Gateway
  /// (US-02.2.1-M2). Reutiliza el MISMO [GatewayClient] (sin crear un
  /// segundo cliente HTTP) y el endpoint de identidad que Core ya expone
  /// para Aliado (mismo authIdentityService del lado del servicio).
  static const rutaRegistroClientePersonaNatural =
      '/api/v1/core/auth/register/client';

  /// Registro de cliente empresa en Core Node (HU-M02-07): NIT y representante
  /// legal, sin sitios; las sedes se administran después, ya con sesión (M-03).
  static const rutaRegistroClienteEmpresa =
      '/api/v1/core/auth/register/client/company';

  /// Resuelve el tenant antes de autenticarse (ADR-0018). No autoriza nada:
  /// Core toma el tenant definitivo del JWT que emite tras el registro.
  static const headerTenantSlug = 'X-Tenant-Slug';

  /// Documentos legales activos y registro de consentimientos (SCRUM-856 / Node#14).
  static const rutaDocumentosLegalesActivos =
      '/api/v1/core/legal/documents/active';
  static const rutaConsentimientosLegales = '/api/v1/core/legal/consents';

  @override
  Future<List<Map<String, dynamic>>> obtenerDocumentosLegalesActivos({
    String? tenantSlug,
  }) async {
    try {
      final respuesta = await gateway.get(
        rutaDocumentosLegalesActivos,
        headers: {
          if (tenantSlug != null && tenantSlug.trim().isNotEmpty)
            headerTenantSlug: tenantSlug.trim(),
        },
      );
      final raw = respuesta['data'];
      if (raw is List) {
        return raw.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  @override
  Future<void> registrarConsentimientoLegal({
    List<String>? documentoLegalIds,
    String? token,
  }) async {
    final payload = <String, dynamic>{
      if (documentoLegalIds != null && documentoLegalIds.isNotEmpty)
        'documentoLegalIds': documentoLegalIds,
    };
    final headers = <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    try {
      await gateway.postJson(
        rutaConsentimientosLegales,
        payload,
        headers: headers,
      );
    } catch (e) {
      // La cuenta ya quedó creada: no se revierte el registro, pero el fallo no se oculta.
      // Sin datos personales en el log (solo el tipo de error).
      _log.error(
        'No se pudo registrar el consentimiento legal tras el registro',
        traceId: StructuredLogger.nuevoTraceId(),
        extra: {'error_type': e.runtimeType.toString()},
      );
    }
  }

  Future<void> _registrarConsentimientoSeguro(
    Map<String, dynamic> respuesta,
  ) async {
    final token = (respuesta['session'] is Map)
        ? respuesta['session']['access_token']?.toString()
        : (respuesta['access_token']?.toString() ??
              client.auth.currentSession?.accessToken);
    if (token != null && token.isNotEmpty) {
      await registrarConsentimientoLegal(token: token);
    }
  }

  @override
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.user == null) {
      throw const AuthException('No user returned');
    }
    return response.user!;
  }

  @override
  Future<Map<String, dynamic>> registrarClientePersonaNatural({
    required String email,
    required String password,
    required String nombreCompleto,
    required String tenantId,
    String? telefono,
    String? direccionHogar,
  }) async {
    // US-02.2.1-M2: migrado de Supabase directo (auth.signUp + .rpc()/.from()
    // de respaldo) al camino Gateway -> Core Node, igual que el registro de
    // Aliado (US-02.1.1-M2). Mismo GatewayClient (gateway), mismo endpoint
    // de identidad del lado de Core (CA-2): no se crea un segundo cliente
    // HTTP ni una segunda implementación de autenticación.
    //
    // direccionHogar queda sin enviar: la creación del `sitio` inicial
    // (hogar) que hacía la función PL/pgSQL legacy todavía no tiene
    // equivalente en Core Node (fuera del alcance de esta subtarea,
    // enfocada en reutilizar identidad/HTTP, no en portar `sitio`/`zona`).
    final campos = <String, dynamic>{
      'email': email.trim(),
      'password': password,
      'fullName': nombreCompleto.trim(),
      if (telefono != null && telefono.trim().isNotEmpty)
        'phone': telefono.trim(),
    };

    final respuesta = await gateway.postJson(
      rutaRegistroClientePersonaNatural,
      campos,
      headers: {headerTenantSlug: tenantId},
    );

    await _registrarConsentimientoSeguro(respuesta);

    return {
      ...respuesta,
      'success': true,
      'usuario_id': respuesta['profile']?['id'],
      'rol': respuesta['profile']?['role'],
      'estado': respuesta['profile']?['status'],
      'mensaje': 'Cuenta de cliente creada exitosamente.',
    };
  }

  @override
  Future<Map<String, dynamic>> registrarClienteEmpresa(
    RegistroClienteEmpresa datos,
  ) async {
    // El tenant va solo en X-Tenant-Slug (ADR-0018). Core registra la
    // aceptación de términos en la misma operación, por eso se envía
    // acceptsTerms (el cubit ya exige la casilla) y no se llama después a
    // /legal/consents, que la duplicaría.
    final campos = <String, dynamic>{
      'email': datos.email.trim(),
      'password': datos.password,
      'razonSocial': datos.razonSocial.trim(),
      'nit': datos.nit.trim(),
      'nombreRepresentante': datos.nombreRepresentante.trim(),
      'phone': ?_texto(datos.telefono),
      'acceptsTerms': true,
    };

    final respuesta = await gateway.postJson(
      rutaRegistroClienteEmpresa,
      campos,
      headers: {headerTenantSlug: datos.tenantId},
    );

    return {
      ...respuesta,
      'success': true,
      'usuario_id': respuesta['profile']?['id'],
      'rol': respuesta['profile']?['role'],
      'estado': respuesta['profile']?['status'],
      'mensaje': 'Cuenta de cliente empresa creada exitosamente.',
    };
  }

  @override
  Future<Map<String, dynamic>> registrarAliadoPersonaNatural({
    required String email,
    required String password,
    required String nombreCompleto,
    required String tenantId,
    required String categoriaId,
    required List<Map<String, String>> documentosKYC,
  }) async {
    // Tenant solo en X-Tenant-Slug y rutas de Storage construidas por Core
    // (ADR-0013, ADR-0018). Nombres de campo en camelCase: así los define el contrato
    // OpenAPI de CFG-16 (fullName/categoriaId), no snake_case español.
    // Core exige acceptsTerms en este registro (SCRUM-856, TERMS_NOT_ACCEPTED)
    // y registra él mismo la aceptación: el cubit ya exige la casilla y no se
    // llama después a /legal/consents, que la duplicaría.
    final campos = <String, String>{
      'email': email.trim(),
      'password': password,
      'fullName': nombreCompleto.trim(),
      'categoriaId': categoriaId.trim(),
      'acceptsTerms': 'true',
    };

    final respuesta = await gateway.postMultipart(
      rutaRegistroPersonaNatural,
      campos: campos,
      archivos: [for (final doc in documentosKYC) _archivo(doc)],
      headers: {headerTenantSlug: tenantId},
    );

    return {
      ...respuesta,
      'success': true,
      'estado_verificacion': respuesta['estado_verificacion'] ?? 'PENDIENTE',
    };
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
  }) async {
    // El tenant va solo en X-Tenant-Slug (ADR-0018), nunca en el cuerpo, y la ruta del
    // documento en Storage la construye Core (tenant_id/aliado_id/documento,
    // ADR-0013): el cliente no envía rutas. Campos en camelCase, como los
    // declara el contrato.
    final campos = <String, String>{
      'email': email.trim(),
      'password': password,
      'razonSocial': razonSocial.trim(),
      'nit': nit.trim(),
      'nombreRepresentante': nombreRepresentante.trim(),
      'docRepresentante': ?_texto(docRepresentante),
      'phone': ?_texto(telefonoContacto),
      'categoriaId': ?_texto(categoriaId),
    };

    final respuesta = await gateway.postMultipart(
      rutaRegistroEmpresa,
      campos: campos,
      archivos: [for (final doc in documentosKYC) _archivo(doc)],
      headers: {headerTenantSlug: tenantId},
    );

    await _registrarConsentimientoSeguro(respuesta);

    return {
      ...respuesta,
      'success': true,
      'estado_verificacion': respuesta['estado_verificacion'] ?? 'PENDIENTE',
    };
  }

  /// Convierte un documento KYC (`tipo_documento`, `nombre_archivo`,
  /// `contenido_base64`) en una parte multipart cuyo campo es el tipo en
  /// minúsculas, p. ej. `camara_comercio`.
  ArchivoMultipart _archivo(Map<String, String> doc) {
    final tipo = doc['tipo_documento'] ?? '';
    final contenido = doc['contenido_base64'];
    if (tipo.isEmpty || contenido == null || contenido.isEmpty) {
      throw GatewayException(
        message:
            'No se pudo leer el documento ${tipo.isEmpty ? '' : '$tipo '}'
            'adjunto. Vuelve a seleccionarlo.',
      );
    }
    final nombre = doc['nombre_archivo'] ?? tipo.toLowerCase();
    return ArchivoMultipart(
      campo: tipo.toLowerCase(),
      nombre: nombre,
      bytes: base64Decode(contenido),
      // Sin tipo, el navegador envía application/octet-stream y Core rechaza el
      // documento con 400 «Tipo de archivo no permitido» (QA, 22 nov).
      tipoContenido: tipoContenidoDocumento(nombre),
    );
  }

  /// MIME del documento KYC según su extensión: Core solo acepta PDF, JPG y PNG.
  /// Devuelve `null` con otra extensión, y Core responde con su propio mensaje.
  static String? tipoContenidoDocumento(String nombreArchivo) {
    final n = nombreArchivo.toLowerCase();
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.png')) return 'image/png';
    return null;
  }

  String? _texto(String? valor) {
    final limpio = valor?.trim();
    return limpio == null || limpio.isEmpty ? null : limpio;
  }

  /// Ruta con la que Core deja constancia del cierre de sesión (HU-M02-03, RNF-04).
  static const rutaCierreSesion = '/api/v1/core/auth/logout';

  @override
  Future<void> signOut() async {
    // Core solo audita: la sesión la revoca Supabase (T6). Si la llamada falla (sin red, token vencido, Core
    // caído) el cierre no se bloquea: la persona debe poder salir siempre.
    try {
      await gateway.postJson(rutaCierreSesion, const {});
    } catch (_) {}
    await client.auth.signOut();
  }
}
