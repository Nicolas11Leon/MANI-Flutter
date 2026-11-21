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
          title: 'MANI Services',
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
