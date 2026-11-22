import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';

/// Barra de acciones estándar de un flujo de varios pasos (SCRUM-1647): **Atrás** a la izquierda y la acción principal
/// (Continuar, Publicar, Pagar…) a la derecha, siempre abajo y siempre con el mismo aspecto.
///
/// Toda pantalla que sea un flujo la usa en vez de hacerse su propia barra, y se registra en `rutasDeFlujo` para que el
/// armazón esconda la barra de menú y abajo quede una sola barra. Así el usuario aprende el patrón una vez.
class BarraAccionesFlujo extends StatelessWidget {
  const BarraAccionesFlujo({
    super.key,
    required this.etiquetaPrincipal,
    required this.onPrincipal,
    this.iconoPrincipal = Icons.arrow_forward_rounded,
    this.cargando = false,
    this.onAtras,
    this.etiquetaAtras = 'Atrás',
    this.pista,
    this.clavePrincipal,
    this.claveAtras,
    this.clavePista,
  });

  /// Texto de la acción principal: «Continuar», «Publicar solicitud», «Pagar»…
  final String etiquetaPrincipal;
  final IconData iconoPrincipal;

  /// Acción principal; `null` la deja sin efecto (por ejemplo, mientras faltan datos).
  final VoidCallback? onPrincipal;

  /// La acción principal está en curso: se muestra un indicador y no se puede repetir.
  final bool cargando;

  /// Acción de «Atrás»; `null` la deja sin efecto.
  final VoidCallback? onAtras;
  final String etiquetaAtras;

  /// Línea breve sobre los botones que dice qué falta para continuar.
  final String? pista;

  final Key? clavePrincipal;
  final Key? claveAtras;
  final Key? clavePista;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: context.mani.surface,
        border: Border(top: BorderSide(color: context.mani.ink, width: 2)),
      ),
      child: SafeArea(
        top: false,
        // heightFactor: la barra mide lo que miden sus botones; sin él, en la ranura inferior de un Scaffold el Center
        // se expande a toda la altura disponible y deja el contenido sin espacio.
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pista != null) ...[
                  Text(
                    pista!,
                    key: clavePista,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.mani.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Flexible: en un teléfono los dos botones comparten el ancho sin desbordar; en escritorio llegan a
                    // su máximo.
                    Flexible(
                      flex: 2,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: ManiButton(
                          key: claveAtras,
                          etiqueta: etiquetaAtras,
                          icono: Icons.arrow_back_rounded,
                          variante: ManiButtonVariante.secundario,
                          expandir: true,
                          onPressed: onAtras,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      flex: 3,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: ManiButton(
                          key: clavePrincipal,
                          etiqueta: etiquetaPrincipal,
                          icono: iconoPrincipal,
                          expandir: true,
                          cargando: cargando,
                          onPressed: onPrincipal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
