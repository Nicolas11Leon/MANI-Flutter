import 'package:flutter/material.dart';

import 'package:mani/features/asignacion/domain/repositories/i_asignacion_repository.dart';
import 'package:mani/features/asignacion/domain/entities/solicitud_entity.dart';

/// Pantalla mínima del flujo de aceptación (RF-14).
///
/// Sirve de sujeto para la prueba de integración: un aliado ve una solicitud
/// pendiente, la acepta y la interfaz refleja el resultado del despacho.
class AceptarSolicitudPage extends StatefulWidget {
  const AceptarSolicitudPage({
    super.key,
    required this.repository,
    required this.solicitudId,
    required this.aliadoId,
  });

  final IAsignacionRepository repository;
  final String solicitudId;
  final String aliadoId;

  @override
  State<AceptarSolicitudPage> createState() => _AceptarSolicitudPageState();
}

class _AceptarSolicitudPageState extends State<AceptarSolicitudPage> {
  String _mensaje = 'Solicitud pendiente';
  bool _enCurso = false;

  Future<void> _aceptar() async {
    setState(() => _enCurso = true);
    String mensaje;
    try {
      final solicitud = await widget.repository.aceptar(
        widget.solicitudId,
        widget.aliadoId,
      );
      mensaje = 'Asignada a ${solicitud.aliadoId}';
    } on SolicitudNoDisponible {
      mensaje = 'Ya no disponible';
    } on SolicitudNoEncontrada {
      mensaje = 'Solicitud no encontrada';
    }
    if (!mounted) return;
    setState(() {
      _mensaje = mensaje;
      _enCurso = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Solicitud ${widget.solicitudId}')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_mensaje),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _enCurso ? null : _aceptar,
              child: const Text('Aceptar solicitud'),
            ),
          ],
        ),
      ),
    );
  }
}
