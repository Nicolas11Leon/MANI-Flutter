import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/features/profile_categories/domain/failures/categories_failure.dart';
import 'package:mani/features/profile_categories/presentation/pages/categories_page.dart';

import 'fakes.dart';

Widget _app(FakeCategoriesRepository repo) => MaterialApp(
  home: BlocProvider(
    create: (_) => cubitCon(repo),
    child: const CategoriesView(),
  ),
);

Finder _check(String id) => find.descendant(
  of: find.byKey(ValueKey('categoria-$id')),
  matching: find.byIcon(Icons.check),
);

void main() {
  testWidgets(
    'muestra las categorías del tenant con las ya declaradas marcadas',
    (t) async {
      await t.pumpWidget(_app(FakeCategoriesRepository(guardadas: {'c-ele'})));
      await t.pumpAndSettle();

      expect(find.text('Plomería'), findsOneWidget);
      expect(find.text('Electricidad'), findsOneWidget);
      expect(find.text('Cerrajería'), findsOneWidget);
      expect(_check('c-ele'), findsOneWidget);
      expect(_check('c-plo'), findsNothing);
      expect(find.text('1 seleccionada'), findsOneWidget);
    },
  );

  testWidgets('tocar una categoría la marca y guardar envía la selección', (
    t,
  ) async {
    final repo = FakeCategoriesRepository();
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('categoria-c-plo')));
    await t.tap(find.byKey(const ValueKey('categoria-c-cer')));
    await t.pump();
    expect(_check('c-plo'), findsOneWidget);
    expect(find.text('2 seleccionadas'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('btn-guardar-categorias')));
    await t.pumpAndSettle();

    expect(repo.ultimoEnvio, {'c-plo', 'c-cer'});
    expect(find.text('Especialidades guardadas'), findsOneWidget);
  });

  testWidgets(
    'sin selección el botón queda deshabilitado, se indica qué falta y no se llama al backend',
    (t) async {
      final repo = FakeCategoriesRepository();
      await t.pumpWidget(_app(repo));
      await t.pumpAndSettle();

      await t.tap(
        find.byKey(const ValueKey('btn-guardar-categorias')),
        warnIfMissed: false,
      );
      await t.pump();

      expect(find.text('Elige al menos una para continuar.'), findsOneWidget);
      expect(repo.llamadasGuardar, 0);
    },
  );

  // SCRUM-1632: antes se exigía que la categoría rechazada quedara marcada.
  // Eso hacía creer al aliado que la había declarado y al recargar desaparecía.
  testWidgets(
    'un error del servidor se muestra y desmarca lo que no se guardó',
    (t) async {
      final repo = FakeCategoriesRepository(
        fallaGuardado: const CategoriesFailure(
          CategoriesErrorTipo.categoriaNoDisponible,
        ),
      );
      await t.pumpWidget(_app(repo));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('categoria-c-plo')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('btn-guardar-categorias')));
      await t.pumpAndSettle();

      expect(find.textContaining('ya no están disponibles'), findsOneWidget);
      expect(_check('c-plo'), findsNothing);
    },
  );

  testWidgets('sin conexión el error se muestra pero la selección sigue ahí', (
    t,
  ) async {
    final repo = FakeCategoriesRepository(
      fallaGuardado: const CategoriesFailure(CategoriesErrorTipo.sinConexion),
    );
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('categoria-c-plo')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('btn-guardar-categorias')));
    await t.pumpAndSettle();

    expect(find.textContaining('Sin conexión'), findsOneWidget);
    expect(_check('c-plo'), findsOneWidget);
  });

  testWidgets('error de carga ofrece reintentar', (t) async {
    final repo = FakeCategoriesRepository(
      fallaCarga: const CategoriesFailure(CategoriesErrorTipo.sinConexion),
    );
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();

    expect(find.textContaining('Sin conexión'), findsOneWidget);

    repo.fallaCarga = null;
    await t.tap(find.byKey(const ValueKey('btn-reintentar-categorias')));
    await t.pumpAndSettle();

    expect(find.text('Plomería'), findsOneWidget);
  });

  testWidgets('al tocar una ficha cambia su estado semántico', (t) async {
    final sem = t.ensureSemantics();
    await t.pumpWidget(_app(FakeCategoriesRepository()));
    await t.pumpAndSettle();

    expect(
      t.getSemantics(find.bySemanticsLabel('Plomería')),
      isSemantics(isChecked: false, hasCheckedState: true),
    );
    await t.tap(find.byKey(const ValueKey('categoria-c-plo')));
    await t.pump();
    expect(
      t.getSemantics(find.bySemanticsLabel('Plomería')),
      isSemantics(isChecked: true, hasCheckedState: true),
    );
    sem.dispose();
  });
}
