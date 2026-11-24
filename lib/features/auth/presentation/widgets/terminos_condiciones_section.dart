import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mani/core/widgets/mani_pulsable.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/features/auth/presentation/widgets/documento_legal_modal.dart';

/// Sección reutilizable de aceptación de Términos y Condiciones y Política de
/// Tratamiento de Datos Personales durante el registro (SCRUM-856 / SCRUM-1036).
///
/// Incluye:
/// - Checkbox obligatorio de consentimiento informado.
/// - Enlaces visibles para abrir el modal con el documento legal completo
///   ([DocumentoLegalModal], SCRUM-1037).
/// - Estado de error visual cuando se intenta enviar el formulario sin aceptar.
class TerminosCondicionesSection extends StatelessWidget {
  const TerminosCondicionesSection({
    super.key,
    required this.aceptaTerminos,
    required this.onChanged,
    this.mostrarError = false,
  });

  final bool aceptaTerminos;
  final ValueChanged<bool> onChanged;
  final bool mostrarError;

  Future<void> _abrirModal(
    BuildContext context,
    TipoDocumentoLegal tipo,
  ) async {
    await DocumentoLegalModal.mostrar(
      context,
      documentoInicial: tipo,
      onAceptar: () => onChanged(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('seccion_terminos_condiciones'),
      padding: const EdgeInsets.all(ManiSpace.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ManiRadius.brLg,
        border: Border.all(
          color: mostrarError ? ManiColors.danger : ManiColors.ink,
          width: mostrarError ? 2.5 : 2,
        ),
        boxShadow: const [ManiShadow.sm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  key: const Key('checkbox_aceptacion_terminos'),
                  value: aceptaTerminos,
                  activeColor: ManiColors.ink,
                  checkColor: ManiColors.brand,
                  side: BorderSide(
                    color: mostrarError ? ManiColors.danger : ManiColors.ink,
                    width: ManiBorder.regular,
                  ),
                  onChanged: (val) => onChanged(val ?? false),
                ),
              ),
              ManiGap.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consentimiento Legal y Protección de Datos (Obligatorio)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: ManiFontSize.bodySm,
                        fontWeight: FontWeight.w900,
                        color: ManiColors.ink,
                      ),
                    ),
                    ManiGap.vXs,
                    Text(
                      'He leído y acepto de manera libre, previa, expresa e informada los Términos y Condiciones (v1.0) y la Política de Tratamiento de Datos Personales conforme a la Ley 1581 de 2012 (Habeas Data).',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: ManiFontSize.caption,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: ManiColors.inkMuted,
                      ),
                    ),
                    ManiGap.vSm,
                    Wrap(
                      spacing: ManiSpace.sm,
                      runSpacing: ManiSpace.sm,
                      children: [
                        _buildDocLinkButton(
                          key: const Key('btn_ver_terminos'),
                          icon: Icons.description_outlined,
                          label: 'Leer Términos y Condiciones (v1.0)',
                          onTap: () => _abrirModal(
                            context,
                            TipoDocumentoLegal.terminosCondiciones,
                          ),
                        ),
                        _buildDocLinkButton(
                          key: const Key('btn_ver_politica_datos'),
                          icon: Icons.privacy_tip_outlined,
                          label: 'Leer Política de Datos (Ley 1581)',
                          onTap: () => _abrirModal(
                            context,
                            TipoDocumentoLegal.politicaDatos,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (mostrarError) ...[
            ManiGap.vSm,
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: ManiColors.danger,
                  size: 16,
                ),
                ManiGap.hSm,
                Expanded(
                  child: Text(
                    'Debes leer y aceptar los Términos y Condiciones y la Política de Datos Personales para completar el registro.',
                    key: const Key('error_terminos_obligatorios'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: ManiFontSize.caption,
                      fontWeight: FontWeight.w800,
                      color: ManiColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocLinkButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ManiPulsable(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ManiSpace.md,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: ManiColors.background,
          borderRadius: ManiRadius.brSm,
          border: Border.all(color: ManiColors.border, width: ManiBorder.thin),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: ManiColors.ink),
            ManiGap.hSm,
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: ManiFontSize.micro,
                fontWeight: FontWeight.w800,
                color: ManiColors.ink,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
