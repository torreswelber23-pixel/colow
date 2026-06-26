import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/app_colors.dart';
import '../config/app_constants.dart';

class PushService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<String?> init() async {
    await Firebase.initializeApp();

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    await _setupLocalNotifications();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    final token = await _messaging.getToken();
    return token;
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(_emergencyChannel());
  }

  static AndroidNotificationChannel _emergencyChannel() {
    return AndroidNotificationChannel(
      AppConstants.emergencyChannelId,
      'Emergencia COLOW',
      description: 'Alertas de emergencia da rede COLOW',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      vibrationPattern: _emergencyVibration,
    );
  }

  // padrao de vibracao de emergencia (lib/alertas.js)
  static final Int64List _emergencyVibration =
      Int64List.fromList([0, 500, 300, 500, 300, 500]);

  /// Extrai o payload de alerta — replica `extrairPayload` do app antigo.
  /// E de emergencia quando tipo == familia/familia_fs ou ha protegido_id.
  static bool _isEmergency(Map<String, dynamic> data) {
    final tipo = data['tipo'];
    return tipo == 'familia' ||
        tipo == 'familia_fs' ||
        data['protegido_id'] != null;
  }

  static String _nomeFrom(Map<String, dynamic> data) {
    return (data['nome_protegido'] ?? data['nome'] ?? 'Alguem que voce ama')
        .toString();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;

    if (_isEmergency(data)) {
      _showEmergencyCall(_localNotifications, _nomeFrom(data), data['tipo']);
      return;
    }

    final notification = message.notification;
    _localNotifications.show(
      message.hashCode,
      notification?.title ?? 'COLOW',
      notification?.body ?? 'Novo alerta',
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.emergencyChannelId,
          'Emergencia COLOW',
          channelDescription: 'Alertas de emergencia da rede COLOW',
          importance: Importance.max,
          priority: Priority.max,
          color: AppColors.danger,
          icon: 'ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: data['tipo']?.toString(),
    );
  }

  /// Notificacao TELA CHEIA estilo chamada (sobre outros apps / tela bloqueada).
  /// Porta `mostrarChamada` do lib/alertas.js.
  static Future<void> _showEmergencyCall(
    FlutterLocalNotificationsPlugin plugin,
    String nome,
    Object? tipo,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      AppConstants.emergencyChannelId,
      'Emergencia COLOW',
      channelDescription: 'Alertas de emergencia da rede COLOW',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      ongoing: false,
      autoCancel: true,
      playSound: true,
      enableVibration: true,
      vibrationPattern: _emergencyVibration,
      color: AppColors.danger,
      colorized: true,
      icon: 'ic_launcher',
      timeoutAfter: 120000,
    );

    await plugin.show(
      9001, // id fixo: nao empilha varias chamadas
      '🆘 $nome precisa de ajuda',
      'Tocou o SOS no COLOW agora. Toque para ver onde esta.',
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      ),
      payload: tipo?.toString(),
    );
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }
}

@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  if (!PushService._isEmergency(data)) return;

  // App fechado/segundo plano: precisamos inicializar o plugin neste isolate.
  final plugin = FlutterLocalNotificationsPlugin();
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await plugin.initialize(initSettings);
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(PushService._emergencyChannel());

  await PushService._showEmergencyCall(
    plugin,
    PushService._nomeFrom(data),
    data['tipo'],
  );
}
