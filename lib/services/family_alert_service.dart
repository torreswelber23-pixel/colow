import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/navigation.dart';
import '../data/datasources/supabase_datasource.dart';
import '../presentation/pages/alerta_recebido_page.dart';
import 'push_service.dart';

/// Escuta alertas da familia em tempo real (Supabase Realtime) e dispara a
/// notificacao estilo chamada quando alguem vinculado aciona o SOS / escuta.
///
/// Independe do FCM — funciona enquanto o app estiver vivo (aberto ou em
/// segundo plano com conexao Realtime ativa).
class FamilyAlertService {
  final SupabaseDatasource _remote;
  final PushService _pushService;

  FamilyAlertService(this._remote, this._pushService);

  RealtimeChannel? _channel;
  String? _currentProfileId;

  /// Comeca a ouvir alertas destinados ao perfil [profileId].
  /// Seguro chamar varias vezes — reusa a assinatura se ja estiver ativa.
  Future<void> start(String profileId) async {
    if (_currentProfileId == profileId && _channel != null) return;
    await stop();
    _currentProfileId = profileId;

    // Marcador de diagnostico: prova que start() foi chamado.
    await _remote.debugMarker(profileId, 'start_called');

    // Assina o Realtime PRIMEIRO — nao pode ser bloqueado pelo dialogo de
    // permissao de notificacao (que trava aguardando o usuario responder).
    _channel = _remote.subscribeFamilyAlerts(profileId, _onAlert);
    debugPrint('[COLOW] FamilyAlertService ouvindo alertas de $profileId');

    // Notificacoes locais como best-effort, sem travar a assinatura.
    unawaited(_pushService.initLocalNotifications());
  }

  void _onAlert(Map<String, dynamic> alerta) {
    final nome = (alerta['nome'] ?? 'Alguem que voce ama').toString();
    final tipo = alerta['tipo']?.toString();
    final id = alerta['id']?.toString();

    // Ignora marcadores de diagnostico (nao sao alertas reais).
    if (tipo == 'debug') return;

    debugPrint('[COLOW] Alerta Realtime recebido: $nome ($tipo)');

    // Sinal observavel: marca como recebido (confirma que o app recebeu).
    if (id != null) {
      _remote.markAlertReceived(id).catchError(
            (e) => debugPrint('[COLOW] erro markAlertReceived: $e'),
          );
    }

    final lat = (alerta['lat'] as num?)?.toDouble();
    final lng = (alerta['lng'] as num?)?.toDouble();
    final room = alerta['room']?.toString();
    final protegidoId = alerta['protegido_id']?.toString();

    // 1) App aberto: abre a tela cheia de alerta dentro do app.
    final nav = rootNavigatorKey.currentState;
    if (nav != null) {
      nav.push(MaterialPageRoute(
        builder: (_) => AlertaRecebidoPage(
          nome: nome,
          tipo: tipo ?? 'sos',
          lat: lat,
          lng: lng,
          room: room,
          protegidoId: protegidoId,
        ),
      ));
    }

    // 2) App em segundo plano: notificacao estilo chamada (best effort).
    _pushService.showIncomingCall(
      nome,
      tipo: tipo,
      protegidoId: protegidoId,
      lat: lat,
      lng: lng,
    );
  }

  /// Grava uma nota de diagnostico no banco (para eu inspecionar erros que
  /// nao aparecem no logcat deste aparelho).
  Future<void> logDebug(String nota) async {
    final id = _currentProfileId;
    if (id == null) return;
    final curta = nota.length > 180 ? nota.substring(0, 180) : nota;
    await _remote.debugMarker(id, curta);
  }

  Future<void> stop() async {
    if (_channel != null) {
      await _channel!.unsubscribe();
      _channel = null;
    }
    _currentProfileId = null;
  }
}
