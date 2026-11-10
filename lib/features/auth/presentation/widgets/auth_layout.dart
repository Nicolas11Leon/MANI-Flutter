import 'package:flutter/material.dart';
import 'package:mani/core/theme/app_theme.dart';
import 'package:mani/core/widgets/mani_button.dart';
import 'package:mani/core/widgets/mani_layout.dart';

/// Marco de las pantallas de acceso (inicio de sesión).
///
/// En escritorio (≥ [anchoEscritorio]) divide la pantalla: a la izquierda el
/// panel de marca [AuthPanelMarca] y a la derecha el formulario centrado. En
/// móvil muestra solo el formulario con la marca compacta encima.
class AuthSplitScaffold extends StatelessWidget {
  const AuthSplitScaffold({
    super.key,
    required this.child,
    this.anchoFormulario = 400,
  });

  final Widget child;
  final double anchoFormulario;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ManiColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final formulario = Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: c.maxWidth >= 600
                      ? ManiSpace.huge
                      : ManiSpace.xxl,
                  vertical: ManiSpace.xxxl,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: anchoFormulario),
                  child: child,
                ),
              ),
            );
            if (c.maxWidth < anchoEscritorio) return formulario;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(flex: 11, child: AuthPanelMarca()),
                Expanded(flex: 10, child: formulario),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Logotipo de MANI: la "M" sobre caja amarilla con sombra dura.
class ManiLogo extends StatelessWidget {
  const ManiLogo({super.key, this.tamano = 96});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    final grande = tamano >= 64;
    return ExcludeSemantics(
      child: Container(
        width: tamano,
        height: tamano,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ManiColors.brand,
          borderRadius: grande ? ManiRadius.brLg : ManiRadius.brSm,
          border: Border.all(
            color: ManiColors.border,
            width: grande ? 3 : ManiBorder.regular,
          ),
          boxShadow: [grande ? ManiShadow.lg : ManiShadow.sm],
        ),
        child: Text(
          'M',
          style: ManiText.display.copyWith(
            fontSize: tamano * 0.44,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

/// Panel de marca del escritorio: propuesta de valor e ilustración hecha con
/// formas (sin imágenes externas), en la paleta neo-brutalista.
class AuthPanelMarca extends StatelessWidget {
  const AuthPanelMarca({super.key});

  static const _puntos = [
    (
      Icons.verified_user_outlined,
      'Aliados verificados',
      'Cada técnico pasa por la revisión documental del tenant.',
    ),
    (
      Icons.request_quote_outlined,
      'Cotizaciones claras',
      'Precio, adiciones y estado de cada servicio a la vista.',
    ),
    (
      Icons.star_outline_rounded,
      'Calidad que se mide',
      'Calificaciones y quejas cierran cada servicio.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('auth-panel-marca'),
      decoration: const BoxDecoration(
        color: ManiColors.brand,
        border: Border(right: ManiBorder.side),
      ),
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: const EdgeInsets.all(ManiSpace.giant),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: c.maxHeight - ManiSpace.giant * 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: maniDecoracion(
                        sombra: ManiShadow.sm,
                        radio: ManiRadius.brSm,
                      ),
                      child: Text('M', style: ManiText.h3),
                    ),
                    ManiGap.hMd,
                    Text(
                      'MANI',
                      style: ManiText.h3.copyWith(letterSpacing: 1.5),
                    ),
                  ],
                ),
                ManiGap.vHuge,
                Text(
                  'Servicios técnicos confiables, de la solicitud al cierre.',
                  style: ManiText.h1.copyWith(
                    fontSize: c.maxWidth >= 640
                        ? ManiFontSize.display
                        : ManiFontSize.h1,
                  ),
                ),
                ManiGap.vLg,
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Text(
                    'Clientes, aliados técnicos y empresas coordinan cada '
                    'servicio en una sola plataforma.',
                    style: ManiText.bodyLg.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ManiGap.vXxxl,
                for (final (icono, titulo, texto) in _puntos) ...[
                  _PuntoValor(icono: icono, titulo: titulo, texto: texto),
                  ManiGap.vLg,
                ],
                ManiGap.vXxl,
                const _IlustracionServicio(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PuntoValor extends StatelessWidget {
  const _PuntoValor({
    required this.icono,
    required this.titulo,
    required this.texto,
  });

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(ManiSpace.sm),
          decoration: maniDecoracion(
            sombra: ManiShadow.sm,
            radio: ManiRadius.brSm,
          ),
          child: Icon(icono, size: 20, color: ManiColors.ink),
        ),
        ManiGap.hLg,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: ManiText.subtitle),
              ManiGap.vXxs,
              Text(
                texto,
                style: ManiText.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de servicio de muestra: dos tarjetas apiladas con sombra dura.
class _IlustracionServicio extends StatelessWidget {
  const _IlustracionServicio();

  @override
  Widget build(BuildContext context) {
    Widget barra(double ancho, {Color color = ManiColors.surfaceMuted}) =>
        Container(
          width: ancho,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: ManiRadius.brPill,
          ),
        );

    return ExcludeSemantics(
      child: SizedBox(
        height: 150,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: ManiSpace.huge,
              top: 0,
              right: 0,
              child: Container(
                height: 110,
                decoration: maniDecoracion(color: ManiColors.brandSoft),
              ),
            ),
            Positioned(
              left: 0,
              top: ManiSpace.xxl,
              right: ManiSpace.huge,
              child: Container(
                padding: const EdgeInsets.all(ManiSpace.lg),
                decoration: maniDecoracion(),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(ManiSpace.sm),
                      decoration: BoxDecoration(
                        color: ManiColors.brand,
                        borderRadius: ManiRadius.brSm,
                        border: Border.all(
                          color: ManiColors.border,
                          width: ManiBorder.regular,
                        ),
                      ),
                      child: const Icon(
                        Icons.plumbing_rounded,
                        color: ManiColors.ink,
                      ),
                    ),
                    ManiGap.hMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          barra(140, color: ManiColors.ink),
                          ManiGap.vSm,
                          barra(96),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ManiSpace.sm,
                        vertical: ManiSpace.xs,
                      ),
                      decoration: BoxDecoration(
                        color: ManiColors.successContainer,
                        borderRadius: ManiRadius.brPill,
                        border: Border.all(
                          color: ManiColors.border,
                          width: ManiBorder.thin,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: ManiColors.successText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opción de navegación de las pantallas de acceso (registros, enlaces):
/// tarjeta enfocable con teclado que se hunde al presionarla.
class AuthOpcion extends StatelessWidget {
  const AuthOpcion({
    super.key,
    required this.icono,
    required this.texto,
    required this.onTap,
    this.destacada = false,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  /// Borde de 2 px y sombra dura (la opción principal); las demás van planas.
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    // La sombra va fuera del Material para quedar bajo su fondo opaco.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: ManiRadius.brMd,
        boxShadow: [if (destacada) ManiShadow.sm],
      ),
      child: Material(
        color: ManiColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: ManiRadius.brMd,
          side: destacada ? ManiBorder.side : ManiBorder.sideThin,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: ManiRadius.brMd,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: ManiSpace.md,
              horizontal: ManiSpace.lg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, color: ManiColors.ink, size: 18),
                ManiGap.hSm,
                Flexible(
                  child: Text(
                    texto,
                    style: ManiText.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: ManiColors.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de envío de los registros: garantía a la izquierda y botón
/// principal a la derecha; en pantallas angostas, el botón pasa debajo y
/// ocupa todo el ancho (antes un botón fijo de 320 px desbordaba en móvil).
class AuthBarraEnvio extends StatelessWidget {
  const AuthBarraEnvio({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.etiquetaBoton,
    required this.cargando,
    required this.onPressed,
    this.icono = Icons.security_rounded,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final String etiquetaBoton;
  final bool cargando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final garantia = Row(
      children: [
        Icon(icono, color: ManiColors.ink, size: 24),
        ManiGap.hMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: ManiText.label),
              ManiGap.vXxs,
              Text(descripcion, style: ManiText.caption),
            ],
          ),
        ),
      ],
    );
    final boton = ManiButton(
      etiqueta: etiquetaBoton,
      onPressed: onPressed,
      cargando: cargando,
      expandir: true,
    );
    return Container(
      padding: const EdgeInsets.all(ManiSpace.xxl),
      decoration: maniDecoracion(),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [garantia, ManiGap.vLg, boton],
            );
          }
          return Row(
            children: [
              Expanded(child: garantia),
              ManiGap.hXxl,
              SizedBox(width: 320, child: boton),
            ],
          );
        },
      ),
    );
  }
}
