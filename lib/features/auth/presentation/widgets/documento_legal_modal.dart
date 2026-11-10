import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mani/core/widgets/mani_pulsable.dart';
import 'package:mani/core/network/gateway_client.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Tipo de documento legal expuesto durante el registro (SCRUM-856 / US-02.3.2).
enum TipoDocumentoLegal {
  terminosCondiciones(
    codigo: 'TERMINOS_CONDICIONES',
    titulo: 'Términos y Condiciones de Uso',
    version: '1.0',
  ),
  politicaDatos(
    codigo: 'POLITICA_DATOS',
    titulo: 'Política de Tratamiento de Datos Personales (Ley 1581)',
    version: '1.0',
  );

  const TipoDocumentoLegal({
    required this.codigo,
    required this.titulo,
    required this.version,
  });

  final String codigo;
  final String titulo;
  final String version;
}

/// Modal que permite al usuario leer el contenido completo de los Términos y
/// Condiciones y de la Política de Tratamiento de Datos Personales antes de
/// otorgar su consentimiento informado (SCRUM-856).
class DocumentoLegalModal extends StatefulWidget {
  const DocumentoLegalModal({
    super.key,
    this.documentoInicial = TipoDocumentoLegal.terminosCondiciones,
    this.onAceptar,
  });

  final TipoDocumentoLegal documentoInicial;
  final VoidCallback? onAceptar;

  static Future<bool?> mostrar(
    BuildContext context, {
    TipoDocumentoLegal documentoInicial =
        TipoDocumentoLegal.terminosCondiciones,
    VoidCallback? onAceptar,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DocumentoLegalModal(
        documentoInicial: documentoInicial,
        onAceptar: onAceptar,
      ),
    );
  }

  @override
  State<DocumentoLegalModal> createState() => _DocumentoLegalModalState();
}

class _DocumentoLegalModalState extends State<DocumentoLegalModal> {
  late TipoDocumentoLegal _seleccionado;
  List<Map<String, dynamic>> _documentosBackend = const [];

  @override
  void initState() {
    super.initState();
    _seleccionado = widget.documentoInicial;
    _cargarDocumentosActivos();
  }

  Future<void> _cargarDocumentosActivos() async {
    try {
      if (GetIt.instance.isRegistered<GatewayClient>()) {
        final gateway = GetIt.instance<GatewayClient>();
        final res = await gateway.get('/api/v1/core/legal/documents/active');
        final raw = res['data'];
        if (raw is List && raw.isNotEmpty && mounted) {
          setState(() {
            _documentosBackend = raw.whereType<Map<String, dynamic>>().toList();
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ManiColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: ManiRadius.brLg,
        side: const BorderSide(color: ManiColors.ink, width: 3),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(ManiSpace.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              ManiGap.vLg,
              _buildTabs(),
              ManiGap.vLg,
              Expanded(child: _buildDocumentBody()),
              ManiGap.vLg,
              _buildFooterActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(ManiSpace.sm),
          decoration: BoxDecoration(
            color: ManiColors.brand,
            borderRadius: ManiRadius.brSm,
            border: Border.all(
              color: ManiColors.border,
              width: ManiBorder.regular,
            ),
          ),
          child: const Icon(
            Icons.gavel_rounded,
            color: ManiColors.ink,
            size: 22,
          ),
        ),
        ManiGap.hMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documentos Legales y Habeas Data',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: ManiFontSize.title,
                  fontWeight: FontWeight.w900,
                  color: ManiColors.ink,
                ),
              ),
              Text(
                'Versión vigente ${_seleccionado.version} · Cumplimiento Ley 1581 de 2012',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: ManiFontSize.caption,
                  fontWeight: FontWeight.w600,
                  color: ManiColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('btn_cerrar_modal_legal'),
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close_rounded, color: ManiColors.ink),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(
          child: _buildTabButton(
            key: const Key('tab_terminos_condiciones'),
            tipo: TipoDocumentoLegal.terminosCondiciones,
            etiqueta: 'Términos y Condiciones',
          ),
        ),
        ManiGap.hSm,
        Expanded(
          child: _buildTabButton(
            key: const Key('tab_politica_datos'),
            tipo: TipoDocumentoLegal.politicaDatos,
            etiqueta: 'Política de Datos (Ley 1581)',
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required Key key,
    required TipoDocumentoLegal tipo,
    required String etiqueta,
  }) {
    final activo = _seleccionado == tipo;
    return ManiPulsable(
      key: key,
      onTap: () => setState(() => _seleccionado = tipo),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ManiSpace.md,
          vertical: ManiSpace.sm,
        ),
        decoration: BoxDecoration(
          color: activo ? ManiColors.brand : Colors.white,
          borderRadius: ManiRadius.brMd,
          border: Border.all(
            color: ManiColors.border,
            width: ManiBorder.regular,
          ),
          boxShadow: activo ? const [ManiShadow.sm] : const [],
        ),
        alignment: Alignment.center,
        child: Text(
          etiqueta,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: ManiFontSize.caption,
            fontWeight: FontWeight.w800,
            color: ManiColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentBody() {
    String contenido = _seleccionado == TipoDocumentoLegal.terminosCondiciones
        ? _textoTerminosCondiciones
        : _textoPoliticaDatos;
    String version = _seleccionado.version;

    for (final doc in _documentosBackend) {
      final tipo = (doc['tipo'] ?? '').toString().toUpperCase();
      if ((_seleccionado == TipoDocumentoLegal.terminosCondiciones &&
              (tipo.contains('TERMINOS') || tipo.contains('TERMS'))) ||
          (_seleccionado == TipoDocumentoLegal.politicaDatos &&
              (tipo.contains('DATOS') || tipo.contains('PRIVACY')))) {
        if (doc['contenido'] != null &&
            doc['contenido'].toString().isNotEmpty) {
          contenido = doc['contenido'].toString();
        }
        if (doc['version'] != null && doc['version'].toString().isNotEmpty) {
          version = doc['version'].toString();
        }
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(ManiSpace.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
      ),
      child: SingleChildScrollView(
        key: const Key('scroll_contenido_documento_legal'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _seleccionado.titulo,
              style: GoogleFonts.plusJakartaSans(
                fontSize: ManiFontSize.bodyLg,
                fontWeight: FontWeight.w900,
                color: ManiColors.ink,
              ),
            ),
            ManiGap.vXs,
            Text(
              'Código: ${_seleccionado.codigo} · Versión $version',
              style: GoogleFonts.plusJakartaSans(
                fontSize: ManiFontSize.micro,
                fontWeight: FontWeight.w700,
                color: ManiColors.inkMuted,
              ),
            ),
            const Divider(height: 20),
            Text(
              contenido,
              style: GoogleFonts.plusJakartaSans(
                fontSize: ManiFontSize.bodySm,
                height: 1.5,
                color: ManiColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'CERRAR',
            style: GoogleFonts.plusJakartaSans(
              fontSize: ManiFontSize.caption,
              fontWeight: FontWeight.w800,
              color: ManiColors.inkMuted,
            ),
          ),
        ),
        ManiGap.hMd,
        ManiPulsable(
          key: const Key('btn_confirmar_lectura_terminos'),
          onTap: () {
            widget.onAceptar?.call();
            Navigator.of(context).pop(true);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ManiSpace.xl,
              vertical: ManiSpace.md,
            ),
            decoration: BoxDecoration(
              color: ManiColors.brand,
              borderRadius: ManiRadius.brMd,
              border: Border.all(
                color: ManiColors.border,
                width: ManiBorder.regular,
              ),
              boxShadow: const [ManiShadow.sm],
            ),
            child: Text(
              'HE LEÍDO Y ACEPTO LOS DOCUMENTOS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: ManiFontSize.caption,
                fontWeight: FontWeight.w900,
                color: ManiColors.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static const String _textoTerminosCondiciones = '''
1. OBJETO Y ALCANCE DE LA PLATAFORMA MANI
MANI es una plataforma tecnológica multi-tenant que conecta clientes (personas naturales y empresas) con técnicos y aliados operativos verificados para la prestación de servicios de mantenimiento, reparación e instalaciones en sitio.

2. REGISTRO Y VERACIDAD DE LA INFORMACIÓN
El usuario declara que la información suministrada durante el registro es veraz, completa y actualizada. Para los perfiles de Aliado Técnico o Aliado Empresa, la activación operativa está sujeta a la verificación previa de los documentos KYC por parte del administrador del tenant.

3. OBLIGACIONES DE LOS USUARIOS Y REGLAS EN SITIO
Los clientes se comprometen a brindar condiciones seguras en el inmueble o sede registrada. Los aliados se comprometen a cumplir las reglas contextuales del sitio (seguridad industrial, horarios y protocolos de ingreso) y a ejecutar los servicios conforme a la cotización aprobada.

4. TRAZABILIDAD DEL CONSENTIMIENTO
Al aceptar, MANI guarda tu aceptación de la versión vigente de este documento junto con la fecha y hora, tu identificador de usuario y el tenant en el que te registras.
''';

  static const String _textoPoliticaDatos = '''
1. MARCO NORMATIVO (LEY 1581 DE 2012 Y DECRETO 1377 DE 2013)
En cumplimiento de la Ley Estatutaria 1581 de 2012 de Protección de Datos Personales (Habeas Data) y sus decretos reglamentarios, MANI informa que los datos recolectados serán tratados bajo estrictos controles de confidencialidad y aislamiento multi-tenant.

2. FINALIDADES DEL TRATAMIENTO
Los datos personales (nombre, identificación, correo electrónico, teléfono, direcciones de servicio y soportes KYC) se recolectan exclusivamente para:
• Gestionar el registro, autenticación y control de acceso por rol dentro del tenant.
• Coordinar la solicitud, cotización, despacho y ejecución de servicios en sitio.
• Verificar la idoneidad técnica y legal de los aliados registrados.
• Conservar la evidencia legal del consentimiento otorgado por el titular.

3. DERECHOS DEL TITULAR DE LOS DATOS
El titular podrá en cualquier momento conocer, actualizar, rectificar y solicitar la supresión de sus datos personales, así como revocar la autorización otorgada, mediante los canales de atención dispuestos por su tenant en la plataforma.

4. AISLAMIENTO Y SEGURIDAD
Cada tenant opera bajo políticas de Row-Level Security (RLS) y controles de acceso firmados criptográficamente, garantizando que la información personal no sea accesible entre organizaciones distintas.
''';
}
