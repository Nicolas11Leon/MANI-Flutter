import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/entities/zona.dart';
import '../controllers/cobertura_controller.dart';
import '../widgets/resumen_cobertura_bar.dart';
import '../widgets/zona_tiles.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_estado.dart';
import 'package:mani/core/widgets/mani_pagina.dart';

/// US-02.1.4 — Declarar zona de cobertura (SCRUM-849).
///
/// Selector jerárquico ciudad → localidad → barrio (ADR-0011, QS-05). No hay
/// mapa de polígonos: ADR-0011 descartó geometría propia (ver documento de la
/// historia, hallazgo H-01).
class DeclararCoberturaPage extends StatefulWidget {
  const DeclararCoberturaPage({
    super.key,
    required this.controller,
    this.debounce = ManiMotion.slow,
  });

  final CoberturaController controller;
  final Duration debounce;

  @override
  State<DeclararCoberturaPage> createState() => _DeclararCoberturaPageState();
}

class _DeclararCoberturaPageState extends State<DeclararCoberturaPage> {
  final _busqueda = TextEditingController();
  Timer? _debounce;

  CoberturaController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_mostrarAviso);
    c.iniciar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    c.removeListener(_mostrarAviso);
    _busqueda.dispose();
    super.dispose();
  }

  void _mostrarAviso() {
    final aviso = c.tomarAviso();
    if (aviso == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(aviso)));
  }

  void _onBuscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, () => c.buscar(texto));
  }

  Future<bool> _confirmarSalida() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Tus cambios en la zona de cobertura se perderán.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    return salir ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => PopScope(
        canPop: !c.hayCambios,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final nav = Navigator.of(context);
          if (await _confirmarSalida()) {
            c.descartarCambios();
            nav.pop();
          }
        },
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ManiBarraPagina(
                icono: Icons.map_outlined,
                titulo: 'Zona de cobertura',
              ),
              Expanded(
                child: ManiAnchoContenido(
                  ancho: ManiAncho.lista,
                  child: _cuerpo(context),
                ),
              ),
            ],
          ),
          bottomNavigationBar: c.carga == EstadoCarga.listo
              ? ResumenCoberturaBar(controller: c)
              : null,
        ),
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    switch (c.carga) {
      case EstadoCarga.inicial:
      case EstadoCarga.cargando:
        return const Center(child: CircularProgressIndicator.adaptive());
      case EstadoCarga.error:
        return _ErrorCarga(
          mensaje: c.error?.mensajeUsuario ?? 'No pudimos cargar las zonas.',
          onReintentar: c.iniciar,
        );
      case EstadoCarga.listo:
        break;
    }

    final ciudad = c.ciudad;
    if (ciudad == null) {
      return const _Vacio(
        texto:
            'Todavía no hay zonas disponibles en el catálogo. Contacta al administrador.',
      );
    }

    final enBusqueda = c.consulta.trim().length >= 2;
    final localidades = c.hijasDe(ciudad.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ManiSpace.lg,
            ManiSpace.md,
            ManiSpace.lg,
            ManiSpace.xs,
          ),
          child: Text(
            c.esPrimeraDeclaracion
                ? 'Elige las localidades o barrios donde puedes trabajar. Solo recibirás solicitudes de clientes en esas zonas.'
                : 'Ajusta tus zonas. Los cambios aplican a las nuevas solicitudes; las que ya aceptaste no cambian.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (c.ciudades.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ManiSpace.lg,
              vertical: ManiSpace.xs,
            ),
            child: DropdownButtonFormField<String>(
              initialValue: ciudad.id,
              decoration: const InputDecoration(labelText: 'Ciudad'),
              items: [
                for (final z in c.ciudades)
                  DropdownMenuItem(value: z.id, child: Text(z.nombre)),
              ],
              onChanged: (id) {
                final nueva = c.ciudades.firstWhere((z) => z.id == id);
                _busqueda.clear();
                c.seleccionarCiudad(nueva);
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ManiSpace.lg,
            ManiSpace.sm,
            ManiSpace.lg,
            ManiSpace.xs,
          ),
          child: TextField(
            key: const ValueKey('buscar-zona'),
            controller: _busqueda,
            onChanged: _onBuscar,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Buscar barrio o localidad en ${ciudad.nombre}',
              suffixIcon: c.consulta.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _busqueda.clear();
                        c.limpiarBusqueda();
                      },
                    ),
            ),
          ),
        ),
        if (c.seleccion.desactivadas.isNotEmpty)
          _AvisoDesactivadas(controller: c),
        const Divider(height: 1),
        Expanded(
          child: enBusqueda
              ? _ListaBusqueda(controller: c)
              : ListView(
                  key: const PageStorageKey('lista-localidades'),
                  children: [
                    ZonaCheckTile(
                      zona: ciudad,
                      controller: c,
                      titulo: 'Toda ${ciudad.nombre}',
                      key: ValueKey('ciudad-completa-${ciudad.id}'),
                    ),
                    const Divider(height: 1),
                    if (localidades == null)
                      const Padding(
                        padding: EdgeInsets.all(ManiSpace.xxl),
                        child: Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      )
                    else if (localidades.isEmpty)
                      // KI-08: si la ciudad no tiene localidades se degrada a ciudad completa.
                      const _Vacio(
                        texto:
                            'Esta ciudad aún no tiene localidades en el catálogo. Selecciona la ciudad completa.',
                      )
                    else
                      for (final l in localidades)
                        l.tieneHijas
                            ? ZonaGrupoTile(zona: l, controller: c)
                            : ZonaCheckTile(zona: l, controller: c),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ListaBusqueda extends StatelessWidget {
  const _ListaBusqueda({required this.controller});
  final CoberturaController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.buscando && controller.resultados.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (controller.resultados.isEmpty) {
      return _Vacio(
        texto: 'No encontramos zonas con "${controller.consulta.trim()}".',
      );
    }
    return ListView(
      children: [
        for (final Zona z in controller.resultados)
          ZonaCheckTile(zona: z, controller: controller, mostrarRuta: true),
      ],
    );
  }
}

class _AvisoDesactivadas extends StatelessWidget {
  const _AvisoDesactivadas({required this.controller});
  final CoberturaController controller;

  @override
  Widget build(BuildContext context) {
    final n = controller.seleccion.desactivadas.length;
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        ManiSpace.lg,
        ManiSpace.sm,
        ManiSpace.lg,
        ManiSpace.xs,
      ),
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: ManiRadius.brMd,
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
          ManiGap.hSm,
          Expanded(
            child: Text(
              '$n ${n == 1 ? 'zona ya no está disponible' : 'zonas ya no están disponibles'} y no recibirás solicitudes de allí.',
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: controller.quitarDesactivadas,
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.mensaje, required this.onReintentar});
  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(ManiSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48),
          ManiGap.vMd,
          Text(mensaje, textAlign: TextAlign.center),
          ManiGap.vMd,
          FilledButton(
            onPressed: onReintentar,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) =>
      ManiEstadoVacio(icono: Icons.map_outlined, titulo: texto);
}
