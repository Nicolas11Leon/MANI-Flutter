import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mani/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// URL de una foto adjunta: una URL absoluta se usa tal cual; una ruta del
/// bucket `solicitudes` se firma por una hora y, si la firma falla, se usa
/// la URL pública. La sesión de Supabase solo se lee cuando hay que firmar.
Future<String> resolverUrlStorage(String ruta) async {
  if (ruta.startsWith('http://') || ruta.startsWith('https://')) return ruta;
  final baseStorageUrl =
      (dotenv.isInitialized ? dotenv.env['SUPABASE_URL'] : null) ??
      'http://localhost:54321';
  final publica = '$baseStorageUrl/storage/v1/object/public/solicitudes/$ruta';
  try {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    final res = await http.post(
      Uri.parse('$baseStorageUrl/storage/v1/object/sign/solicitudes/$ruta'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'expiresIn': 3600}),
    );
    if (res.statusCode != 200) return publica;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final rawSigned = (data['signedURL'] ?? data['signedUrl'] ?? '').toString();
    return rawSigned.startsWith('http')
        ? rawSigned
        : '$baseStorageUrl$rawSigned';
  } catch (_) {
    return publica;
  }
}

/// Visor y miniatura de fotos adjuntas a una solicitud.
/// Permite al aliado ver una preview inmediata y abrir un diálogo
/// para examinar cada foto a mayor resolución con zoom interactivo.
class FotosAdjuntasPreview extends StatefulWidget {
  const FotosAdjuntasPreview({
    super.key,
    required this.fotosRutas,
    this.solicitudId,
    this.resolverUrl = resolverUrlStorage,
  });

  final List<String> fotosRutas;
  final String? solicitudId;

  /// Convierte la ruta guardada de una foto en una URL que se puede mostrar.
  /// Por omisión firma la ruta en Storage ([resolverUrlStorage]); las pruebas
  /// pasan otra para no depender de Supabase ni de la red.
  final Future<String> Function(String ruta) resolverUrl;

  @override
  State<FotosAdjuntasPreview> createState() => _FotosAdjuntasPreviewState();
}

class _FotosAdjuntasPreviewState extends State<FotosAdjuntasPreview> {
  final Map<String, String> _resolvedUrls = {};
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadUrls();
  }

  @override
  void didUpdateWidget(covariant FotosAdjuntasPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fotosRutas != widget.fotosRutas) {
      _loadUrls();
    }
  }

  Future<void> _loadUrls() async {
    if (widget.fotosRutas.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      for (final ruta in widget.fotosRutas) {
        _resolvedUrls[ruta] = await widget.resolverUrl(ruta);
      }
    } catch (_) {
      _hasError = true;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _abrirDetalle(int initialIndex) {
    final validUrls = widget.fotosRutas
        .map((r) => _resolvedUrls[r])
        .whereType<String>()
        .toList();

    if (validUrls.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) =>
          FotosDetalleDialog(urls: validUrls, initialIndex: initialIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fotosRutas.isEmpty) return const SizedBox.shrink();

    if (_loading) {
      return Container(
        height: 74,
        margin: const EdgeInsets.only(top: ManiSpace.sm),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: ManiColors.background,
                borderRadius: ManiRadius.brSm,
                border: Border.all(
                  color: ManiColors.borderSubtle,
                  width: ManiBorder.thin,
                ),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            ManiGap.hSm,
            const Text(
              'Cargando vista previa...',
              style: TextStyle(
                fontSize: ManiFontSize.caption,
                color: ManiColors.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError && _resolvedUrls.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: ManiSpace.sm),
        padding: const EdgeInsets.all(ManiSpace.sm),
        decoration: BoxDecoration(
          color: ManiColors.background,
          borderRadius: ManiRadius.brSm,
          border: Border.all(
            color: ManiColors.borderSubtle,
            width: ManiBorder.thin,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              size: 18,
              color: ManiColors.inkMuted,
            ),
            ManiGap.hSm,
            Text(
              '${widget.fotosRutas.length} foto(s) no disponible(s)',
              style: const TextStyle(
                fontSize: ManiFontSize.caption,
                color: ManiColors.inkMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManiGap.vSm,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  size: 16,
                  color: ManiColors.ink,
                ),
                ManiGap.hSm,
                Text(
                  widget.fotosRutas.length == 1
                      ? '1 foto adjunta'
                      : '${widget.fotosRutas.length} fotos adjuntas',
                  style: const TextStyle(
                    fontSize: ManiFontSize.caption,
                    fontWeight: FontWeight.w800,
                    color: ManiColors.ink,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => _abrirDetalle(0),
              borderRadius: ManiRadius.brXs,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ManiSpace.sm,
                  vertical: ManiSpace.xxs,
                ),
                child: Row(
                  children: const [
                    Icon(Icons.zoom_in, size: 16, color: ManiColors.ink),
                    ManiGap.hXs,
                    Text(
                      'Ver en detalle',
                      style: TextStyle(
                        fontSize: ManiFontSize.caption,
                        fontWeight: FontWeight.w800,
                        color: ManiColors.ink,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ManiGap.vSm,
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.fotosRutas.length,
            separatorBuilder: (_, _) => ManiGap.hSm,
            itemBuilder: (context, index) {
              final ruta = widget.fotosRutas[index];
              final url = _resolvedUrls[ruta];

              return InkWell(
                onTap: () => _abrirDetalle(index),
                borderRadius: ManiRadius.brSm,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: ManiColors.background,
                    borderRadius: ManiRadius.brSm,
                    border: Border.all(
                      color: ManiColors.border,
                      width: ManiBorder.regular,
                    ),
                    boxShadow: const [ManiShadow.sm],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(ManiRadius.sm - 2),
                    child: url != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 24,
                                    color: ManiColors.inkMuted,
                                  ),
                                ),
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              Positioned(
                                right: 3,
                                bottom: 3,
                                child: Container(
                                  padding: const EdgeInsets.all(ManiSpace.xxs),
                                  decoration: BoxDecoration(
                                    color: ManiColors.ink.withValues(
                                      alpha: 0.65,
                                    ),
                                    borderRadius: ManiRadius.brXs,
                                  ),
                                  child: const Icon(
                                    Icons.fullscreen,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Center(
                            child: Icon(
                              Icons.image,
                              size: 24,
                              color: ManiColors.inkMuted,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Diálogo modal a mayor detalle para examinar las fotos con zoom y carrusel.
class FotosDetalleDialog extends StatefulWidget {
  const FotosDetalleDialog({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<FotosDetalleDialog> createState() => _FotosDetalleDialogState();
}

class _FotosDetalleDialogState extends State<FotosDetalleDialog> {
  late int _currentIndex;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _irA(int index) {
    if (index >= 0 && index < widget.urls.length) {
      _pageController.animateToPage(
        index,
        duration: ManiMotion.base,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.urls.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: ManiSpace.lg,
        vertical: ManiSpace.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
          child: Container(
            decoration: BoxDecoration(
              color: ManiColors.surface,
              borderRadius: ManiRadius.brMd,
              border: Border.all(
                color: ManiColors.border,
                width: ManiBorder.thick,
              ),
              boxShadow: const [ManiShadow.md],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra superior
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ManiSpace.lg,
                    vertical: ManiSpace.md,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(bottom: ManiBorder.side),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(ManiSpace.sm),
                        decoration: BoxDecoration(
                          color: ManiColors.brand,
                          borderRadius: ManiRadius.brXs,
                          border: Border.all(
                            color: ManiColors.border,
                            width: ManiBorder.thin,
                          ),
                        ),
                        child: const Icon(
                          Icons.image_outlined,
                          size: 20,
                          color: ManiColors.ink,
                        ),
                      ),
                      ManiGap.hSm,
                      Text(
                        'Foto ${_currentIndex + 1} de $total',
                        style: const TextStyle(
                          fontSize: ManiFontSize.bodyLg,
                          fontWeight: FontWeight.w900,
                          color: ManiColors.ink,
                        ),
                      ),
                      const Spacer(),
                      Semantics(
                        button: true,
                        label: 'Cerrar vista detallada',
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: ManiRadius.brXs,
                          child: Container(
                            padding: const EdgeInsets.all(ManiSpace.sm),
                            decoration: BoxDecoration(
                              color: ManiColors.background,
                              borderRadius: ManiRadius.brXs,
                              border: Border.all(
                                color: ManiColors.border,
                                width: ManiBorder.thin,
                              ),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 20,
                              color: ManiColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Área principal de la imagen con zoom
                Flexible(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        color: ManiColors.ink,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: total,
                          onPageChanged: (idx) =>
                              setState(() => _currentIndex = idx),
                          itemBuilder: (context, index) {
                            return InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 4.0,
                              child: Center(
                                child: Image.network(
                                  widget.urls[index],
                                  fit: BoxFit.contain,
                                  loadingBuilder: (_, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          size: 48,
                                          color: Colors.white54,
                                        ),
                                        ManiGap.vSm,
                                        Text(
                                          'No se pudo cargar la imagen',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Botón Anterior
                      if (total > 1 && _currentIndex > 0)
                        Positioned(
                          left: 12,
                          child: InkWell(
                            onTap: () => _irA(_currentIndex - 1),
                            borderRadius: ManiRadius.brSm,
                            child: Container(
                              padding: const EdgeInsets.all(ManiSpace.sm),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ManiColors.border,
                                  width: ManiBorder.regular,
                                ),
                                boxShadow: const [ManiShadow.sm],
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: ManiColors.ink,
                              ),
                            ),
                          ),
                        ),

                      // Botón Siguiente
                      if (total > 1 && _currentIndex < total - 1)
                        Positioned(
                          right: 12,
                          child: InkWell(
                            onTap: () => _irA(_currentIndex + 1),
                            borderRadius: ManiRadius.brSm,
                            child: Container(
                              padding: const EdgeInsets.all(ManiSpace.sm),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ManiColors.border,
                                  width: ManiBorder.regular,
                                ),
                                boxShadow: const [ManiShadow.sm],
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 18,
                                color: ManiColors.ink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Barra inferior con miniaturas selectoras (si hay más de una foto)
                if (total > 1)
                  Container(
                    height: 72,
                    padding: const EdgeInsets.symmetric(
                      horizontal: ManiSpace.lg,
                      vertical: ManiSpace.sm,
                    ),
                    decoration: const BoxDecoration(
                      color: ManiColors.background,
                      border: Border(top: ManiBorder.side),
                    ),
                    child: Center(
                      child: ListView.separated(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        itemCount: total,
                        separatorBuilder: (_, _) => ManiGap.hSm,
                        itemBuilder: (context, index) {
                          final isSelected = index == _currentIndex;
                          return InkWell(
                            onTap: () => _irA(index),
                            borderRadius: ManiRadius.brXs,
                            child: AnimatedContainer(
                              duration: ManiMotion.base,
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: ManiRadius.brXs,
                                border: Border.all(
                                  color: isSelected
                                      ? ManiColors.ink
                                      : ManiColors.borderSubtle,
                                  width: isSelected ? 2.5 : 1.5,
                                ),
                                boxShadow: isSelected
                                    ? const [ManiShadow.sm]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  ManiRadius.xs - 1,
                                ),
                                child: Image.network(
                                  widget.urls[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.broken_image,
                                    size: 20,
                                    color: ManiColors.inkMuted,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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
