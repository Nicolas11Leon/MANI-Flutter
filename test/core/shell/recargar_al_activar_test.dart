import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/shell/recargar_al_activar.dart';

/// Una pantalla que cuenta cuántas veces se construyó su estado: cada reconstrucción vuelve a pedir los datos.
class _Pantalla extends StatefulWidget {
  const _Pantalla(this.alCrear);
  final VoidCallback alCrear;

  @override
  State<_Pantalla> createState() => _PantallaState();
}

class _PantallaState extends State<_Pantalla> {
  @override
  void initState() {
    super.initState();
    widget.alCrear();
  }

  @override
  Widget build(BuildContext context) => const Text('pedidos');
}

void main() {
  group('SCRUM-1647 — pestañas que conservan su estado', () {
    late ActivacionDePestanas avisos;
    late DateTime ahora;
    var creada = 0;

    setUp(() {
      avisos = ActivacionDePestanas();
      ahora = DateTime(2026, 11, 15, 10);
      creada = 0;
    });

    Future<void> montar(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        home: RecargarAlActivar(
          ruta: '/cliente/solicitudes',
          avisos: avisos,
          reloj: () => ahora,
          child: _Pantalla(() => creada++),
        ),
      ),
    );

    testWidgets('al primer uso se construye una vez', (tester) async {
      await montar(tester);
      avisos.activar('/cliente/solicitudes');
      await tester.pump();
      expect(creada, 1);
    });

    testWidgets(
      'si se vuelve pronto, la pantalla se conserva y no repite las consultas',
      (tester) async {
        await montar(tester);
        avisos.activar('/cliente/solicitudes');
        avisos.activar('/inicio'); // se va a otra pestaña
        ahora = ahora.add(const Duration(seconds: 10));
        avisos.activar('/cliente/solicitudes'); // y vuelve a los 10 s
        await tester.pump();

        expect(creada, 1);
      },
    );

    testWidgets(
      'si se vuelve tarde, la pantalla se reconstruye y trae datos nuevos',
      (tester) async {
        await montar(tester);
        avisos.activar('/cliente/solicitudes');
        avisos.activar('/inicio');
        ahora = ahora.add(const Duration(seconds: 45));
        avisos.activar('/cliente/solicitudes');
        await tester.pump();

        expect(creada, 2);
      },
    );

    testWidgets(
      'cada vuelta cuenta desde la última salida, no desde la primera',
      (tester) async {
        await montar(tester);
        avisos.activar('/cliente/solicitudes');

        // Primera salida corta: no recarga.
        avisos.activar('/inicio');
        ahora = ahora.add(const Duration(seconds: 10));
        avisos.activar('/cliente/solicitudes');
        await tester.pump();
        expect(creada, 1);

        // Segunda salida larga: recarga.
        avisos.activar('/inicio');
        ahora = ahora.add(const Duration(seconds: 40));
        avisos.activar('/cliente/solicitudes');
        await tester.pump();
        expect(creada, 2);

        // Y la siguiente salida corta, otra vez no.
        avisos.activar('/inicio');
        ahora = ahora.add(const Duration(seconds: 5));
        avisos.activar('/cliente/solicitudes');
        await tester.pump();
        expect(creada, 2);
      },
    );

    testWidgets('abrir otra pestaña no recarga esta', (tester) async {
      await montar(tester);
      avisos.activar('/cliente/solicitudes');
      ahora = ahora.add(const Duration(minutes: 5));
      avisos.activar('/servicios');
      avisos.activar('/cuenta');
      await tester.pump();
      expect(creada, 1);
    });

    testWidgets('el tiempo de caducidad se puede ajustar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RecargarAlActivar(
            ruta: '/aliado/cobros',
            caducaEn: const Duration(minutes: 5),
            avisos: avisos,
            reloj: () => ahora,
            child: _Pantalla(() => creada++),
          ),
        ),
      );
      avisos.activar('/aliado/cobros');
      avisos.activar('/inicio');
      ahora = ahora.add(const Duration(minutes: 2));
      avisos.activar('/aliado/cobros');
      await tester.pump();
      expect(creada, 1);
    });

    testWidgets(
      'si algo cambió mientras estaba fuera, al volver se recarga aunque sea pronto',
      (tester) async {
        await montar(tester);
        avisos.activar('/cliente/solicitudes');
        avisos.activar('/inicio');
        avisos.invalidar(); // p. ej. se publicó una solicitud
        await tester.pump();
        expect(creada, 1, reason: 'oculta, todavía no gasta una consulta');

        ahora = ahora.add(const Duration(seconds: 2));
        avisos.activar('/cliente/solicitudes');
        await tester.pump();
        expect(creada, 2);
      },
    );

    testWidgets('si algo cambia con la pestaña abierta, se recarga ya', (
      tester,
    ) async {
      await montar(tester);
      avisos.activar('/cliente/solicitudes');
      avisos.invalidar();
      await tester.pump();
      expect(creada, 2);
    });

    testWidgets('la pestaña que ya se puso al día queda por fuera', (
      tester,
    ) async {
      await montar(tester);
      avisos.activar('/cliente/solicitudes');
      avisos.invalidar(excepto: '/cliente/solicitudes');
      await tester.pump();
      expect(creada, 1);

      avisos.activar('/inicio');
      avisos.activar('/cliente/solicitudes');
      await tester.pump();
      expect(creada, 1);
    });

    testWidgets('una invalidación se gasta una sola vez', (tester) async {
      await montar(tester);
      avisos.activar('/cliente/solicitudes');
      avisos.activar('/inicio');
      avisos.invalidar();
      avisos.activar('/cliente/solicitudes');
      await tester.pump();
      expect(creada, 2);

      avisos.activar('/inicio');
      ahora = ahora.add(const Duration(seconds: 5));
      avisos.activar('/cliente/solicitudes');
      await tester.pump();
      expect(creada, 2);
    });

    test('un mismo aviso repetido no notifica dos veces', () {
      var avisosRecibidos = 0;
      avisos.addListener(() => avisosRecibidos++);
      avisos.activar('/inicio');
      avisos.activar('/inicio');
      expect(avisosRecibidos, 1);
      expect(avisos.ruta, '/inicio');
    });
  });
}
