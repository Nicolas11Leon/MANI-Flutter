import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mani/core/shell/sin_deslizar_menus.dart';
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
        margin: const EdgeInsets.only(top: 8),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: context.mani.background,
                borderRadius: BorderRadius.circular(ManiRadius.lg),
                border: Border.all(
                  color: context.mani.borderSubtle,
                  width: 1.5,
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
            const SizedBox(width: 8),
            Text(
              'Cargando vista previa...',
              style: TextStyle(
                fontSize: 12,
                color: context.mani.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError && _resolvedUrls.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.mani.background,
          borderRadius: BorderRadius.circular(ManiRadius.lg),
          border: Border.all(color: context.mani.borderSubtle, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 18,
              color: context.mani.inkMuted,
            ),
            const SizedBox(width: 6),
            Text(
              '${widget.fotosRutas.length} foto(s) no disponible(s)',
              style: TextStyle(fontSize: 12, color: context.mani.inkMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 16,
                  color: context.mani.ink,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.fotosRutas.length == 1
                      ? '1 foto adjunta'
                      : '${widget.fotosRutas.length} fotos adjuntas',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.mani.ink,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => _abrirDetalle(0),
              borderRadius: BorderRadius.circular(ManiRadius.sm),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.zoom_in, size: 16, color: context.mani.ink),
                    SizedBox(width: 4),
                    Text(
                      'Ver en detalle',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.mani.ink,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SinDeslizarMenus(
          child: SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.fotosRutas.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final ruta = widget.fotosRutas[index];
                final url = _resolvedUrls[ruta];

                return InkWell(
                  onTap: () => _abrirDetalle(index),
                  borderRadius: BorderRadius.circular(ManiRadius.lg),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: context.mani.background,
                      borderRadius: BorderRadius.circular(ManiRadius.lg),
                      border: Border.all(color: context.mani.ink, width: 2),
                      boxShadow: const [ManiShadow.sm],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(ManiRadius.lg - 2),
                      child: url != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 24,
                                      color: context.mani.inkMuted,
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
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.65,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
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
                          : Center(
                              child: Icon(
                                Icons.image,
                                size: 24,
                                color: context.mani.inkMuted,
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.urls.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
          child: Container(
            decoration: BoxDecoration(
              color: context.mani.surface,
              borderRadius: BorderRadius.circular(ManiRadius.lg),
              border: Border.all(color: context.mani.ink, width: 2.5),
              boxShadow: const [ManiShadow.md],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra superior
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: context.mani.ink, width: 2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: context.mani.brand,
                          borderRadius: BorderRadius.circular(ManiRadius.sm),
                          border: Border.all(
                            color: context.mani.ink,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          size: 20,
                          color: context.mani.onBrand,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Foto ${_currentIndex + 1} de $total',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: context.mani.ink,
                        ),
                      ),
                      const Spacer(),
                      Semantics(
                        button: true,
                        label: 'Cerrar vista detallada',
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(ManiRadius.sm),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: context.mani.background,
                              borderRadius: BorderRadius.circular(
                                ManiRadius.sm,
                              ),
                              border: Border.all(
                                color: context.mani.ink,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: context.mani.ink,
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
                        color: const Color(0xFF1E293B),
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
                                        SizedBox(height: 8),
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
                            borderRadius: BorderRadius.circular(ManiRadius.lg),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.mani.ink,
                                  width: 2,
                                ),
                                boxShadow: const [ManiShadow.sm],
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: context.mani.ink,
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
                            borderRadius: BorderRadius.circular(ManiRadius.lg),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.mani.ink,
                                  width: 2,
                                ),
                                boxShadow: const [ManiShadow.sm],
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 18,
                                color: context.mani.ink,
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
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.mani.background,
                      border: Border(
                        top: BorderSide(color: context.mani.ink, width: 2),
                      ),
                    ),
                    child: Center(
                      child: ListView.separated(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        itemCount: total,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final isSelected = index == _currentIndex;
                          return InkWell(
                            onTap: () => _irA(index),
                            borderRadius: BorderRadius.circular(ManiRadius.sm),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  ManiRadius.sm,
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? context.mani.ink
                                      : context.mani.borderSubtle,
                                  width: isSelected ? 2.5 : 1.5,
                                ),
                                boxShadow: isSelected
                                    ? const [ManiShadow.sm]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  ManiRadius.sm - 1,
                                ),
                                child: Image.network(
                                  widget.urls[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.broken_image,
                                    size: 20,
                                    color: context.mani.inkMuted,
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
