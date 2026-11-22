import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';

import '../../domain/entities/categoria_servicio.dart';
import '../../domain/entities/flujo_operativo.dart';
import '../../domain/entities/nueva_categoria.dart';
import '../../domain/failures/categoria_failure.dart';
import '../bloc/categorias_cubit.dart';
import 'flujo_operativo_estilo.dart';

/// Abre el formulario "Nueva categoría": diálogo en escritorio, hoja inferior
/// en móvil. Devuelve `true` si se creó la categoría.
Future<bool> mostrarFormularioCategoria(BuildContext context) async {
  final cubit = context.read<CategoriasCubit>();
  final contenido = BlocProvider.value(
    value: cubit,
    child: const FormularioCategoria(),
  );
  final bool? creada;
  if (MediaQuery.sizeOf(context).width >= 720) {
    creada = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: ManiColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: ManiRadius.brLg,
          side: const BorderSide(color: ManiColors.ink, width: 3),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
          child: contenido,
        ),
      ),
    );
  } else {
    creada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ManiColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ManiRadius.lg),
        ),
        side: ManiBorder.side,
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
          ),
          child: contenido,
        ),
      ),
    );
  }
  return creada ?? false;
}

class FormularioCategoria extends StatefulWidget {
  const FormularioCategoria({super.key});

  /// Nombres frecuentes; solo se sugieren los que el tenant aún no tiene.
  static const sugerencias = [
    'Plomería',
    'Electricidad',
    'Cerrajería',
    'Pintura',
    'Carpintería',
    'Aire acondicionado',
    'Jardinería',
    'Limpieza',
  ];

  @override
  State<FormularioCategoria> createState() => _FormularioCategoriaState();
}

class _FormularioCategoriaState extends State<FormularioCategoria> {
  final _nombre = TextEditingController();
  FlujoOperativo? _flujo;
  bool _activa = true;
  bool _nombreTocado = false;

  /// Error devuelto por el servidor en el último intento.
  CategoriaFailure? _errorEnvio;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  CategoriaServicio? _duplicada(List<CategoriaServicio> existentes) =>
      NuevaCategoria.buscarDuplicada(_nombre.text, existentes);

  String? _errorNombre(List<CategoriaServicio> existentes) {
    final duplicada = _duplicada(existentes);
    if (duplicada != null) {
      return 'Ya tienes la categoría "${duplicada.nombre}" en tu catálogo.';
    }
    if (_errorEnvio?.tipo == CategoriaErrorTipo.nombreDuplicado) {
      return _errorEnvio!.mensajeUsuario;
    }
    if (_nombreTocado && NuevaCategoria.validarNombre(_nombre.text) != null) {
      return 'Usa entre ${NuevaCategoria.nombreMinimo} y '
          '${NuevaCategoria.nombreMaximo} caracteres, con al menos una letra.';
    }
    return null;
  }

  void _usarSugerencia(String nombre) {
    _nombre.value = TextEditingValue(
      text: nombre,
      selection: TextSelection.collapsed(offset: nombre.length),
    );
    setState(() {
      _nombreTocado = true;
      _errorEnvio = null;
    });
  }

  Future<void> _crear() async {
    setState(() => _nombreTocado = true);
    final falla = await context.read<CategoriasCubit>().crear(
      nombre: _nombre.text,
      flujo: _flujo,
      activa: _activa,
    );
    if (!mounted) {
      return;
    }
    if (falla == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _errorEnvio = falla);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoriasCubit, CategoriasState>(
      buildWhen: (a, b) =>
          a.guardando != b.guardando || a.categorias != b.categorias,
      builder: (context, state) {
        final existentes = state.categorias;
        final errorNombre = _errorNombre(existentes);
        final nombreValido =
            NuevaCategoria.validarNombre(_nombre.text) == null &&
            _duplicada(existentes) == null;
        final puedeCrear = nombreValido && _flujo != null && !state.guardando;
        final errorGeneral = switch (_errorEnvio?.tipo) {
          null || CategoriaErrorTipo.nombreDuplicado => null,
          _ => _errorEnvio!.mensajeUsuario,
        };
        final clavesExistentes = existentes.map((c) => c.claveNombre).toSet();
        final sugerencias = FormularioCategoria.sugerencias
            .where((s) => !clavesExistentes.contains(normalizarClaveNombre(s)))
            .take(6)
            .toList();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Encabezado(onCerrar: () => Navigator.of(context).pop(false)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  ManiSpace.xxl,
                  ManiSpace.xs,
                  ManiSpace.xxl,
                  ManiSpace.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Paso(numero: 1, titulo: 'Nombre de la categoría'),
                    ManiGap.vSm,
                    TextField(
                      key: const ValueKey('campo-nombre-categoria'),
                      controller: _nombre,
                      autofocus: true,
                      maxLength: NuevaCategoria.nombreMaximo,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      enabled: !state.guardando,
                      onChanged: (_) => setState(() => _errorEnvio = null),
                      // Al sobrescribir onEditingComplete hay que cerrar el
                      // teclado a mano (el comportamiento por defecto se pierde).
                      onEditingComplete: () {
                        setState(() => _nombreTocado = true);
                        FocusScope.of(context).unfocus();
                      },
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      decoration: _decoracion(
                        hint: 'Ej: Plomería',
                        error: errorNombre,
                      ),
                    ),
                    if (sugerencias.isNotEmpty) ...[
                      ManiGap.vXs,
                      const Text(
                        'Sugerencias',
                        style: TextStyle(
                          fontSize: ManiFontSize.micro,
                          fontWeight: FontWeight.w800,
                          color: ManiColors.inkSubtle,
                        ),
                      ),
                      ManiGap.vSm,
                      Wrap(
                        spacing: ManiSpace.sm,
                        runSpacing: ManiSpace.sm,
                        children: [
                          for (final s in sugerencias)
                            ActionChip(
                              key: ValueKey('sugerencia-$s'),
                              label: Text(
                                s,
                                style: const TextStyle(
                                  fontSize: ManiFontSize.caption,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: state.guardando
                                  ? null
                                  : () => _usarSugerencia(s),
                              backgroundColor: ManiColors.surface,
                              side: ManiBorder.sideThin,
                              shape: RoundedRectangleBorder(
                                borderRadius: ManiRadius.brSm,
                              ),
                            ),
                        ],
                      ),
                    ],
                    ManiGap.vXxl,
                    const _Paso(
                      numero: 2,
                      titulo: '¿Cómo opera este servicio?',
                    ),
                    ManiGap.vXs,
                    const Text(
                      'Define qué pasa cuando un cliente solicita un servicio de esta categoría.',
                      style: TextStyle(
                        fontSize: ManiFontSize.caption,
                        color: ManiColors.inkMuted,
                      ),
                    ),
                    ManiGap.vSm,
                    for (final f in FlujoOperativo.values) ...[
                      _OpcionFlujo(
                        flujo: f,
                        seleccionado: _flujo == f,
                        onTap: state.guardando
                            ? null
                            : () => setState(() {
                                _flujo = f;
                                _errorEnvio = null;
                              }),
                      ),
                      ManiGap.vSm,
                    ],
                    ManiGap.vMd,
                    const _Paso(numero: 3, titulo: 'Visibilidad'),
                    ManiGap.vSm,
                    // Material propio: el ListTile pinta ahí su fondo y el
                    // efecto de toque (un Container con color los ocultaría).
                    Material(
                      color: ManiColors.surface,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: ManiRadius.brMd,
                        side: ManiBorder.side,
                      ),
                      child: SwitchListTile(
                        key: const ValueKey('switch-visible'),
                        value: _activa,
                        onChanged: state.guardando
                            ? null
                            : (v) => setState(() => _activa = v),
                        activeThumbColor: ManiColors.ink,
                        activeTrackColor: ManiColors.brand,
                        title: const Text(
                          'Visible para clientes de inmediato',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          _activa
                              ? 'Aparecerá en el catálogo apenas la crees.'
                              : 'Quedará oculta hasta que la actives.',
                          style: const TextStyle(
                            fontSize: ManiFontSize.caption,
                          ),
                        ),
                      ),
                    ),
                    ManiGap.vXl,
                    _VistaPrevia(
                      nombre: normalizarNombre(_nombre.text),
                      flujo: _flujo,
                      activa: _activa,
                    ),
                    if (errorGeneral != null) ...[
                      ManiGap.vLg,
                      _ErrorEnvio(mensaje: errorGeneral),
                    ],
                  ],
                ),
              ),
            ),
            _Acciones(
              puedeCrear: puedeCrear,
              guardando: state.guardando,
              pista: switch ((nombreValido, _flujo)) {
                _ when state.guardando || puedeCrear => null,
                (false, null) => 'Escribe un nombre y elige cómo opera.',
                (false, _) => 'Escribe un nombre válido para continuar.',
                (true, null) => 'Elige cómo opera la categoría para continuar.',
                _ => null,
              },
              onCancelar: () => Navigator.of(context).pop(false),
              onCrear: _crear,
            ),
          ],
        );
      },
    );
  }

  InputDecoration _decoracion({required String hint, String? error}) {
    OutlineInputBorder borde(Color color, double ancho) => OutlineInputBorder(
      borderRadius: ManiRadius.brMd,
      borderSide: BorderSide(color: color, width: ancho),
    );
    return InputDecoration(
      hintText: hint,
      helperText: 'Entre 3 y 60 caracteres. Es lo que verán tus clientes.',
      errorText: error,
      errorMaxLines: 2,
      filled: true,
      fillColor: ManiColors.surface,
      prefixIcon: const Icon(Icons.category_outlined, color: ManiColors.ink),
      enabledBorder: borde(ManiColors.ink, 2),
      focusedBorder: borde(ManiColors.ink, 2.5),
      disabledBorder: borde(ManiColors.borderSubtle, 2),
      errorBorder: borde(ManiColors.danger, 2),
      focusedErrorBorder: borde(ManiColors.danger, 2.5),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.onCerrar});

  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ManiSpace.xxl,
        ManiSpace.xl,
        ManiSpace.md,
        ManiSpace.sm,
      ),
      child: Row(
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
              Icons.add_business_rounded,
              color: ManiColors.ink,
            ),
          ),
          ManiGap.hMd,
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nueva categoría',
                  style: TextStyle(
                    fontSize: ManiFontSize.title,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Organiza el catálogo que ven tus clientes.',
                  style: TextStyle(
                    fontSize: ManiFontSize.caption,
                    color: ManiColors.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: onCerrar,
            icon: const Icon(Icons.close_rounded, color: ManiColors.ink),
          ),
        ],
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.numero, required this.titulo});

  final int numero;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: ManiColors.ink,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$numero',
            style: const TextStyle(
              fontSize: ManiFontSize.caption,
              fontWeight: FontWeight.w900,
              color: ManiColors.brand,
            ),
          ),
        ),
        ManiGap.hSm,
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: ManiFontSize.body,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta seleccionable de un flujo operativo (comportamiento de radio).
class _OpcionFlujo extends StatelessWidget {
  const _OpcionFlujo({
    required this.flujo,
    required this.seleccionado,
    required this.onTap,
  });

  final FlujoOperativo flujo;
  final bool seleccionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radio = ManiRadius.brMd;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: seleccionado,
      button: true,
      label: '${flujo.etiqueta}. ${flujo.descripcion}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: ManiMotion.fast,
        decoration: BoxDecoration(
          color: seleccionado ? flujo.fondo : ManiColors.surface,
          borderRadius: radio,
          border: Border.all(
            color: ManiColors.border,
            width: seleccionado ? 2.5 : 1.5,
          ),
          boxShadow: [if (seleccionado) ManiShadow.sm],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('flujo-${flujo.codigo}'),
            borderRadius: radio,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(ManiSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(ManiSpace.sm),
                    decoration: BoxDecoration(
                      color: seleccionado ? ManiColors.surface : flujo.fondo,
                      borderRadius: ManiRadius.brSm,
                      border: Border.all(
                        color: ManiColors.border,
                        width: ManiBorder.thin,
                      ),
                    ),
                    child: Icon(flujo.icono, color: flujo.acento, size: 22),
                  ),
                  ManiGap.hMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flujo.etiqueta,
                          style: const TextStyle(
                            fontSize: ManiFontSize.body,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        ManiGap.vXxs,
                        Text(
                          flujo.descripcion,
                          style: const TextStyle(
                            fontSize: ManiFontSize.caption,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        ManiGap.vXs,
                        Text(
                          flujo.ejemplo,
                          style: const TextStyle(
                            fontSize: ManiFontSize.micro,
                            fontStyle: FontStyle.italic,
                            color: ManiColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ManiGap.hSm,
                  Icon(
                    seleccionado
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: ManiColors.ink,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Así la verán tus clientes": refuerza el efecto de cada elección.
class _VistaPrevia extends StatelessWidget {
  const _VistaPrevia({
    required this.nombre,
    required this.flujo,
    required this.activa,
  });

  final String nombre;
  final FlujoOperativo? flujo;
  final bool activa;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('vista-previa-categoria'),
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: ManiColors.brandSoft,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: ManiColors.border, width: ManiBorder.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ASÍ LA VERÁN TUS CLIENTES',
            style: TextStyle(
              fontSize: ManiFontSize.nano,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: ManiColors.inkMuted,
            ),
          ),
          ManiGap.vSm,
          if (!activa)
            const Row(
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  size: 18,
                  color: ManiColors.inkMuted,
                ),
                ManiGap.hSm,
                Expanded(
                  child: Text(
                    'Oculta: tus clientes no la verán todavía.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(ManiSpace.md),
              decoration: BoxDecoration(
                color: ManiColors.surface,
                borderRadius: ManiRadius.brSm,
                border: Border.all(
                  color: ManiColors.border,
                  width: ManiBorder.thin,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.home_repair_service_rounded,
                    color: ManiColors.ink,
                  ),
                  ManiGap.hSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre.isEmpty ? 'Nombre de la categoría' : nombre,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: nombre.isEmpty
                                ? ManiColors.inkSubtle
                                : ManiColors.ink,
                          ),
                        ),
                        Text(
                          flujo?.textoCliente ?? 'Elige cómo opera el servicio',
                          style: const TextStyle(
                            fontSize: ManiFontSize.caption,
                            color: ManiColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: ManiColors.inkSubtle,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorEnvio extends StatelessWidget {
  const _ErrorEnvio({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('error-envio-categoria'),
      padding: const EdgeInsets.all(ManiSpace.md),
      decoration: BoxDecoration(
        color: ManiColors.dangerContainer,
        borderRadius: ManiRadius.brMd,
        border: Border.all(color: ManiColors.danger, width: ManiBorder.thin),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: ManiColors.danger),
          ManiGap.hSm,
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Acciones extends StatelessWidget {
  const _Acciones({
    required this.puedeCrear,
    required this.guardando,
    required this.onCancelar,
    required this.onCrear,
    this.pista,
  });

  final bool puedeCrear;
  final bool guardando;
  final VoidCallback onCancelar;
  final VoidCallback onCrear;

  /// Qué falta para habilitar "Crear categoría".
  final String? pista;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ManiSpace.xxl,
        ManiSpace.md,
        ManiSpace.xxl,
        ManiSpace.lg,
      ),
      decoration: const BoxDecoration(border: Border(top: ManiBorder.side)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pista != null) ...[
              Text(
                pista!,
                key: const ValueKey('pista-formulario-categoria'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: ManiFontSize.caption,
                  fontWeight: FontWeight.w600,
                  color: ManiColors.inkMuted,
                ),
              ),
              ManiGap.vSm,
            ],
            _botones(),
          ],
        ),
      ),
    );
  }

  Widget _botones() {
    return Row(
      children: [
        Expanded(
          child: ManiButton(
            key: const ValueKey('btn-cancelar-categoria'),
            etiqueta: 'Cancelar',
            variante: ManiButtonVariante.secundario,
            expandir: true,
            onPressed: guardando ? null : onCancelar,
          ),
        ),
        ManiGap.hMd,
        Expanded(
          flex: 2,
          child: ManiButton(
            key: const ValueKey('btn-crear-categoria'),
            etiqueta: guardando ? 'Creando…' : 'Crear categoría',
            icono: Icons.check_rounded,
            expandir: true,
            cargando: guardando,
            onPressed: puedeCrear ? onCrear : null,
          ),
        ),
      ],
    );
  }
}
