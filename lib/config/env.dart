import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get mapboxPublicToken => dotenv.env['MAPBOX_PUBLIC_TOKEN'] ?? '';
  static String get livekitUrl => dotenv.env['LIVEKIT_URL'] ?? '';
}
