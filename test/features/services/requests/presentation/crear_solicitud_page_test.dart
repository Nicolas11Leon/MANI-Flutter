import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/features/services/requests/domain/entities/nueva_solicitud.dart';
import 'package:mani/features/services/requests/domain/failures/solicitud_failure.dart';
import 'package:mani/features/services/requests/presentation/pages/crear_solicitud_page.dart';

import '../fakes.dart';

const _movil = Size(420, 900);
const _escritorio = Size(1300, 900);

Future<void> _montar(
  WidgetTester t,
  FakeSolicitudesClienteRepository repo, {
  FakeSelectorFotos? selector,
  VoidCallback? onIrAMisSolicitudes,
  Size tamano = _movil,
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
        child: CrearSolicitudPage(
          selectorFotos: selector ?? FakeSelectorFotos(),
          onIrAMisSolicitudes: onIrAMisSolicitudes,
          esperaBusqueda: Duration.zero,
        ),
      ),
    ),
  );
  await cubit.cargar();
  await t.pumpAndSettle();
}

Future<void> _tocar(WidgetTester t, Key key) async {
  await t.ensureVisible(find.byKey(key));
  await t.pumpAndSettle();
  await t.tap(find.byKey(key));
  await t.pumpAndSettle();
}

Future<void> _escribir(WidgetTester t, Key key, String texto) async {
  await t.enterText(find.byKey(key), texto);
  await t.testTextInput.receiveAction(TextInputAction.done);
  await t.pumpAndSettle();
}

ManiButton _boton(WidgetTester t, String clave) =>
    t.widget<ManiButton>(find.byKey(ValueKey(clave)));

void main() {
  testWidgets('paso 1 muestra los servicios del tenant y qué recibirá', (
    t,
  ) async {
    await _montar(t, FakeSolicitudesClienteRepository());

    expect(find.text('Nueva solicitud'), findsOneWidget);
    expect(find.text('¿Qué servicio necesitas?'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 1 de 4: Servicio'), findsOneWidget);
    expect(find.text('Plomería'), findsOneWidget);
    expect(find.text('Recibirás cotizaciones de los aliados'), findsOneWidget);
    expect(find.text('Precio fijo de referencia'), findsOneWidget);
    expect(find.byKey(const ValueKey('btn-continuar')), findsNothing);
  });

  testWidgets('elegir un servicio avanza al paso del problema', (t) async {
    await _montar(t, FakeSolicitudesClienteRepository());

    await _tocar(t, const ValueKey('categoria-cat-plo'));

    expect(find.text('Cuéntanos el problema'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 2 de 4: Problema'), findsOneWidget);
  });

  testWidgets(
    'la descripción guía al usuario y habilita Continuar al estar completa',
    (t) async {
      await _montar(t, FakeSolicitudesClienteRepository());
      await _tocar(t, const ValueKey('categoria-cat-plo'));

      expect(_boton(t, 'btn-continuar').onPressed, isNull);
      expect(find.text('Describe el problema para continuar.'), findsOneWidget);

      await _escribir(t, const ValueKey('campo-descripcion'), 'Gotea');
      expect(find.text('Escribe al menos 15 caracteres más.'), findsOneWidget);

      await _escribir(
        t,
        const ValueKey('campo-descripcion'),
        descripcionValida,
      );
      expect(find.text('¡Bien! Tu descripción está completa.'), findsOneWidget);
      expect(_boton(t, 'btn-continuar').onPressed, isNotNull);
    },
  );

  testWidgets('las fotos se agregan con miniatura, contador y se quitan', (
    t,
  ) async {
    final selector = FakeSelectorFotos([foto('fuga.jpg'), foto('tubo.png')]);
    await _montar(t, FakeSolicitudesClienteRepository(), selector: selector);
    await _tocar(t, const ValueKey('categoria-cat-plo'));

    await _tocar(t, const ValueKey('btn-agregar-fotos'));

    expect(selector.aperturas, 1);
    expect(find.text('2/5'), findsOneWidget);
    expect(find.byKey(const ValueKey('foto-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('foto-1')), findsOneWidget);

    await _tocar(t, const ValueKey('quitar-foto-0'));
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('al llegar a 5 fotos desaparece el botón de agregar', (t) async {
    final selector = FakeSelectorFotos(
      List.generate(NuevaSolicitud.maxFotos, (i) => foto('f$i.jpg')),
    );
    await _montar(t, FakeSolicitudesClienteRepository(), selector: selector);
    await _tocar(t, const ValueKey('categoria-cat-plo'));

    await _tocar(t, const ValueKey('btn-agregar-fotos'));

    expect(find.text('5/5'), findsOneWidget);
    expect(find.byKey(const ValueKey('btn-agregar-fotos')), findsNothing);
  });

  testWidgets('una foto inválida se explica sin perder las demás', (t) async {
    final selector = FakeSelectorFotos([foto('ok.jpg'), foto('doc.pdf')]);
    await _montar(t, FakeSolicitudesClienteRepository(), selector: selector);
    await _tocar(t, const ValueKey('categoria-cat-plo'));

    await _tocar(t, const ValueKey('btn-agregar-fotos'));

    expect(find.text('1/5'), findsOneWidget);
    expect(find.textContaining('JPG, PNG o WEBP'), findsWidgets);
  });

  testWidgets('ubicación: dirección guardada o nueva con buscador de barrio', (
    t,
  ) async {
    await _montar(t, FakeSolicitudesClienteRepository());
    await _tocar(t, const ValueKey('categoria-cat-plo'));
    await _escribir(t, const ValueKey('campo-descripcion'), descripcionValida);
    await _tocar(t, const ValueKey('btn-continuar'));

    expect(find.text('¿Dónde es el servicio?'), findsOneWidget);
    expect(find.text('Calle Colima 120, Apto 401'), findsOneWidget);
    expect(
      _boton(t, 'btn-continuar').onPressed,
      isNotNull,
      reason: 'propuesta',
    );

    await _tocar(t, const ValueKey('opcion-nueva-direccion'));
    expect(_boton(t, 'btn-continuar').onPressed, isNull);
    await _escribir(t, const ValueKey('campo-direccion'), 'Calle Durango 45');
    expect(
      find.text('Escribe la dirección y elige el barrio.'),
      findsOneWidget,
    );

    await _escribir(t, const ValueKey('campo-buscar-zona'), 'pol');
    await t.pump(const Duration(milliseconds: 1));
    await t.pumpAndSettle();
    await _tocar(t, const ValueKey('zona-z-polanco'));

    expect(find.byKey(const ValueKey('zona-elegida')), findsOneWidget);
    expect(find.text('Polanco · Miguel Hidalgo'), findsOneWidget);
    expect(_boton(t, 'btn-continuar').onPressed, isNotNull);
  });

  testWidgets(
    'revisar, editar y publicar muestra la confirmación con lo publicado',
    (t) async {
      final repo = FakeSolicitudesClienteRepository();
      await _montar(t, repo, selector: FakeSelectorFotos([foto('fuga.jpg')]));
      await _tocar(t, const ValueKey('categoria-cat-plo'));
      await _escribir(
        t,
        const ValueKey('campo-descripcion'),
        descripcionValida,
      );
      await _tocar(t, const ValueKey('btn-agregar-fotos'));
      await _tocar(t, const ValueKey('btn-continuar'));
      await _tocar(t, const ValueKey('btn-continuar'));

      expect(find.text('Revisa y publica'), findsOneWidget);
      expect(find.text(descripcionValida), findsOneWidget);
      expect(find.text('1 foto'), findsOneWidget);
      expect(find.text('¿Qué pasa después?'), findsOneWidget);

      // Editar vuelve al paso y conserva lo escrito.
      await _tocar(t, const ValueKey('editar-detalle'));
      expect(find.text(descripcionValida), findsOneWidget);
      await _tocar(t, const ValueKey('btn-continuar'));
      await _tocar(t, const ValueKey('btn-continuar'));

      await _tocar(t, const ValueKey('btn-publicar'));

      expect(find.byKey(const ValueKey('titulo-publicada')), findsOneWidget);
      expect(find.text('BUSCANDO ALIADO'), findsOneWidget);
      expect(find.text('1 foto adjunta'), findsOneWidget);
      expect(repo.publicadas.single.fotos, hasLength(1));
    },
  );

  testWidgets('un error al publicar se informa y permite reintentar', (
    t,
  ) async {
    final repo = FakeSolicitudesClienteRepository()
      ..fallarAlPublicar = const SolicitudFailure(
        SolicitudErrorTipo.sinConexion,
      );
    await _montar(t, repo);
    await _tocar(t, const ValueKey('categoria-cat-plo'));
    await _escribir(t, const ValueKey('campo-descripcion'), descripcionValida);
    await _tocar(t, const ValueKey('btn-continuar'));
    await _tocar(t, const ValueKey('btn-continuar'));

    await _tocar(t, const ValueKey('btn-publicar'));
    expect(find.textContaining('Sin conexión'), findsOneWidget);
    expect(find.text('Revisa y publica'), findsOneWidget);

    repo.fallarAlPublicar = null;
    await _tocar(t, const ValueKey('btn-publicar'));
    expect(find.byKey(const ValueKey('titulo-publicada')), findsOneWidget);
    expect(repo.llamadasPublicar, 2);
  });

  testWidgets(
    'publicada sin aviso a los aliados: se informa y se puede reintentar',
    (t) async {
      final repo = FakeSolicitudesClienteRepository()..avisoAlPublicar = false;
      await _montar(t, repo);
      await _tocar(t, const ValueKey('categoria-cat-plo'));
      await _escribir(
        t,
        const ValueKey('campo-descripcion'),
        descripcionValida,
      );
      await _tocar(t, const ValueKey('btn-continuar'));
      await _tocar(t, const ValueKey('btn-continuar'));
      await _tocar(t, const ValueKey('btn-publicar'));

      expect(find.byKey(const ValueKey('titulo-publicada')), findsOneWidget);
      expect(find.textContaining('todavía no pudimos'), findsOneWidget);
      expect(find.text('SIN AVISAR'), findsOneWidget);

      await _tocar(t, const ValueKey('btn-reintentar-aviso'));

      expect(repo.avisos, hasLength(1));
      expect(find.byKey(const ValueKey('btn-reintentar-aviso')), findsNothing);
      expect(find.text('BUSCANDO ALIADO'), findsOneWidget);
    },
  );

  testWidgets('"Ir a Mis solicitudes" redirige a la bandeja de solicitudes', (
    t,
  ) async {
    var redirigido = false;
    await _montar(
      t,
      FakeSolicitudesClienteRepository(),
      onIrAMisSolicitudes: () => redirigido = true,
    );
    await _tocar(t, const ValueKey('categoria-cat-plo'));
    await _escribir(t, const ValueKey('campo-descripcion'), descripcionValida);
    await _tocar(t, const ValueKey('btn-continuar'));
    await _tocar(t, const ValueKey('btn-continuar'));
    await _tocar(t, const ValueKey('btn-publicar'));

    await _tocar(t, const ValueKey('btn-mis-solicitudes'));

    expect(redirigido, isTrue);
  });

  testWidgets('"Publicar otra solicitud" reinicia el asistente', (t) async {
    await _montar(t, FakeSolicitudesClienteRepository());
    await _tocar(t, const ValueKey('categoria-cat-plo'));
    await _escribir(t, const ValueKey('campo-descripcion'), descripcionValida);
    await _tocar(t, const ValueKey('btn-continuar'));
    await _tocar(t, const ValueKey('btn-continuar'));
    await _tocar(t, const ValueKey('btn-publicar'));

    await _tocar(t, const ValueKey('btn-otra-solicitud'));

    expect(find.text('¿Qué servicio necesitas?'), findsOneWidget);
  });

  testWidgets('sin categorías activas lo explica', (t) async {
    await _montar(t, FakeSolicitudesClienteRepository(categorias: const []));
    expect(find.text('Aún no hay servicios disponibles'), findsOneWidget);
  });

  testWidgets('un usuario que no es cliente ve el motivo y puede reintentar', (
    t,
  ) async {
    final repo = FakeSolicitudesClienteRepository()
      ..fallarAlCargar = const SolicitudFailure(SolicitudErrorTipo.noEsCliente);
    await _montar(t, repo);

    expect(
      find.text('Solo los clientes pueden publicar solicitudes de servicio.'),
      findsOneWidget,
    );
    repo.fallarAlCargar = null;
    await _tocar(t, const ValueKey('btn-reintentar-formulario'));
    expect(find.text('Plomería'), findsOneWidget);
  });

  testWidgets('en escritorio los servicios se muestran en dos columnas', (
    t,
  ) async {
    await _montar(t, FakeSolicitudesClienteRepository(), tamano: _escritorio);

    final a = t.getTopLeft(find.byKey(const ValueKey('categoria-cat-plo')));
    final b = t.getTopLeft(find.byKey(const ValueKey('categoria-cat-cer')));
    expect(a.dy, b.dy, reason: 'misma fila');
  });
}
