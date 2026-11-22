import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/features/services/categories/domain/entities/flujo_operativo.dart';
import 'package:mani/features/services/categories/domain/failures/categoria_failure.dart';
import 'package:mani/features/services/categories/presentation/pages/gestion_categorias_page.dart';

import '../fakes.dart';

const _escritorio = Size(1400, 900);
const _movil = Size(400, 860);

Future<void> _montar(
  WidgetTester t,
  FakeCategoriasRepository repo, {
  Size tamano = _escritorio,
}) async {
  t.view.physicalSize = tamano;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  final cubit = crearCubit(repo);
  addTearDown(cubit.close);
  await t.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: const GestionCategoriasPage(),
      ),
    ),
  );
  await cubit.cargar();
  await t.pumpAndSettle();
}

FakeCategoriasRepository _repoBase() => FakeCategoriasRepository([
  categoria('Plomería', aliados: 2),
  categoria('Cerrajería', activa: false, flujo: FlujoOperativo.tarifaEstandar),
]);

ManiButton _botonCrear(WidgetTester t) =>
    t.widget<ManiButton>(find.byKey(const ValueKey('btn-crear-categoria')));

Future<void> _tocar(WidgetTester t, Key key) async {
  await t.ensureVisible(find.byKey(key));
  await t.pumpAndSettle();
  await t.tap(find.byKey(key));
  await t.pumpAndSettle();
}

Future<void> _abrirFormulario(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('btn-nueva-categoria')));
  await t.pumpAndSettle();
}

/// Escribe el nombre y pulsa "Listo" en el teclado, como haría el usuario.
Future<void> _escribirNombre(WidgetTester t, String nombre) async {
  await t.enterText(
    find.byKey(const ValueKey('campo-nombre-categoria')),
    nombre,
  );
  await t.testTextInput.receiveAction(TextInputAction.done);
  await t.pumpAndSettle();
}

void main() {
  group('Catálogo', () {
    testWidgets('muestra las categorías con su flujo, visibilidad y aliados', (
      t,
    ) async {
      await _montar(t, _repoBase());

      expect(find.text('Tu catálogo de servicios'), findsOneWidget);
      expect(find.text('1 visible para clientes · 1 oculta'), findsOneWidget);
      expect(find.text('Plomería'), findsOneWidget);
      expect(find.text('Cotización previa'), findsOneWidget);
      expect(find.text('Tarifa estándar'), findsOneWidget);
      expect(find.text('Visible para clientes'), findsOneWidget);
      expect(find.text('Oculta'), findsOneWidget);
      expect(find.text('2 aliados'), findsOneWidget);
    });

    testWidgets('sin categorías invita a crear la primera', (t) async {
      await _montar(t, FakeCategoriasRepository());

      expect(find.text('Aún no tienes categorías'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('btn-primera-categoria')));
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.byKey(const ValueKey('campo-nombre-categoria')),
        findsOneWidget,
      );
    });

    testWidgets('la búsqueda filtra por nombre', (t) async {
      await _montar(t, _repoBase());

      await t.enterText(find.byKey(const ValueKey('buscar-categoria')), 'cerr');
      await t.pumpAndSettle();

      expect(find.text('Cerrajería'), findsOneWidget);
      expect(find.text('Plomería'), findsNothing);
    });

    testWidgets('error de carga ofrece reintentar', (t) async {
      final repo = _repoBase()
        ..fallarAlListar = const CategoriaFailure(
          CategoriaErrorTipo.noAutorizado,
        );
      await _montar(t, repo);

      expect(
        find.text(
          'Solo el administrador del tenant puede gestionar categorías.',
        ),
        findsOneWidget,
      );
      repo.fallarAlListar = null;
      await t.tap(find.byKey(const ValueKey('btn-reintentar-categorias')));
      await t.pumpAndSettle();
      expect(find.text('Plomería'), findsOneWidget);
    });
  });

  group('Formulario (escritorio)', () {
    testWidgets('Crear inicia deshabilitado y explica qué falta', (t) async {
      await _montar(t, _repoBase());
      await _abrirFormulario(t);

      expect(find.byType(Dialog), findsOneWidget);
      expect(_botonCrear(t).onPressed, isNull);
      expect(
        find.text('Escribe un nombre y elige cómo opera.'),
        findsOneWidget,
      );

      await _escribirNombre(t, 'Pintura');
      expect(
        find.text('Elige cómo opera la categoría para continuar.'),
        findsOneWidget,
      );
    });

    testWidgets('las sugerencias omiten lo que ya existe', (t) async {
      await _montar(t, _repoBase());
      await _abrirFormulario(t);

      expect(find.byKey(const ValueKey('sugerencia-Plomería')), findsNothing);
      expect(find.byKey(const ValueKey('sugerencia-Cerrajería')), findsNothing);
      expect(find.byKey(const ValueKey('sugerencia-Pintura')), findsOneWidget);
    });

    testWidgets('avisa en vivo si el nombre ya existe', (t) async {
      await _montar(t, _repoBase());
      await _abrirFormulario(t);

      await _escribirNombre(t, '  PLOMERÍA ');
      await _tocar(t, const ValueKey('flujo-COTIZACION_PREVIA'));

      expect(
        find.text('Ya tienes la categoría "Plomería" en tu catálogo.'),
        findsOneWidget,
      );
      expect(_botonCrear(t).onPressed, isNull);
    });

    testWidgets(
      'un nombre sin letras muestra el error al terminar de escribir',
      (t) async {
        await _montar(t, _repoBase());
        await _abrirFormulario(t);

        await _escribirNombre(t, '123');

        expect(
          find.text('Usa entre 3 y 60 caracteres, con al menos una letra.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('la vista previa refleja nombre, flujo y visibilidad', (
      t,
    ) async {
      await _montar(t, _repoBase());
      await _abrirFormulario(t);

      final previa = find.byKey(const ValueKey('vista-previa-categoria'));
      await _escribirNombre(t, 'Pintura');
      await _tocar(t, const ValueKey('flujo-TARIFA_ESTANDAR'));

      expect(
        find.descendant(of: previa, matching: find.text('Pintura')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: previa,
          matching: find.text('Precio fijo de referencia'),
        ),
        findsOneWidget,
      );

      await _tocar(t, const ValueKey('switch-visible'));
      expect(
        find.text('Oculta: tus clientes no la verán todavía.'),
        findsOneWidget,
      );
    });

    testWidgets('crea la categoría, cierra el diálogo y la resalta', (t) async {
      final repo = _repoBase();
      await _montar(t, repo);
      await _abrirFormulario(t);

      await _tocar(t, const ValueKey('sugerencia-Pintura'));
      await _tocar(t, const ValueKey('flujo-TARIFA_ESTANDAR'));
      expect(_botonCrear(t).onPressed, isNotNull);

      await _tocar(t, const ValueKey('btn-crear-categoria'));

      expect(find.byType(Dialog), findsNothing);
      expect(repo.ultimaCreada?.nombre, 'Pintura');
      expect(repo.ultimaCreada?.flujo, FlujoOperativo.tarifaEstandar);
      expect(repo.ultimaCreada?.activa, isTrue);
      expect(find.text('NUEVA'), findsOneWidget);
      expect(find.textContaining('Categoría "Pintura" creada'), findsOneWidget);
      expect(find.text('2 visibles para clientes · 1 oculta'), findsOneWidget);
    });

    testWidgets(
      'un error del servidor se muestra y el formulario sigue abierto',
      (t) async {
        final repo = _repoBase()
          ..fallarAlCrear = const CategoriaFailure(
            CategoriaErrorTipo.sinConexion,
          );
        await _montar(t, repo);
        await _abrirFormulario(t);

        await _escribirNombre(t, 'Pintura');
        await _tocar(t, const ValueKey('flujo-COTIZACION_PREVIA'));
        await _tocar(t, const ValueKey('btn-crear-categoria'));

        expect(find.byType(Dialog), findsOneWidget);
        expect(
          find.byKey(const ValueKey('error-envio-categoria')),
          findsOneWidget,
        );
        expect(find.textContaining('Sin conexión'), findsOneWidget);

        // Los datos no se pierden: reintentar funciona.
        repo.fallarAlCrear = null;
        await _tocar(t, const ValueKey('btn-crear-categoria'));
        expect(find.byType(Dialog), findsNothing);
      },
    );

    testWidgets('cancelar no crea nada', (t) async {
      final repo = _repoBase();
      await _montar(t, repo);
      await _abrirFormulario(t);

      await _tocar(t, const ValueKey('btn-cancelar-categoria'));

      expect(find.byType(Dialog), findsNothing);
      expect(repo.llamadasCrear, 0);
    });
  });

  testWidgets('en móvil el formulario abre como hoja inferior y crea', (
    t,
  ) async {
    final repo = _repoBase();
    await _montar(t, repo, tamano: _movil);

    await _abrirFormulario(t);
    expect(find.byType(BottomSheet), findsOneWidget);

    await _escribirNombre(t, 'Aire acondicionado');
    await _tocar(t, const ValueKey('flujo-COTIZACION_PREVIA'));
    await _tocar(t, const ValueKey('btn-crear-categoria'));

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Aire acondicionado'), findsOneWidget);
    expect(repo.guardadas, hasLength(3));
  });

  testWidgets(
    'US-03.1.2: permite ocultar y reactivar una categoría desde su tarjeta',
    (t) async {
      final repo = _repoBase();
      await _montar(t, repo);

      expect(find.text('1 visible para clientes · 1 oculta'), findsOneWidget);

      await _tocar(t, const ValueKey('toggle-estado-categoria-cat-plomería'));
      await _tocar(t, const ValueKey('confirmacion-confirmar'));

      expect(find.text('0 visibles para clientes · 2 ocultas'), findsOneWidget);
      expect(
        find.textContaining('los servicios en curso continúan sin cambios'),
        findsOneWidget,
      );

      await _tocar(t, const ValueKey('toggle-estado-categoria-cat-plomería'));

      expect(find.text('1 visible para clientes · 1 oculta'), findsOneWidget);
      expect(
        find.textContaining('Ya vuelve a aparecer en el catálogo'),
        findsOneWidget,
      );
    },
  );

  group('SCRUM-1650 — confirmación al desactivar', () {
    const togglePlomeria = ValueKey('toggle-estado-categoria-cat-plomería');
    const toggleCerrajeria = ValueKey('toggle-estado-categoria-cat-cerrajería');

    testWidgets('desactivar pide confirmación con nombre y consecuencias', (
      t,
    ) async {
      final repo = _repoBase();
      await _montar(t, repo);

      await _tocar(t, togglePlomeria);

      expect(find.text('¿Desactivar Plomería?'), findsOneWidget);
      expect(
        find.text(
          'Los clientes dejarán de verla en Nueva solicitud. '
          'Los servicios en curso no se afectan.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Desactivar'), findsOneWidget);
      expect(repo.llamadasCambiarEstado, 0, reason: 'aún no se confirma');
    });

    testWidgets('confirmar desactiva la categoría', (t) async {
      final repo = _repoBase();
      await _montar(t, repo);

      await _tocar(t, togglePlomeria);
      await _tocar(t, const ValueKey('confirmacion-confirmar'));

      expect(repo.llamadasCambiarEstado, 1);
      expect(find.text('¿Desactivar Plomería?'), findsNothing);
      expect(find.text('0 visibles para clientes · 2 ocultas'), findsOneWidget);
    });

    testWidgets('cancelar no llama a Core y deja la categoría visible', (
      t,
    ) async {
      final repo = _repoBase();
      await _montar(t, repo);

      await _tocar(t, togglePlomeria);
      await _tocar(t, const ValueKey('confirmacion-cancelar'));

      expect(repo.llamadasCambiarEstado, 0);
      expect(find.text('¿Desactivar Plomería?'), findsNothing);
      expect(find.text('1 visible para clientes · 1 oculta'), findsOneWidget);
      expect(find.text('Visible para clientes'), findsOneWidget);
    });

    testWidgets('activar una categoría oculta no muestra diálogo', (t) async {
      final repo = _repoBase();
      await _montar(t, repo);

      await _tocar(t, toggleCerrajeria);

      expect(find.byKey(const ValueKey('mani-confirmacion')), findsNothing);
      expect(repo.llamadasCambiarEstado, 1);
      expect(find.text('2 visibles para clientes'), findsOneWidget);
    });
  });
}
