import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mani/core/network/gateway_exception.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/features/services/categories/data/datasources/catalogo_publico_datasource.dart';

/// Selector de la especialidad del aliado con las categorías activas del
/// catálogo del tenant. Carga al construirse y muestra carga, error con
/// reintento o catálogo vacío; [onChanged] recibe `null` mientras no haya
/// una categoría válida elegida.
class SelectorCategoriaCatalogo extends StatefulWidget {
  const SelectorCategoriaCatalogo({
    super.key,
    required this.cargar,
    required this.value,
    required this.onChanged,
  });

  final Future<List<CategoriaPublica>> Function() cargar;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  State<SelectorCategoriaCatalogo> createState() =>
      _SelectorCategoriaCatalogoState();
}

class _SelectorCategoriaCatalogoState extends State<SelectorCategoriaCatalogo> {
  late Future<List<CategoriaPublica>> _categorias;

  @override
  void initState() {
    super.initState();
    _categorias = _cargar();
  }

  Future<List<CategoriaPublica>> _cargar() async {
    final categorias = await widget.cargar();
    // Si la categoría elegida ya no está en el catálogo, se descarta.
    if (widget.value != null && !categorias.any((c) => c.id == widget.value)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(null);
      });
    }
    return categorias;
  }

  void _reintentar() {
    final nuevo = _cargar();
    setState(() {
      _categorias = nuevo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CategoriaPublica>>(
      future: _categorias,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _contenedor(
            const Row(
              key: Key('categorias_cargando'),
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                ManiGap.hSm,
                Text('Cargando especialidades...'),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return _contenedor(
            Row(
              key: const Key('categorias_error'),
              children: [
                Expanded(
                  child: Text(
                    error is GatewayException
                        ? 'No pudimos cargar las especialidades. ${error.message}'
                        : 'No pudimos cargar las especialidades.',
                    style: _estilo(color: ManiColors.danger),
                  ),
                ),
                TextButton(
                  key: const Key('btn_reintentar_categorias'),
                  onPressed: _reintentar,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        final categorias = snapshot.data ?? const <CategoriaPublica>[];
        if (categorias.isEmpty) {
          return _contenedor(
            Text(
              'Este operador aún no tiene especialidades disponibles.',
              key: const Key('categorias_vacias'),
              style: _estilo(),
            ),
          );
        }
        final valor = categorias.any((c) => c.id == widget.value)
            ? widget.value
            : null;
        return _contenedor(
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('dropdown_categoria_aliado'),
              value: valor,
              hint: Text('Selecciona tu especialidad', style: _estilo()),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: ManiColors.ink),
              style: _estilo(),
              items: [
                for (final c in categorias)
                  DropdownMenuItem<String>(value: c.id, child: Text(c.nombre)),
              ],
              onChanged: widget.onChanged,
            ),
          ),
        );
      },
    );
  }

  TextStyle _estilo({Color color = ManiColors.ink}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: ManiFontSize.bodySm,
        fontWeight: FontWeight.w700,
        color: color,
      );

  Widget _contenedor(Widget child) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: ManiColors.surface,
      borderRadius: ManiRadius.brMd,
      border: Border.all(color: ManiColors.border, width: ManiBorder.regular),
    ),
    padding: const EdgeInsets.symmetric(horizontal: ManiSpace.md),
    child: child,
  );
}
