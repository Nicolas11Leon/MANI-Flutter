import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mani/app.dart';
import 'package:mani/core/di/injection_container.dart' as di;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno desde el archivo .env
  await dotenv.load(fileName: ".env");

  // Inicializar Supabase usando las variables de entorno
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Inicializar inyección de dependencias
  await di.init();

  runApp(const ManiApp());
}
