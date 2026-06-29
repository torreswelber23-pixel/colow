import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../core/navigation.dart';
import '../presentation/pages/alerta_recebido_page.dart';

class PushService {
  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _cachedToken;

  Future<String?> init() async {
    // Idempotente: se ja inicializou, so retorna o token (evita duplicar
    // listeners quando chamado de novo apos o login).
    if (_initialized) {
      _cachedToken ??= await _messaging?.getToken();
      return _cachedToken;
    }

    await Firebase.initializeApp();

    _messaging = FirebaseMessaging.instance;

    await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    await initLocalNotifications();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    final token = await _messaging!.getToken();
    _cachedToken = token;
    _initialized = true;
    return token;
  }

  bool _localReady = false;

  /// Inicializa SO as notificacoes locais (sem Firebase). Idempotente.
  /// Usado pelo alerta Realtime, que nao depende de FCM.
  Future<void> initLocalNotifications() async {
    if (_localReady) return;
    await _setupLocalNotifications();
    _localReady = true;
  }

  /// Mostra a notificacao estilo chamada (tela cheia) — chamavel de fora,
  /// usado quando um alerta chega via Realtime.
  Future<void> showIncomingCall(String nome,
      {String? tipo, String? protegidoId, double? lat, double? lng}) async {
    await initLocalNotifications();
    await _showEmergencyCall(_localNotifications, {
      'nome': nome,
      if (tipo != null) 'tipo': tipo,
      if (protegidoId != null) 'protegido_id': protegidoId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('ic_notification');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) => abrirAlerta(resp.payload),
    );

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Android 13+ exige permissao em runtime para exibir notificacoes.
    await android?.requestNotificationsPermission();
    await android?.createNotificationChannel(_emergencyChannel());
  }

  /// Payload pendente quando o app e aberto pela notificacao (cold start)
  /// antes do navigator estar pronto.
  static String? pendingLaunchPayload;

  /// Verifica se o app foi aberto ao tocar/abrir a notificacao (tela
  /// bloqueada / app fechado) e, se sim, abre a tela de alerta.
  Future<void> tratarAberturaPorNotificacao() async {
    final details =
        await _localNotifications.getNotificationAppLaunchDetails();
    final payload = details?.didNotificationLaunchApp == true
        ? details!.notificationResponse?.payload
        : pendingLaunchPayload;
    if (payload != null) {
      pendingLaunchPayload = null;
      abrirAlerta(payload);
    }
  }

  /// Abre a tela vermelha de alerta a partir do payload JSON da notificacao.
  static void abrirAlerta(String? payload) {
    if (payload == null || payload.isEmpty) return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final nav = rootNavigatorKey.currentState;
    if (nav == null) {
      pendingLaunchPayload = payload; // tenta de novo quando o app abrir
      return;
    }
    final pid = data['protegido_id']?.toString();
    double? toD(Object? v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
    nav.push(MaterialPageRoute(
      builder: (_) => AlertaRecebidoPage(
        nome: (data['nome'] ?? data['nome_protegido'] ?? 'Alguem que voce ama')
            .toString(),
        tipo: (data['tipo'] ?? 'sos').toString(),
        lat: toD(data['lat']),
        lng: toD(data['lng']),
        room: pid != null ? 'colow-$pid' : null,
        protegidoId: pid,
      ),
    ));
  }

  static AndroidNotificationChannel _emergencyChannel() {
    return AndroidNotificationChannel(
      AppConstants.emergencyChannelId,
      'Emergencia COLOW',
      description: 'Alertas de emergencia da rede COLOW',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      // Som de alarme (sirene) tocando no volume de ALARME — fura o silencioso.
      sound: const RawResourceAndroidNotificationSound('alarme'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableLights: true,
      vibrationPattern: _emergencyVibration,
    );
  }

  // padrao de vibracao de emergencia — longo e insistente
  static final Int64List _emergencyVibration = Int64List.fromList(
      [0, 600, 250, 600, 250, 600, 250, 1000, 400, 1000]);

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
      _showEmergencyCall(_localNotifications, data);
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
          icon: 'ic_notification',
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
    Map<String, dynamic> data,
  ) async {
    final nome = _nomeFrom(data);
    final tipo = data['tipo'];
    // payload completo para a tela de alerta abrir com localizacao + ouvir.
    final payload = jsonEncode({
      'nome': nome,
      'tipo': tipo,
      'protegido_id': data['protegido_id'],
      'lat': data['lat'],
      'lng': data['lng'],
    });
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
      sound: const RawResourceAndroidNotificationSound('alarme'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: _emergencyVibration,
      color: AppColors.danger,
      colorized: true,
      icon: 'ic_notification',
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
      payload: payload,
    );
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messaging?.subscribeToTopic(topic);
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
    android: AndroidInitializationSettings('ic_notification'),
    iOS: DarwinInitializationSettings(),
  );
  await plugin.initialize(initSettings);
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(PushService._emergencyChannel());

  await PushService._showEmergencyCall(plugin, data);
}
