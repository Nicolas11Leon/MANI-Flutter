import 'package:flutter/material.dart';
import 'package:mani/core/routing/app_router.dart';
import 'package:mani/core/theme/app_theme.dart';

class ManiApp extends StatelessWidget {
  const ManiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      // Mismo título que web/index.html: Flutter reemplaza el de la pestaña al navegar (SCRUM-1645).
      title: 'MANI | Servicios a domicilio para tu hogar',
      theme: AppTheme.light, // Usando el tema centralizado del core
      routerConfig: appRouter, // Usando go_router
      debugShowCheckedModeBanner: false,
    );
  }
}
