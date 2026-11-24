import 'package:flutter/widgets.dart';

/// Punteros (dedos) cuyo gesto no debe cambiar de menú: los que empezaron dentro de un [SinDeslizarMenus].
final _punterosSinDeslizar = <int>{};

/// ¿El gesto de este puntero pertenece a una zona que no cambia de menú?
bool punteroSinDeslizar(int puntero) => _punterosSinDeslizar.contains(puntero);

/// Olvida el puntero cuando el dedo se levanta o se cancela.
void liberarPuntero(int puntero) => _punterosSinDeslizar.remove(puntero);

/// Marca una zona donde arrastrar de lado hace otra cosa (mapa, tira de fotos, fila de filtros): un gesto que empieza
/// aquí no cambia de menú con el deslizamiento del armazón.
class SinDeslizarMenus extends StatelessWidget {
  const SinDeslizarMenus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _punterosSinDeslizar.add(e.pointer),
      child: child,
    );
  }
}
