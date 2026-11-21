import 'package:flutter_test/flutter_test.dart';
import 'package:mani/core/di/injection_container.dart';

void main() {
  tearDown(() => sl.reset());

  // Un tipo registrado dos veces hace que GetIt lance al arrancar y la app
  // quede en blanco, sin que ninguna otra prueba lo note.
  test('init registra cada dependencia una sola vez', () async {
    await expectLater(init(), completes);
  });
}
