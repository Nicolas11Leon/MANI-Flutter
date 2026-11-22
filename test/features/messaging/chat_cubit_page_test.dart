import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/features/messaging/data/mensajes_datasource.dart';
import 'package:mani/features/messaging/domain/mensaje.dart';
import 'package:mani/features/messaging/presentation/chat_cubit.dart';
import 'package:mani/features/messaging/presentation/chat_page.dart';

Mensaje _msg(String id, {bool mio = false, String texto = ''}) => Mensaje(
  id: id,
  contenido: texto.isEmpty ? 'texto $id' : texto,
  esMio: mio,
  rolRemitente: mio ? 'CLIENT' : 'ALLY',
  creadoEn: DateTime(2026, 10, 27, 15, 30),
);

/// Fuente en memoria que se comporta como Core: el hilo guarda los mensajes, `listar` devuelve los
/// posteriores al cursor y `enviar` los agrega. Registra las llamadas.
class _FuenteFake implements FuenteMensajes {
  final hilo = <Mensaje>[];
  final consultas = <String?>[];
  final envios = <({String contenido, String clave})>[];
  Object? falloListar;
  Object? falloEnviar;

  /// Si se asigna, `enviar` guarda el mensaje pero responde con este fallo (el cliente no se entera).
  Object? falloTrasGuardar;
  Completer<void>? esperaListar;
  Completer<void>? esperaEnviar;
  int _n = 0;

  @override
  Future<List<Mensaje>> listar(String solicitudId, {String? despuesDe}) async {
    consultas.add(despuesDe);
    await esperaListar?.future;
    if (falloListar != null) throw falloListar!;
    if (despuesDe == null) return List.of(hilo);
    final i = hilo.indexWhere((m) => m.id == despuesDe);
    return hilo.sublist(i + 1);
  }

  @override
  Future<void> enviar(
    String solicitudId,
    String contenido, {
    required String claveIdempotencia,
  }) async {
    envios.add((contenido: contenido, clave: claveIdempotencia));
    await esperaEnviar?.future;
    if (falloEnviar != null) throw falloEnviar!;
    // Core: la misma clave no duplica.
    if (!envios
        .take(envios.length - 1)
        .any((e) => e.clave == claveIdempotencia)) {
      hilo.add(_msg('m${++_n}', mio: true, texto: contenido));
    }
    if (falloTrasGuardar != null) throw falloTrasGuardar!;
  }
}

const _sinRed = MensajeFailure(MensajeErrorTipo.sinConexion);

void main() {
  group('ChatCubit', () {
    test('la primera carga muestra el hilo en el orden de Core', () async {
      final f = _FuenteFake()..hilo.addAll([_msg('a'), _msg('b', mio: true)]);
      final cubit = ChatCubit(f, 'sol-1', intervalo: const Duration(hours: 1));
      addTearDown(cubit.close);

      await cubit.iniciar();

      expect(cubit.state.cargando, isFalse);
      expect(cubit.state.mensajes.map((m) => m.id), ['a', 'b']);
      expect(f.consultas, [null]);
    });

    test(
      'las consultas siguientes piden solo lo posterior al último mensaje y no duplican',
      () async {
        final f = _FuenteFake()..hilo.add(_msg('a'));
        final cubit = ChatCubit(
          f,
          'sol-1',
          intervalo: const Duration(hours: 1),
        );
        addTearDown(cubit.close);
        await cubit.iniciar();

        f.hilo.add(_msg('b'));
        await cubit.reanudar(); // sin pausa previa no consulta
        expect(f.consultas, [null]);
        cubit.pausar();
        await cubit.reanudar();
        await cubit.reanudar();

        expect(f.consultas, [null, 'a']);
        expect(cubit.state.mensajes.map((m) => m.id), ['a', 'b']);
      },
    );

    test(
      'enviar guarda con una clave, limpia el campo y trae el mensaje en el orden de Core',
      () async {
        final f = _FuenteFake();
        final cubit = ChatCubit(
          f,
          'sol-1',
          intervalo: const Duration(hours: 1),
          generarClave: () => 'k1',
        );
        addTearDown(cubit.close);
        await cubit.iniciar();

        final ok = await cubit.enviar('  hola  ');

        expect(ok, isTrue);
        expect(f.envios.single, (contenido: 'hola', clave: 'k1'));
        expect(cubit.state.mensajes.single.contenido, 'hola');
        expect(cubit.state.mensajes.single.esMio, isTrue);
        expect(cubit.state.enviando, isFalse);
      },
    );

    test(
      'un mensaje del otro anterior al mío no se pierde al enviar',
      () async {
        final f = _FuenteFake()..hilo.add(_msg('a'));
        final cubit = ChatCubit(
          f,
          'sol-1',
          intervalo: const Duration(hours: 1),
        );
        addTearDown(cubit.close);
        await cubit.iniciar();

        // El aliado escribe antes que yo, pero aún no consulté.
        f.hilo.add(_msg('b'));
        await cubit.enviar('mío');

        expect(cubit.state.mensajes.map((m) => m.id), ['a', 'b', 'm1']);
      },
    );

    test(
      'C2: si el envío falla, no hay mensaje, el error queda y se puede reintentar con la misma clave',
      () async {
        var n = 0;
        final f = _FuenteFake()..falloEnviar = _sinRed;
        final cubit = ChatCubit(
          f,
          'sol-1',
          intervalo: const Duration(hours: 1),
          generarClave: () => 'k${++n}',
        );
        addTearDown(cubit.close);
        await cubit.iniciar();

        expect(await cubit.enviar('hola'), isFalse);
        expect(cubit.state.mensajes, isEmpty);
        expect(cubit.state.errorEnvio?.tipo, MensajeErrorTipo.sinConexion);
        expect(cubit.state.enviando, isFalse);

        f.falloEnviar = null;
        expect(await cubit.enviar('hola'), isTrue);

        expect(f.envios.map((e) => e.clave), [
          'k1',
          'k1',
        ], reason: 'mismo texto, misma clave');
        expect(cubit.state.errorEnvio, isNull);
      },
    );

    test(
      'si Core guardó pero la respuesta se perdió, reintentar no duplica',
      () async {
        final f = _FuenteFake()..falloTrasGuardar = _sinRed;
        final cubit = ChatCubit(
          f,
          'sol-1',
          intervalo: const Duration(hours: 1),
        );
        addTearDown(cubit.close);
        await cubit.iniciar();

        expect(await cubit.enviar('hola'), isFalse);
        f.falloTrasGuardar = null;
        expect(await cubit.enviar('hola'), isTrue);

        expect(f.hilo, hasLength(1));
        expect(cubit.state.mensajes, hasLength(1));
      },
    );

    test('cambiar el texto tras un fallo usa una clave nueva', () async {
      var n = 0;
      final f = _FuenteFake()..falloEnviar = _sinRed;
      final cubit = ChatCubit(
        f,
        'sol-1',
        intervalo: const Duration(hours: 1),
        generarClave: () => 'k${++n}',
      );
      addTearDown(cubit.close);
      await cubit.iniciar();

      await cubit.enviar('uno');
      await cubit.enviar('dos');

      expect(f.envios.map((e) => e.clave), ['k1', 'k2']);
    });

    test('un doble toque mientras se envía no manda otro mensaje', () async {
      final f = _FuenteFake()..esperaEnviar = Completer<void>();
      final cubit = ChatCubit(f, 'sol-1', intervalo: const Duration(hours: 1));
      addTearDown(cubit.close);
      await cubit.iniciar();

      final primero = cubit.enviar('hola');
      expect(await cubit.enviar('hola'), isFalse);
      f.esperaEnviar!.complete();
      await primero;

      expect(f.envios, hasLength(1));
    });

    test(
      'vacío, solo espacios o más de 1000 caracteres no llegan a Core',
      () async {
        final f = _FuenteFake();
        final cubit = ChatCubit(
          f,
          'sol-1',
          intervalo: const Duration(hours: 1),
        );
        addTearDown(cubit.close);
        await cubit.iniciar();

        expect(await cubit.enviar('   '), isFalse);
        expect(await cubit.enviar('a' * 1001), isFalse);

        expect(f.envios, isEmpty);
        expect(cubit.state.errorEnvio?.tipo, MensajeErrorTipo.datosInvalidos);
      },
    );

    test('un 409 deja el hilo en solo lectura y conserva lo leído', () async {
      final f = _FuenteFake()
        ..hilo.add(_msg('a'))
        ..falloEnviar = const MensajeFailure(MensajeErrorTipo.servicioCerrado);
      final cubit = ChatCubit(f, 'sol-1', intervalo: const Duration(hours: 1));
      addTearDown(cubit.close);
      await cubit.iniciar();

      await cubit.enviar('tarde');

      expect(cubit.state.soloLectura, isTrue);
      expect(cubit.state.puedeEscribir, isFalse);
      expect(cubit.state.mensajes, hasLength(1));
    });

    test('C3: un 404 o 403 en la lectura deja el hilo inaccesible', () async {
      for (final tipo in [
        MensajeErrorTipo.noEncontrado,
        MensajeErrorTipo.sinPermiso,
      ]) {
        final f = _FuenteFake()..falloListar = MensajeFailure(tipo);
        final cubit = ChatCubit(
          f,
          'sol-1',
          intervalo: const Duration(hours: 1),
        );
        addTearDown(cubit.close);

        await cubit.iniciar();

        expect(cubit.state.hiloInaccesible, isTrue, reason: '$tipo');
        expect(cubit.state.puedeEscribir, isFalse);
        expect(cubit.state.cargando, isFalse);
      }
    });

    test(
      'un fallo de red al consultar conserva los mensajes y se recupera solo',
      () async {
        final f = _FuenteFake()..hilo.add(_msg('a'));
        final cubit = ChatCubit(
          f,
          'sol-1',
          intervalo: const Duration(hours: 1),
        );
        addTearDown(cubit.close);
        await cubit.iniciar();

        f.falloListar = _sinRed;
        cubit.pausar();
        await cubit.reanudar();
        expect(cubit.state.errorLectura?.tipo, MensajeErrorTipo.sinConexion);
        expect(cubit.state.mensajes, hasLength(1));
        expect(
          cubit.state.puedeEscribir,
          isTrue,
          reason: 'un corte de red no cierra el chat',
        );

        f.falloListar = null;
        f.hilo.add(_msg('b'));
        cubit.pausar();
        await cubit.reanudar();
        expect(cubit.state.errorLectura, isNull);
        expect(cubit.state.mensajes.map((m) => m.id), ['a', 'b']);
      },
    );

    test('dos consultas a la vez no se solapan', () async {
      final f = _FuenteFake()..esperaListar = Completer<void>();
      final cubit = ChatCubit(f, 'sol-1', intervalo: const Duration(hours: 1));
      addTearDown(cubit.close);

      final primera = cubit.iniciar();
      cubit.pausar();
      unawaited(cubit.reanudar());
      await Future<void>.delayed(Duration.zero);
      expect(
        f.consultas,
        hasLength(1),
        reason: 'la segunda espera a la primera',
      );
      f.esperaListar!.complete();
      await primera;
    });

    test('al cerrar el Cubit no emite ni consulta más', () async {
      final f = _FuenteFake()..esperaListar = Completer<void>();
      final cubit = ChatCubit(f, 'sol-1', intervalo: const Duration(hours: 1));

      final carga = cubit.iniciar();
      await cubit.close();
      f.esperaListar!.complete();
      await carga;
    });
  });

  group('sondeo periódico', () {
    testWidgets(
      'consulta cada intervalo mientras está abierto y se detiene al cerrarse',
      (tester) async {
        final f = _FuenteFake()..hilo.add(_msg('a'));
        final cubit = ChatCubit(
          f,
          'sol-1',
          intervalo: const Duration(seconds: 5),
        );

        await cubit.iniciar();
        expect(f.consultas, [null]);

        f.hilo.add(_msg('b'));
        await tester.pump(const Duration(seconds: 5));
        expect(f.consultas, [null, 'a']);
        expect(cubit.state.mensajes.map((m) => m.id), ['a', 'b']);

        await tester.pump(const Duration(seconds: 5));
        expect(f.consultas, [null, 'a', 'b']);

        cubit.pausar();
        await tester.pump(const Duration(seconds: 30));
        expect(
          f.consultas,
          hasLength(3),
          reason: 'en segundo plano no consulta',
        );

        await cubit.close();
        await tester.pump(const Duration(seconds: 30));
        expect(f.consultas, hasLength(3));
      },
    );

    testWidgets('un 404 detiene el sondeo', (tester) async {
      final f = _FuenteFake()
        ..falloListar = const MensajeFailure(MensajeErrorTipo.noEncontrado);
      final cubit = ChatCubit(
        f,
        'sol-1',
        intervalo: const Duration(seconds: 5),
      );

      await cubit.iniciar();
      await tester.pump(const Duration(seconds: 30));

      expect(f.consultas, hasLength(1));
      await cubit.close();
    });
  });

  group('ChatPage', () {
    Future<(_FuenteFake, ChatCubit)> montar(
      WidgetTester tester, {
      _FuenteFake? fuente,
    }) async {
      final f = fuente ?? _FuenteFake();
      final cubit = ChatCubit(
        f,
        'sol-1',
        intervalo: const Duration(seconds: 5),
        generarClave: () => 'k',
      );
      // BlocProvider(create:) cierra el Cubit al desmontar la pantalla, igual que en la app, y con él el Timer.
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(create: (_) => cubit, child: const ChatPage()),
        ),
      );
      await cubit.iniciar();
      await tester.pump();
      return (f, cubit);
    }

    testWidgets('sin mensajes invita a escribir el primero', (tester) async {
      await montar(tester);
      expect(find.byKey(const Key('chat-vacio')), findsOneWidget);
      expect(find.byKey(const Key('campo-mensaje')), findsOneWidget);
    });

    testWidgets('muestra los mensajes de ambos y distingue al aliado', (
      tester,
    ) async {
      final f = _FuenteFake()
        ..hilo.addAll([
          _msg('a', texto: 'Llego a las 3'),
          _msg('b', mio: true, texto: 'Perfecto'),
        ]);
      await montar(tester, fuente: f);

      expect(find.text('Llego a las 3'), findsOneWidget);
      expect(find.text('Perfecto'), findsOneWidget);
      expect(
        find.text('Aliado'),
        findsOneWidget,
        reason: 'el mensaje del otro lleva su rol; el mío no',
      );
      expect(find.text('15:30'), findsWidgets);
    });

    testWidgets(
      'escribir y enviar guarda el mensaje, vacía el campo y lo muestra',
      (tester) async {
        final (f, _) = await montar(tester);

        await tester.enterText(
          find.byKey(const Key('campo-mensaje')),
          'Hola, ¿a qué hora?',
        );
        await tester.tap(find.byKey(const Key('btn-enviar-mensaje')));
        await tester.pumpAndSettle();

        expect(f.envios.single.contenido, 'Hola, ¿a qué hora?');
        expect(find.text('Hola, ¿a qué hora?'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: find.byKey(const Key('campo-mensaje')),
                  matching: find.byType(TextField),
                ),
              )
              .controller!
              .text,
          isEmpty,
        );
      },
    );

    testWidgets(
      'C2: si el envío falla, avisa y conserva el texto para reintentar',
      (tester) async {
        final f = _FuenteFake()..falloEnviar = _sinRed;
        await montar(tester, fuente: f);

        await tester.enterText(find.byKey(const Key('campo-mensaje')), 'Hola');
        await tester.tap(find.byKey(const Key('btn-enviar-mensaje')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('error-envio')), findsOneWidget);
        expect(find.textContaining('Sin conexión'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: find.byKey(const Key('campo-mensaje')),
                  matching: find.byType(TextField),
                ),
              )
              .controller!
              .text,
          'Hola',
        );
      },
    );

    testWidgets(
      'un mensaje del otro aparece en la siguiente consulta, sin acción de la persona',
      (tester) async {
        final (f, _) = await montar(tester);
        f.hilo.add(_msg('a', texto: 'Ya voy en camino'));

        await tester.pump(const Duration(seconds: 5));
        await tester.pump();

        expect(find.text('Ya voy en camino'), findsOneWidget);
      },
    );

    testWidgets(
      'con el servicio cerrado se lee pero no hay campo para escribir',
      (tester) async {
        final f = _FuenteFake()
          ..hilo.add(_msg('a', texto: 'Gracias'))
          ..falloEnviar = const MensajeFailure(
            MensajeErrorTipo.servicioCerrado,
          );
        await montar(tester, fuente: f);

        await tester.enterText(find.byKey(const Key('campo-mensaje')), 'tarde');
        await tester.tap(find.byKey(const Key('btn-enviar-mensaje')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('aviso-solo-lectura')), findsOneWidget);
        expect(find.byKey(const Key('campo-mensaje')), findsNothing);
        expect(find.text('Gracias'), findsOneWidget);
      },
    );

    testWidgets(
      'C3: un hilo ajeno (404) no muestra campo para escribir y explica',
      (tester) async {
        final f = _FuenteFake()
          ..falloListar = const MensajeFailure(MensajeErrorTipo.noEncontrado);
        await montar(tester, fuente: f);

        expect(find.byKey(const Key('aviso-lectura')), findsOneWidget);
        expect(find.text('No encontramos este servicio.'), findsOneWidget);
        expect(find.byKey(const Key('campo-mensaje')), findsNothing);
      },
    );

    testWidgets(
      'un corte de red al consultar avisa sin ocultar la conversación',
      (tester) async {
        final f = _FuenteFake()..hilo.add(_msg('a', texto: 'Hola'));
        await montar(tester, fuente: f);

        f.falloListar = _sinRed;
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();

        expect(find.byKey(const Key('aviso-lectura')), findsOneWidget);
        expect(find.text('Hola'), findsOneWidget);
        expect(find.byKey(const Key('campo-mensaje')), findsOneWidget);
      },
    );

    testWidgets(
      'al pasar a segundo plano deja de consultar y al volver consulta de inmediato',
      (tester) async {
        final (f, _) = await montar(tester);

        // La app pasa a segundo plano por la secuencia real del sistema.
        for (final e in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(e);
        }
        await tester.pump(const Duration(seconds: 30));
        expect(f.consultas, hasLength(1));

        for (final e in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(e);
        }
        await tester.pump();
        expect(f.consultas, hasLength(2));
      },
    );

    testWidgets('el campo limita a 1000 caracteres', (tester) async {
      await montar(tester);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('campo-mensaje')),
                matching: find.byType(TextField),
              ),
            )
            .maxLength,
        1000,
      );
    });
  });
}
