import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

import '../widgets/detalle_aliado_panel.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

/// Detalle de un aliado en pantallas angostas. Requiere que el
/// `BandejaVerificacionCubit` de la bandeja esté disponible en el contexto.
class DetalleAliadoPage extends StatelessWidget {
  const DetalleAliadoPage({super.key, required this.aliadoId});

  final String aliadoId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ManiColors.background,

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManiEncabezadoPantalla(
            ancho: ManiAncho.panel,
            icono: Icons.person_rounded,
            titulo: 'Perfil del aliado',
          ),
          Expanded(
            child: ManiAnchoContenido(
              ancho: ManiAncho.panel,
              child: DetalleAliadoPanel(
                aliadoId: aliadoId,
                onResuelto: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
