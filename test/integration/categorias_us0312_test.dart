// Test maestro de US-03.1.2 (SCRUM-858) — Desactivar categoría sin afectar en curso.
//
// Recorre la historia de punta a punta con las capas reales de categorías,
// solicitudes de cliente y asignación de aliados:
//   1. El Administrador del Tenant oculta una categoría activa ("Plomería").
//   2. La categoría desaparece del catálogo público del cliente y rechaza
//      nuevas solicitudes (MANI-SOL-422C -> categoriaNoDisponible).
//   3. Los servicios que ya estaban en curso en esa categoría (PENDIENTE /
//      ASIGNADA) se conservan intactos y pueden continuar su ejecución.
//   4. Se verifica autorización por rol (ADMIN_TENANT) y aislamiento
//      multi-tenant (404 al intentar alterar una categoría de otro tenant).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/logging/structured_logger.dart';
import 'package:mani/features/asignacion/data/repositories/asignacion_repository_impl.dart';
import 'package:mani/features/asignacion/domain/entities/solicitud_entity.dart';
import 'package:mani/features/services/categories/data/repositories/categorias_repository_impl.dart';
import 'package:mani/features/services/categories/domain/failures/categoria_failure.dart';
import 'package:mani/features/services/categories/presentation/pages/gestion_categorias_page.dart';
import 'package:mani/features/services/requests/data/repositories/solicitudes_cliente_repository_impl.dart';
import 'package:mani/features/services/requests/domain/entities/nueva_solicitud.dart';
import 'package:mani/features/services/requests/domain/failures/solicitud_failure.dart';

import '../features/asignacion/fakes.dart' as asig;
import '../features/services/categories/fakes.dart';
import '../features/services/requests/fakes.dart' as req;

const _tenantA = 'tenant-a';
const _tenantB = 'tenant-b';

ServidorCategoriasFake _servidorCategorias() =>
    ServidorCategoriasFake(tenantSesion: _tenantA)
      ..sembrar(
        tenantId: _tenantA,
        id: 'cat-plo',
        nombre: 'Plomería',
        aliados: 5,
      )
      ..sembrar(
        tenantId: _tenantA,
        id: 'cat-cer',
        nombre: 'Cerrajería',
        estado: 'INACTIVO',
        flujo: 'TARIFA_ESTANDAR',
      )
      ..sembrar(tenantId: _tenantB, id: 'cat-pin-b', nombre: 'Pintura');

Future<List<Map<String, dynamic>>> _montarAdminApp(
  WidgetTester t,
  ServidorCategoriasFake servidor,
) async {
  t.view.physicalSize = const Size(1400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  final logs = <Map<String, dynamic>>[];
  final repo = CategoriasRepositoryImpl(
    servidor,
    logger: StructuredLogger(
      canal: 'test',
      sink: (l) => logs.add(jsonDecode(l) as Map<String, dynamic>),
    ),
  );
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
  return logs;
}

Future<void> _tocar(WidgetTester t, Key key) async {
  await t.ensureVisible(find.byKey(key));
  await t.pumpAndSettle();
  await t.tap(find.byKey(key));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'US-03.1.2 flujo completo: ocultar categoría impide nuevas solicitudes sin cancelar servicios en curso',
    (t) async {
      final servidorCat = _servidorCategorias();
      final logs = await _montarAdminApp(t, servidorCat);

      // Servidores de solicitudes (cliente) y asignación (aliado) con dos
      // servicios ya iniciados en "Plomería" antes de desactivarla.
      final servidorSol = req.ServidorSolicitudesFake(tenant: _tenantA)
        ..sembrarBase();
      final repoCliente = SolicitudesClienteRepositoryImpl(servidorSol);

      final servidorAsig = asig.ServidorAsignacionFake()
        ..registrarAliado(
          'aliado-1',
          asig.AliadoFake(
            tenantId: _tenantA,
            categorias: {'Plomería'},
            zonas: {'Cuauhtémoc'},
          ),
        )
        ..publicar(
          id: 'sol-pendiente-previa',
          tenantId: _tenantA,
          categoria: 'Plomería',
          zona: 'Roma Norte',
          zonaPadre: 'Cuauhtémoc',
        )
        ..publicar(
          id: 'sol-en-ejecucion-previa',
          tenantId: _tenantA,
          categoria: 'Plomería',
          zona: 'Roma Norte',
          zonaPadre: 'Cuauhtémoc',
        );
      // La segunda solicitud ya estaba asignada y en curso antes de ocultar.
      servidorAsig.fila('sol-en-ejecucion-previa')
        ..['aliado_id'] = 'aliado-1'
        ..['estado'] = 'ASIGNADA';
      final repoAliado = AsignacionRepositoryImpl(
        servidorAsig.sesion('aliado-1'),
      );

      // Estado inicial: Plomería está visible (1 visible · 1 oculta).
      expect(find.text('1 visible para clientes · 1 oculta'), findsOneWidget);
      expect((await repoCliente.categoriasDisponibles()).map((c) => c.nombre), [
        'Plomería',
      ]);

      // CA-1: El Admin del Tenant oculta "Plomería" y lo confirma (SCRUM-1650).
      await _tocar(t, const ValueKey('toggle-estado-categoria-cat-plo'));
      await _tocar(t, const ValueKey('confirmacion-confirmar'));

      final filaPlomeria = servidorCat
          .delTenant(_tenantA)
          .firstWhere((f) => f['id'] == 'cat-plo');
      expect(filaPlomeria['estado'], 'INACTIVO');
      expect(find.text('0 visibles para clientes · 2 ocultas'), findsOneWidget);
      expect(
        find.text('5 aliados'),
        findsOneWidget,
        reason: 'conserva aliados',
      );
      expect(
        find.textContaining('los servicios en curso continúan sin cambios'),
        findsOneWidget,
      );

      // Sincroniza el estado de la tabla compartida `categoria_servicio`.
      servidorSol.categorias.firstWhere((c) => c['id'] == 'cat-plo')['estado'] =
          filaPlomeria['estado'];

      // CA-2: La categoría desaparece del catálogo público del cliente y
      // cualquier intento de crear una nueva solicitud en ella se rechaza.
      expect(await repoCliente.categoriasDisponibles(), isEmpty);

      SolicitudFailure? fallaPublicar;
      try {
        await repoCliente.publicar(
          NuevaSolicitud.crear(
            categoria: req.plomeria,
            descripcion: req.descripcionValida,
            fotos: const [],
            ubicacion: NuevaDireccion.crear(
              direccion: 'Calle Colima 120, Apto 401',
              zona: req.romaNorte,
            ),
            claveIdempotencia: '00000000-0000-4000-8000-000000000099',
          ),
        );
      } on SolicitudFailure catch (f) {
        fallaPublicar = f;
      }
      expect(fallaPublicar?.tipo, SolicitudErrorTipo.categoriaInvalida);
      expect(servidorSol.solicitudes, isEmpty);

      // CA-3: Los servicios previos de "Plomería" NO se cancelan y continúan
      // su flujo normal.
      final enCurso = await repoAliado.listar();
      expect(
        enCurso.map((s) => s.id),
        containsAll(['sol-pendiente-previa', 'sol-en-ejecucion-previa']),
      );
      final futuroAceptar = repoAliado.aceptar('sol-pendiente-previa');
      await t.pump(const Duration(milliseconds: 1));
      final aceptada = await futuroAceptar;
      expect(aceptada.estado, EstadoSolicitud.asignada);
      expect(
        servidorAsig.fila('sol-en-ejecucion-previa')['estado'],
        'ASIGNADA',
      );

      // CA-4: El Admin reactiva "Plomería" y vuelve a estar disponible para
      // nuevas solicitudes.
      await _tocar(t, const ValueKey('toggle-estado-categoria-cat-plo'));
      expect(filaPlomeria['estado'], 'ACTIVO');
      expect(find.text('1 visible para clientes · 1 oculta'), findsOneWidget);

      servidorSol.categorias.firstWhere((c) => c['id'] == 'cat-plo')['estado'] =
          filaPlomeria['estado'];
      expect((await repoCliente.categoriasDisponibles()).map((c) => c.nombre), [
        'Plomería',
      ]);

      // Trazabilidad: log estructurado por cada cambio de estado.
      final eventosEstado = logs
          .where((l) => l['event'] == 'US-03.1.2.cambiar_estado_categoria')
          .toList();
      expect(eventosEstado, hasLength(2));
      expect(eventosEstado[0]['message'], 'categoria_desactivada');
      expect(eventosEstado[0]['categoria_id'], 'cat-plo');
      expect(eventosEstado[0]['activa'], isFalse);
      expect(eventosEstado[0]['tenant_id'], _tenantA);
      expect(eventosEstado[1]['message'], 'categoria_activada');
      expect(eventosEstado[1]['activa'], isTrue);
    },
  );

  test(
    'US-03.1.2 seguridad: permisos por rol y aislamiento multi-tenant al cambiar estado',
    () async {
      final servidor = _servidorCategorias();
      final repo = CategoriasRepositoryImpl(servidor);

      // Un administrador de tenant-a no puede desactivar una categoría de tenant-b.
      await expectLater(
        repo.cambiarEstado(categoriaId: 'cat-pin-b', activa: false),
        throwsA(
          isA<CategoriaFailure>().having(
            (f) => f.tipo,
            'tipo',
            CategoriaErrorTipo.noEncontrada,
          ),
        ),
      );
      expect(
        servidor.delTenant(_tenantB).single['estado'],
        'ACTIVO',
        reason: 'la categoría del otro tenant permanece intacta',
      );

      // Un usuario con rol CLIENTE o ALIADO recibe 403 noAutorizado.
      for (final rol in ['CLIENTE', 'ALIADO']) {
        servidor.rolSesion = rol;
        await expectLater(
          repo.cambiarEstado(categoriaId: 'cat-plo', activa: false),
          throwsA(
            isA<CategoriaFailure>().having(
              (f) => f.tipo,
              'tipo',
              CategoriaErrorTipo.noAutorizado,
            ),
          ),
        );
      }
      expect(servidor.delTenant(_tenantA).first['estado'], 'ACTIVO');
    },
  );
}
