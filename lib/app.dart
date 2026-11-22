import 'package:flutter/material.dart';
import 'package:mani/core/routing/app_router.dart';
import 'package:mani/core/theme/app_theme.dart';

class ManiApp extends StatelessWidget {
  const ManiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: maniThemeController,
      builder: (context, modo, _) {
        return MaterialApp.router(
          // Mismo título que web/index.html: Flutter reemplaza el de la pestaña al navegar (SCRUM-1645).
          title: 'MANI | Servicios a domicilio para tu hogar',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: modo,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
