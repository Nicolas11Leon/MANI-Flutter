import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

import '../widgets/detalle_aliado_panel.dart';
import 'package:mani/core/shell/titulo_de_pantalla.dart';

/// Detalle de un aliado en pantallas angostas. Requiere que el
/// `BandejaVerificacionCubit` de la bandeja esté disponible en el contexto.
class DetalleAliadoPage extends StatelessWidget {
  const DetalleAliadoPage({super.key, required this.aliadoId});

  final String aliadoId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: barraDePantalla(context, titulo: 'Perfil del aliado'),
      body: DetalleAliadoPanel(
        aliadoId: aliadoId,
        onResuelto: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
