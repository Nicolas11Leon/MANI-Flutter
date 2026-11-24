import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'app_shell.dart';

/// Títulos que las pantallas a la vista le piden mostrar al armazón (SCRUM-1647).
///
/// En celular el armazón ya trae una barra superior con «volver». Si además cada pantalla pone la suya, se ven dos
/// barras, dos títulos y dos flechas. Por eso la pantalla no dibuja barra: declara su título aquí y el armazón lo
/// muestra en la única que hay.
class TitulosDePantalla extends ChangeNotifier {
  final _declarados =
      <Object, ({String titulo, List<AccionDePantalla> acciones})>{};

  /// El título de la pantalla que está encima, o `null` si ninguna declaró uno.
  String? get actual =>
      _declarados.isEmpty ? null : _declarados.values.last.titulo;

  /// Las acciones de la pantalla que está encima (vacías si no declaró ninguna).
  List<AccionDePantalla> get acciones =>
      _declarados.isEmpty ? const [] : _declarados.values.last.acciones;

  void poner(
    Object quien,
    String titulo, [
    List<AccionDePantalla> acciones = const [],
  ]) {
    final previo = _declarados[quien];
    final esLaUltima = _declarados.isNotEmpty && _declarados.keys.last == quien;
    final igual =
        previo != null &&
        esLaUltima &&
        previo.titulo == titulo &&
        _mismasEtiquetas(previo.acciones, acciones);
    // Los `alTocar` se renuevan sin avisar: solo cambiar lo que se ve redibuja la barra.
    _declarados
      ..remove(quien)
      ..[quien] = (titulo: titulo, acciones: acciones);
    if (!igual) _avisar();
  }

  static bool _mismasEtiquetas(
    List<AccionDePantalla> a,
    List<AccionDePantalla> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].etiqueta != b[i].etiqueta || a[i].icono != b[i].icono) {
        return false;
      }
    }
    return true;
  }

  void quitar(Object quien) {
    if (_declarados.remove(quien) != null) _avisar();
  }

  // Las pantallas declaran su título mientras se arman; el armazón no puede redibujarse en ese instante.
  void _avisar() {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => notifyListeners())
      ..ensureVisualUpdate();
  }
}

/// Una acción de la pantalla que va en la barra del armazón (p. ej. «Historial»).
class AccionDePantalla {
  const AccionDePantalla({
    required this.icono,
    required this.etiqueta,
    required this.alTocar,
    this.clave,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback alTocar;
  final Key? clave;
}

/// Botones de la barra para [acciones]: con una, un botón de icono; con dos o más, un menú «⋮» con icono y texto.
List<Widget> botonesDeAcciones(List<AccionDePantalla> acciones) {
  if (acciones.isEmpty) return const [];
  if (acciones.length == 1) {
    final a = acciones.single;
    return [
      IconButton(
        key: a.clave,
        tooltip: a.etiqueta,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: a.alTocar,
        icon: Icon(a.icono),
      ),
    ];
  }
  return [
    PopupMenuButton<AccionDePantalla>(
      key: const Key('acciones-de-pantalla'),
      tooltip: 'Más opciones',
      icon: const Icon(Icons.more_vert),
      onSelected: (a) => a.alTocar(),
      itemBuilder: (_) => [
        for (final a in acciones)
          PopupMenuItem(
            key: a.clave,
            value: a,
            child: Row(
              children: [
                Icon(a.icono, size: 20),
                const SizedBox(width: 12),
                Flexible(child: Text(a.etiqueta)),
              ],
            ),
          ),
      ],
    ),
  ];
}

/// Títulos compartidos de la app.
final titulosDePantalla = TitulosDePantalla();

/// Declara [titulo] al armazón mientras la pantalla está a la vista. No dibuja nada.
class TituloDePantalla extends StatefulWidget {
  const TituloDePantalla({
    super.key,
    required this.titulo,
    this.acciones = const [],
    this.titulos,
  });

  final String titulo;

  /// Acciones de la pantalla para la barra del armazón.
  final List<AccionDePantalla> acciones;

  /// Dónde se declara; por omisión, los títulos compartidos de la app.
  final TitulosDePantalla? titulos;

  @override
  State<TituloDePantalla> createState() => _TituloDePantallaState();
}

class _TituloDePantallaState extends State<TituloDePantalla> {
  late TitulosDePantalla _titulos;

  @override
  void initState() {
    super.initState();
    _titulos = widget.titulos ?? titulosDePantalla;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _declarar();
  }

  @override
  void didUpdateWidget(TituloDePantalla anterior) {
    super.didUpdateWidget(anterior);
    _declarar();
  }

  // Una pestaña oculta u otra pantalla encima apagan los relojes de animación: con esa señal, solo la pantalla que
  // se ve mantiene su título.
  void _declarar() {
    if (TickerMode.valuesOf(context).enabled) {
      _titulos.poner(this, widget.titulo, widget.acciones);
    } else {
      _titulos.quitar(this);
    }
  }

  @override
  void dispose() {
    _titulos.quitar(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Barra superior de una pantalla con título.
///
/// Dentro del armazón y con ancho de celular no ocupa espacio: le pasa el título a la barra del armazón, que ya trae
/// la flecha de volver. En escritorio, o en una pantalla suelta, es la barra de siempre.
PreferredSizeWidget barraDePantalla(
  BuildContext context, {
  required String titulo,
  List<AccionDePantalla> acciones = const [],
}) {
  final enArmazon = context.findAncestorWidgetOfExactType<AppShell>() != null;
  final compacto = MediaQuery.sizeOf(context).width < anchoMenuExpandido;
  if (enArmazon && compacto) {
    return PreferredSize(
      preferredSize: Size.zero,
      child: TituloDePantalla(titulo: titulo, acciones: acciones),
    );
  }
  return AppBar(title: Text(titulo), actions: botonesDeAcciones(acciones));
}
