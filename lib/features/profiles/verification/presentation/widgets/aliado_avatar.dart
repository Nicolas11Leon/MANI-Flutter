import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';

import '../../domain/entities/solicitud_aliado.dart';

/// Avatar cuadrado con las iniciales del aliado; ícono de edificio si es empresa.
class AliadoAvatar extends StatelessWidget {
  const AliadoAvatar({super.key, required this.aliado, this.tamano = 48});

  final SolicitudAliado aliado;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final esEmpresa = aliado.tipo == TipoAliado.empresa;
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: esEmpresa ? ManiColors.infoContainer : context.mani.brand,
        borderRadius: ManiRadius.brMd,
        border: Border.all(
          color: context.mani.border,
          width: ManiBorder.regular,
        ),
      ),
      child: esEmpresa
          ? Icon(
              Icons.apartment_rounded,
              color: context.mani.ink,
              size: tamano * 0.5,
            )
          : Text(
              aliado.iniciales,
              style: TextStyle(
                fontSize: tamano * 0.36,
                fontWeight: FontWeight.w900,
                color: context.mani.ink,
              ),
            ),
    );
  }
}
