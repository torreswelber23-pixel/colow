import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servico em primeiro plano que mantem o app vivo (voz + localizacao +
/// Realtime) com a tela apagada / app em segundo plano.
///
/// A notificacao e DISFARCADA de proposito (parece um app generico de
/// sincronizacao), para nao denunciar a vitima caso o agressor pegue o celular.
///
/// LIMITACAO: o Android sempre mostra o "ponto verde" do microfone quando ele
/// esta em uso — isso e do sistema e nao da pra esconder.
class GuardForeground {
  static bool _inited = false;

  static void _init() {
    if (_inited) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sync_bg_service',
        channelName: 'Sincronizacao',
        channelDescription: 'Mantem os dados do app atualizados.',
        channelImportance: NotificationChannelImportance.MIN,
        priority: NotificationPriority.MIN,
        playSound: false,
        enableVibration: false,
        showWhen: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _inited = true;
  }

  /// Inicia o servico disfarcado. IMPORTANTE: no Android 14+ um servico com
  /// tipo "microphone" SO pode iniciar se a permissao de microfone ja estiver
  /// concedida — senao o sistema mata o app. Por isso pedimos antes.
  static Future<void> start() async {
    _init();

    // 1) Permissoes obrigatorias ANTES de iniciar o FGS (microphone/location).
    final mic = await Permission.microphone.request();
    await Permission.locationWhenInUse.request();
    if (!mic.isGranted) {
      debugPrint('[COLOW] Microfone negado — servico em 2o plano nao iniciado');
      return; // sem mic nao da pra iniciar FGS tipo microphone (crasharia)
    }

    // 2) Notificacoes (Android 13+) e bateria (best effort).
    try {
      await FlutterForegroundTask.requestNotificationPermission();
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (_) {}

    if (await FlutterForegroundTask.isRunningService) return;

    try {
      await FlutterForegroundTask.startService(
        serviceId: 4823,
        // Texto disfarcado — parece um servico de sistema/sincronizacao.
        notificationTitle: 'Sincronizacao',
        notificationText: 'Mantendo seus dados atualizados...',
      );
    } catch (e) {
      debugPrint('[COLOW] GuardForeground start erro: $e');
    }
  }

  static Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}
