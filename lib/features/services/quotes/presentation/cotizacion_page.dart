import 'package:mani/core/widgets/mani_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_card.dart';
import 'package:mani/core/widgets/mani_esqueleto.dart';
import 'package:mani/core/widgets/mani_estado.dart'
    hide ManiEstadoVacio, ManiEstadoError;
import 'package:mani/core/widgets/mani_estados.dart';

import '../domain/cotizacion.dart';
import 'cotizacion_cubit.dart';

/// Importe de la cotización: no negativo, hasta diez enteros y dos decimales,
/// el mismo formato que valida Core (DECIMAL(12,2)).
final _importeRe = RegExp(r'^\d{1,10}([.,]\d{1,2})?$');

/// `1234567.5` → `$ 1.234.567,50`.
String formatearPesos(double valor) {
  final partes = valor.toStringAsFixed(2).split('.');
  final enteros = partes[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '\$ $enteros,${partes[1]}';
}

/// Cotización de una solicitud (US-04.2.1 y US-04.2.3).
///
/// - Aliado asignado ([esAliado]): emite la cotización con mano de obra y
///   materiales separados. Puede emitir otra versión cuando el cliente pide
///   un ajuste (SCRUM-865).
/// - Cliente dueño: ve la versión vigente y la acepta, la rechaza con motivo o
///   pide un ajuste con comentario (SCRUM-867).
///
/// El total y la versión los calcula Core; la app solo muestra el total
/// mientras se escribe, como ayuda.
class CotizacionPage extends StatelessWidget {
  const CotizacionPage({
    super.key,
    required this.esAliado,
    this.encabezado,
    this.pie,
    this.alRefrescar,
    this.alPagar,
    this.accionEncabezado,
    this.pagosExtra,
    this.bitacora,
    this.calificacion,
    this.alertaTarifa,
  });

  final bool esAliado;

  /// Sección bajo el título (p. ej. la tarifa de referencia, SCRUM-886).
  final Widget? encabezado;

  /// Sección que va al final de la pantalla (p. ej. la ejecución, SCRUM-868).
  final Widget? pie;

  /// Se llama además de recargar la cotización al deslizar hacia abajo.
  final Future<void> Function()? alRefrescar;

  /// Abre el pago en el sandbox de una cotización aceptada (SCRUM-1432). Solo
  /// el cliente lo recibe; sin él no se ofrece el botón.
  final void Function(String cotizacionId, double total)? alPagar;

  /// Botón a la derecha del encabezado (p. ej. el chat del servicio).
  final Widget? accionEncabezado;

  /// Va en la columna de cotización y pagos, tras la cotización (p. ej. las
  /// adiciones, que cambian el total a pagar).
  final Widget? pagosExtra;

  /// Columna de ejecución y bitácora del servicio.
  final Widget? bitacora;

  /// Columna de la calificación del servicio.
  final Widget? calificacion;

  /// Sección bajo la cotización vigente (p. ej. la alerta de tarifa,
  /// SCRUM-866). Recibe el id de la versión vigente.
  final Widget Function(String cotizacionId)? alertaTarifa;

  /// Ancho desde el que las columnas van lado a lado.
  static const anchoTresColumnas = 1000.0;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CotizacionCubit, CotizacionState>(
      listenWhen: (a, b) => b.aviso != null && a.aviso != b.aviso,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.aviso!),
              backgroundColor: state.avisoEsError
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          );
      },
      builder: (context, state) {
        final cubit = context.read<CotizacionCubit>();
        final pagos = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (encabezado != null) ...[
              encabezado!,
              const SizedBox(height: 16),
            ],
            if (state.cargando && state.cotizaciones.isEmpty)
              ManiEsqueleto.detalle()
            else if (state.error != null)
              _Error(mensaje: state.error!, onReintentar: cubit.cargar)
            else ...[
              if (state.vigente != null) ...[
                _TarjetaCotizacion(state.vigente!, vigente: true),
                if (alertaTarifa != null) ...[
                  const SizedBox(height: 8),
                  alertaTarifa!(state.vigente!.id),
                ],
              ],
              if (esAliado)
                _SeccionAliado(state: state)
              else
                _SeccionCliente(state: state, alPagar: alPagar),
              if (state.cotizaciones.length > 1) ...[
                const SizedBox(height: 16),
                Text(
                  'Versiones anteriores',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final c in state.cotizaciones.skip(1))
                  _TarjetaCotizacion(c, vigente: false),
              ],
            ],
            if (pagosExtra != null) ...[
              const SizedBox(height: 16),
              pagosExtra!,
            ],
            if (pie != null) ...[const SizedBox(height: 16), pie!],
          ],
        );
        final columnas = <Widget>[
          _Columna(
            key: const Key('servicio-columna-pagos'),
            icono: Icons.payments_outlined,
            titulo: esAliado ? 'Cotización y cobro' : 'Cotización y pagos',
            child: pagos,
          ),
          if (bitacora != null)
            _Columna(
              key: const Key('servicio-columna-bitacora'),
              icono: Icons.timeline_outlined,
              titulo: 'Ejecución y bitácora',
              child: bitacora!,
            ),
          if (calificacion != null)
            _Columna(
              key: const Key('servicio-columna-calificacion'),
              icono: Icons.star_outline_rounded,
              titulo: 'Calificación del servicio',
              child: calificacion!,
            ),
        ];
        return RefreshIndicator(
          color: context.mani.ink,
          backgroundColor: context.mani.brand,
          onRefresh: () async {
            await Future.wait([cubit.cargar(), ?alRefrescar?.call()]);
          },
          child: LayoutBuilder(
            builder: (context, c) {
              final enColumnas =
                  columnas.length > 1 && c.maxWidth >= anchoTresColumnas;
              // Scroll que construye todo (no perezoso): cada columna es un
              // bloque alto que debe existir completo aunque quede fuera de vista.
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: c.maxWidth >= 600 ? 32 : 16,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _encabezado(),
                        const SizedBox(height: 24),
                        if (enColumnas)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var k = 0; k < columnas.length; k++) ...[
                                if (k > 0) const SizedBox(width: 24),
                                Expanded(child: columnas[k]),
                              ],
                            ],
                          )
                        else
                          for (var k = 0; k < columnas.length; k++) ...[
                            if (k > 0) const SizedBox(height: 28),
                            columnas[k],
                          ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _encabezado() {
    return ManiCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, c) {
          final titulo = Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.mani.brand,
                  borderRadius: BorderRadius.circular(ManiRadius.lg),
                  border: Border.all(color: context.mani.ink, width: 2),
                  boxShadow: const [ManiShadow.sm],
                ),
                child: Icon(
                  Icons.request_quote_outlined,
                  color: context.mani.onBrand,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  esAliado ? 'Cotizar el servicio' : 'Cotización del servicio',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: context.mani.ink,
                  ),
                ),
              ),
            ],
          );
          // En escritorio el botón va a la derecha del título; en móvil, debajo.
          if (accionEncabezado == null) return titulo;
          if (c.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titulo, const SizedBox(height: 14), accionEncabezado!],
            );
          }
          return Row(
            children: [
              Expanded(child: titulo),
              const SizedBox(width: 16),
              accionEncabezado!,
            ],
          );
        },
      ),
    );
  }
}

/// Columna de la pantalla del servicio: título con ícono en caja amarilla y
/// subrayado negro, y debajo sus tarjetas tal cual.
class _Columna extends StatelessWidget {
  const _Columna({
    super.key,
    required this.icono,
    required this.titulo,
    required this.child,
  });

  final IconData icono;
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.mani.ink, width: 2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.mani.brand,
                  borderRadius: BorderRadius.circular(ManiRadius.lg),
                  border: Border.all(color: context.mani.ink, width: 2),
                ),
                child: Icon(icono, color: context.mani.onBrand, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: context.mani.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _TarjetaCotizacion extends StatelessWidget {
  const _TarjetaCotizacion(this.c, {required this.vigente});

  final Cotizacion c;
  final bool vigente;

  @override
  Widget build(BuildContext context) {
    return ManiCard(
      key: Key('cotizacion-v${c.version}'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Versión ${c.version}',
                  style: TextStyle(
                    fontSize: vigente ? 16 : 14,
                    fontWeight: FontWeight.w800,
                    color: context.mani.ink,
                  ),
                ),
              ),
              ManiEstado(texto: c.etiquetaEstado, tono: _tonoDe(c.estado)),
            ],
          ),
          const SizedBox(height: 12),
          _Renglon('Mano de obra', formatearPesos(c.valorManoObra)),
          _Renglon('Materiales', formatearPesos(c.valorMateriales)),
          Divider(color: context.mani.borderSubtle, thickness: 1.0, height: 24),
          _Renglon('Total', formatearPesos(c.total), negrita: true),
        ],
      ),
    );
  }
}

ManiTono _tonoDe(EstadoCotizacion estado) => switch (estado) {
  EstadoCotizacion.aceptada => ManiTono.listo,
  EstadoCotizacion.rechazada || EstadoCotizacion.expirada => ManiTono.mal,
  EstadoCotizacion.pendiente ||
  EstadoCotizacion.ajusteSolicitado => ManiTono.atencion,
  EstadoCotizacion.otro => ManiTono.neutro,
};

/// Un renglón del desglose: etiqueta atenuada a la izquierda y valor con cifras tabulares a la derecha. El total, más
/// grande y en la fuente de títulos; no va en rojo: el rojo en una cifra de dinero se lee como deuda o error.
class _Renglon extends StatelessWidget {
  const _Renglon(this.etiqueta, this.valor, {this.negrita = false});

  final String etiqueta;
  final String valor;
  final bool negrita;

  @override
  Widget build(BuildContext context) {
    const tabular = [FontFeature.tabularFigures()];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: TextStyle(
                fontSize: 14,
                fontWeight: negrita ? FontWeight.w700 : FontWeight.w500,
                color: negrita ? context.mani.ink : context.mani.inkMuted,
              ),
            ),
          ),
          Text(
            valor,
            style: negrita
                ? AppTheme.titulo(
                    size: 22,
                    height: 28 / 22,
                    color: context.mani.ink,
                  ).copyWith(fontFeatures: tabular)
                : TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.mani.ink,
                    fontFeatures: tabular,
                  ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ aliado

class _SeccionAliado extends StatelessWidget {
  const _SeccionAliado({required this.state});

  final CotizacionState state;

  @override
  Widget build(BuildContext context) {
    final vigente = state.vigente;
    // Core admite una versión nueva cuando no hay ninguna pendiente y el
    // cliente no aceptó ni rechazó (SCRUM-865, MANI-COT-409P y 409E).
    if (vigente == null ||
        vigente.estado == EstadoCotizacion.ajusteSolicitado) {
      return _FormularioCotizacion(
        enviando: state.enviando,
        titulo: vigente == null
            ? 'Envía tu cotización al cliente'
            : 'El cliente pidió un ajuste: envía la versión ${vigente.version + 1}',
      );
    }
    final texto = switch (vigente.estado) {
      EstadoCotizacion.pendiente =>
        'Esperando la respuesta del cliente. Te avisaremos en tu bandeja.',
      EstadoCotizacion.aceptada => 'El cliente aceptó la cotización.',
      EstadoCotizacion.rechazada => 'El cliente rechazó la cotización.',
      _ => 'Esta cotización ya no admite cambios.',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(texto, key: const Key('estado-cotizacion-aliado')),
    );
  }
}

class _FormularioCotizacion extends StatefulWidget {
  const _FormularioCotizacion({required this.enviando, required this.titulo});

  final bool enviando;
  final String titulo;

  @override
  State<_FormularioCotizacion> createState() => _FormularioCotizacionState();
}

class _FormularioCotizacionState extends State<_FormularioCotizacion> {
  final _form = GlobalKey<FormState>();
  final _manoObra = TextEditingController();
  final _materiales = TextEditingController(text: '0');

  @override
  void dispose() {
    _manoObra.dispose();
    _materiales.dispose();
    super.dispose();
  }

  static String _normalizado(String v) => v.trim().replaceAll(',', '.');

  static double? _valor(String v) =>
      _importeRe.hasMatch(v.trim()) ? double.parse(_normalizado(v)) : null;

  String? _validar(String? v) {
    if (v == null || v.trim().isEmpty) return 'Obligatorio';
    if (!_importeRe.hasMatch(v.trim())) {
      return 'Valor no negativo con máximo dos decimales';
    }
    return null;
  }

  void _enviar() {
    if (!_form.currentState!.validate()) return;
    final total =
        (_valor(_manoObra.text) ?? 0) + (_valor(_materiales.text) ?? 0);
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El total debe ser mayor que cero')),
      );
      return;
    }
    context.read<CotizacionCubit>().emitir(
      valorManoObra: _normalizado(_manoObra.text),
      valorMateriales: _normalizado(_materiales.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formato = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return Form(
      key: _form,
      child: ManiCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.mani.brand,
                    borderRadius: BorderRadius.circular(ManiRadius.sm),
                    border: Border.all(color: context.mani.ink, width: 1.5),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: 18,
                    color: context.mani.onBrand,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.titulo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.mani.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final enFila = constraints.maxWidth > 460;
                final campoManoObra = ManiTextField(
                  key: const Key('campo-mano-obra'),
                  controller: _manoObra,
                  decoration: const InputDecoration(
                    labelText: 'Mano de obra',
                    prefixText: '\$ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: formato,
                  validator: _validar,
                  onChanged: (_) => setState(() {}),
                );
                final campoMateriales = ManiTextField(
                  key: const Key('campo-materiales'),
                  controller: _materiales,
                  decoration: const InputDecoration(
                    labelText: 'Materiales',
                    prefixText: '\$ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: formato,
                  validator: _validar,
                  onChanged: (_) => setState(() {}),
                );

                if (enFila) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: campoManoObra),
                      const SizedBox(width: 16),
                      Expanded(child: campoMateriales),
                    ],
                  );
                }
                return Column(
                  children: [
                    campoManoObra,
                    const SizedBox(height: 12),
                    campoMateriales,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.mani.background,
                borderRadius: BorderRadius.circular(ManiRadius.lg),
                border: Border.all(color: context.mani.ink, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total calculado:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.mani.ink,
                    ),
                  ),
                  Text(
                    'Total: ${formatearPesos((_valor(_manoObra.text) ?? 0) + (_valor(_materiales.text) ?? 0))}',
                    key: const Key('total-calculado'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: context.mani.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
                child: ManiButton(
                  key: const Key('btn-enviar-cotizacion'),
                  etiqueta: widget.enviando ? 'Enviando…' : 'Enviar cotización',
                  icono: Icons.send_rounded,
                  expandir: true,
                  cargando: widget.enviando,
                  onPressed: widget.enviando ? null : _enviar,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- cliente

class _SeccionCliente extends StatelessWidget {
  const _SeccionCliente({required this.state, this.alPagar});

  final CotizacionState state;
  final void Function(String cotizacionId, double total)? alPagar;

  @override
  Widget build(BuildContext context) {
    final vigente = state.vigente;
    if (vigente == null) {
      return const Text(
        'El aliado aún no ha enviado la cotización. Desliza hacia abajo para '
        'actualizar.',
        key: Key('sin-cotizacion'),
      );
    }
    if (!vigente.pendiente) {
      final texto = switch (vigente.estado) {
        EstadoCotizacion.ajusteSolicitado =>
          'Pediste un ajuste. El aliado enviará una nueva versión.',
        EstadoCotizacion.aceptada => 'Aceptaste esta cotización.',
        EstadoCotizacion.rechazada => 'Rechazaste esta cotización.',
        _ => 'Esta cotización ya no admite respuesta.',
      };
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(texto, key: const Key('estado-cotizacion-cliente')),
            if (vigente.estado == EstadoCotizacion.aceptada &&
                alPagar != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 180,
                    maxWidth: 260,
                  ),
                  child: ManiButton(
                    key: const Key('btn-pagar-cotizacion'),
                    etiqueta: 'Pagar (sandbox)',
                    icono: Icons.payments_outlined,
                    expandir: true,
                    onPressed: () => alPagar!(vigente.id, vigente.total),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }
    final cubit = context.read<CotizacionCubit>();
    final habilitado = !state.enviando;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManiButton(
            key: const Key('btn-aceptar-cotizacion'),
            etiqueta: 'Aceptar cotización',
            icono: Icons.check_rounded,
            expandir: true,
            cargando: state.enviando,
            onPressed: habilitado
                ? () => cubit.responder(DecisionCotizacion.aceptar)
                : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ManiButton(
                  key: const Key('btn-ajustar-cotizacion'),
                  etiqueta: 'Pedir ajuste',
                  icono: Icons.edit_note_rounded,
                  variante: ManiButtonVariante.secundario,
                  expandir: true,
                  onPressed: habilitado
                      ? () => _pedirTexto(
                          context,
                          titulo: 'Pedir ajuste',
                          etiqueta: '¿Qué debe cambiar el aliado?',
                          minimo: 3,
                          decision: DecisionCotizacion.ajustar,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ManiButton(
                  key: const Key('btn-rechazar-cotizacion'),
                  etiqueta: 'Rechazar',
                  variante: ManiButtonVariante.texto,
                  colorTexto: ManiColors.dangerText,
                  expandir: true,
                  onPressed: habilitado
                      ? () => _pedirTexto(
                          context,
                          titulo: 'Rechazar cotización',
                          etiqueta: 'Motivo del rechazo',
                          minimo: 5,
                          decision: DecisionCotizacion.rechazar,
                          peligro: true,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pedirTexto(
    BuildContext context, {
    required String titulo,
    required String etiqueta,
    required int minimo,
    required DecisionCotizacion decision,
    bool peligro = false,
  }) async {
    final cubit = context.read<CotizacionCubit>();
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoTexto(
        titulo: titulo,
        etiqueta: etiqueta,
        minimo: minimo,
        peligro: peligro,
      ),
    );
    if (texto != null) await cubit.responder(decision, texto: texto);
  }
}

class _DialogoTexto extends StatefulWidget {
  const _DialogoTexto({
    required this.titulo,
    required this.etiqueta,
    required this.minimo,
    this.peligro = false,
  });

  final String titulo;
  final String etiqueta;
  final int minimo;

  /// La decisión es destructiva (rechazar): el botón de confirmar va en rojo.
  final bool peligro;

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valido = _texto.text.trim().length >= widget.minimo;
    return AlertDialog(
      title: Text(widget.titulo),
      content: ManiTextField(
        key: const Key('campo-texto-decision'),
        controller: _texto,
        maxLength: 500,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: widget.etiqueta,
          helperText: 'Mínimo ${widget.minimo} caracteres',
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        ManiButton(
          etiqueta: 'Cancelar',
          variante: ManiButtonVariante.secundario,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ManiButton(
          key: const Key('btn-confirmar-decision'),
          etiqueta: 'Confirmar',
          variante: widget.peligro
              ? ManiButtonVariante.peligro
              : ManiButtonVariante.primario,
          onPressed: valido
              ? () => Navigator.of(context).pop(_texto.text.trim())
              : null,
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('error-cotizacion'),
      child: ManiEstadoError(texto: mensaje, alReintentar: onReintentar),
    );
  }
}
