import 'package:flutter/material.dart';

/// Controlador global de modo de tema (Claro / Oscuro) para MANI.
///
/// Permite alternar el tema neo-brutalista desde la barra superior (`AppShell`)
/// o desde cualquier prueba sin requerir dependencias externas.
class ManiThemeController extends ValueNotifier<ThemeMode> {
  ManiThemeController([super.initial = ThemeMode.light]);

  ThemeMode get modo => value;

  bool get esOscuro => value == ThemeMode.dark;

  void alternar() {
    value = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void fijar(ThemeMode nuevoModo) {
    value = nuevoModo;
  }
}

final ManiThemeController maniThemeController = ManiThemeController();
