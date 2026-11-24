import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/features/availability/domain/entities/ausencia.dart';

const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _dosDigitos(int n) => n.toString().padLeft(2, '0');

/// "lun 20 oct 2026".
String formatearFecha(DateTime f) =>
    '${_dias[f.weekday - 1]} ${f.day} ${_meses[f.month - 1]} ${f.year}';

/// "08:00".
String formatearHora(DateTime f) =>
    '${_dosDigitos(f.hour)}:${_dosDigitos(f.minute)}';

/// "lun 20 oct 2026, 08:00".
String formatearFechaHora(DateTime f) =>
    '${formatearFecha(f)}, ${formatearHora(f)}';

/// Formulario para crear o editar una ausencia. Valida en el cliente las
/// mismas reglas que Core y solo se cierra si [onGuardar] devuelve true.
class FormularioAusencia extends StatefulWidget {
  const FormularioAusencia({
    super.key,
    required this.ahora,
    required this.onGuardar,
    this.inicial,
    this.titulo = 'Marcar no disponible',
  });

  final DateTime ahora;
  final BorradorAusencia? inicial;
  final String titulo;
  final Future<bool> Function(BorradorAusencia borrador) onGuardar;

  @override
  State<FormularioAusencia> createState() => _FormularioAusenciaState();
}

class _FormularioAusenciaState extends State<FormularioAusencia> {
  late DateTime _inicio;
  late DateTime _fin;
  late MotivoAusencia _motivo;
  late final TextEditingController _nota;
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final inicial = widget.inicial;
    // Por defecto: desde la próxima hora en punto, durante un día.
    final proximaHora = DateTime(
      widget.ahora.year,
      widget.ahora.month,
      widget.ahora.day,
      widget.ahora.hour + 1,
    );
    _inicio = inicial?.inicio ?? proximaHora;
    _fin = inicial?.fin ?? proximaHora.add(const Duration(days: 1));
    _motivo = inicial?.motivo ?? MotivoAusencia.vacaciones;
    _nota = TextEditingController(text: inicial?.nota ?? '');
  }

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha({required bool esInicio}) async {
    final actual = esInicio ? _inicio : _fin;
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(widget.ahora.year - 1),
      lastDate: DateTime(widget.ahora.year + 2),
    );
    if (elegida == null) return;
    setState(() {
      final nueva = DateTime(
        elegida.year,
        elegida.month,
        elegida.day,
        actual.hour,
        actual.minute,
      );
      esInicio ? _inicio = nueva : _fin = nueva;
      _error = null;
    });
  }

  Future<void> _elegirHora({required bool esInicio}) async {
    final actual = esInicio ? _inicio : _fin;
    final elegida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(actual),
    );
    if (elegida == null) return;
    setState(() {
      final nueva = DateTime(
        actual.year,
        actual.month,
        actual.day,
        elegida.hour,
        elegida.minute,
      );
      esInicio ? _inicio = nueva : _fin = nueva;
      _error = null;
    });
  }

  Future<void> _guardar() async {
    final borrador = BorradorAusencia(
      inicio: _inicio,
      fin: _fin,
      motivo: _motivo,
      nota: _nota.text.trim().isEmpty ? null : _nota.text.trim(),
    );
    final error = borrador.validar(widget.ahora);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _guardando = true);
    final ok = await widget.onGuardar(borrador);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.titulo,
              style: TextStyle(
                fontSize: ManiFontSize.title,
                fontWeight: FontWeight.w900,
                color: context.mani.ink,
              ),
            ),
            ManiGap.vXs,
            Text(
              'Durante este intervalo no recibirás solicitudes nuevas.',
              style: TextStyle(
                fontSize: ManiFontSize.bodySm,
                color: context.mani.inkMuted,
              ),
            ),
            ManiGap.vLg,
            const _Etiqueta('Motivo'),
            Wrap(
              spacing: ManiSpace.sm,
              children: [
                for (final m in MotivoAusencia.values)
                  ChoiceChip(
                    key: ValueKey('motivo-${m.codigo}'),
                    label: Text(m.etiqueta),
                    selected: _motivo == m,
                    selectedColor: context.mani.brand,
                    side: ManiBorder.sideThin,
                    onSelected: (_) => setState(() => _motivo = m),
                  ),
              ],
            ),
            ManiGap.vLg,
            const _Etiqueta('Desde'),
            _SelectorFechaHora(
              prefijo: 'inicio',
              valor: _inicio,
              onFecha: () => _elegirFecha(esInicio: true),
              onHora: () => _elegirHora(esInicio: true),
            ),
            ManiGap.vMd,
            const _Etiqueta('Hasta'),
            _SelectorFechaHora(
              prefijo: 'fin',
              valor: _fin,
              onFecha: () => _elegirFecha(esInicio: false),
              onHora: () => _elegirHora(esInicio: false),
            ),
            ManiGap.vLg,
            const _Etiqueta('Nota (opcional)'),
            TextField(
              key: const ValueKey('nota-ausencia'),
              controller: _nota,
              maxLength: 280,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ej. Viaje familiar',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              Text(
                _error!,
                key: const ValueKey('error-formulario'),
                style: const TextStyle(
                  color: ManiColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ManiGap.vMd,
            ],
            ManiButton(
              key: const ValueKey('btn-guardar-ausencia'),
              etiqueta: 'Guardar',
              icono: Icons.check_rounded,
              cargando: _guardando,
              expandir: true,
              onPressed: _guardando ? null : _guardar,
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ManiSpace.sm),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: ManiFontSize.bodySm,
        fontWeight: FontWeight.w800,
        color: context.mani.ink,
      ),
    ),
  );
}

class _SelectorFechaHora extends StatelessWidget {
  const _SelectorFechaHora({
    required this.prefijo,
    required this.valor,
    required this.onFecha,
    required this.onHora,
  });

  final String prefijo;
  final DateTime valor;
  final VoidCallback onFecha;
  final VoidCallback onHora;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          key: ValueKey('$prefijo-fecha'),
          onPressed: onFecha,
          icon: Icon(
            Icons.calendar_today_rounded,
            size: 18,
            color: context.mani.ink,
          ),
          label: Text(
            formatearFecha(valor),
            style: TextStyle(color: context.mani.ink),
          ),
        ),
      ),
      ManiGap.hSm,
      OutlinedButton.icon(
        key: ValueKey('$prefijo-hora'),
        onPressed: onHora,
        icon: Icon(Icons.schedule_rounded, size: 18, color: context.mani.ink),
        label: Text(
          formatearHora(valor),
          style: TextStyle(color: context.mani.ink),
        ),
      ),
    ],
  );
}
