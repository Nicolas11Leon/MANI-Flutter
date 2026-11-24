import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Idioma de la app (SCRUM-1732, WCAG 3.1.1): español de Colombia.
///
/// Flutter web escribe en `<html lang>` el locale de la app, así que sin declararlo salía `en-US` y el lector de
/// pantalla leía el contenido en español con voz en inglés. Declararlo también traduce los textos del propio framework
/// (selector de fechas, «Aceptar», «Cancelar», menús contextuales).
abstract final class ManiIdioma {
  static const Locale principal = Locale('es', 'CO');

  /// Primero el de Colombia; `es` a secas cubre a quien tenga otro español configurado.
  static const List<Locale> soportados = [principal, Locale('es')];

  static const List<LocalizationsDelegate<dynamic>> delegados = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
