import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/env.dart';
import 'injection.dart';
import 'domain/repositories/profile_repository.dart';
import 'services/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[COLOW] Erro ao carregar .env: $e');
  }

  await Hive.initFlutter();

  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      // PKCE e o fluxo OAuth correto para mobile. O Supabase SDK captura
      // automaticamente o deep link colow://login-callback e cria a sessao.
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } catch (e) {
    debugPrint('[COLOW] Erro ao inicializar Supabase: $e');
  }

  await initDependencies();

  // Push notifications — best effort: sem google-services.json o app ainda abre.
  _initPush();

  runApp(const ColowApp());
}

Future<void> _initPush() async {
  try {
    final token = await getIt<PushService>().init();
    if (token != null) {
      // salva o token no perfil (no-op silencioso se ainda nao houver perfil)
      await getIt<ProfileRepository>().savePushToken(token);
    }
  } catch (_) {
    // Firebase nao configurado ainda — ignora.
  }
}
