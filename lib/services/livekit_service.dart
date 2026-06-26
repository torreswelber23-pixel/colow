import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

/// Gerencia a conexão de áudio ao vivo com o LiveKit.
///
/// Responsabilidades:
///  - Criar e conectar uma [Room] ao servidor LiveKit
///  - Habilitar/desabilitar o microfone local
///  - Expor o [ConnectionState] via stream para o cubit
///  - Garantir limpeza adequada dos recursos ao desconectar
class LiveKitService {
  Room? _room;
  final _connectionController =
      StreamController<ConnectionState>.broadcast();

  /// Stream de mudanças de estado da conexão LiveKit.
  Stream<ConnectionState> get onConnectionState =>
      _connectionController.stream;

  /// Estado atual da conexão (ou [ConnectionState.disconnected] se sem sala).
  ConnectionState get connectionState =>
      _room?.connectionState ?? ConnectionState.disconnected;

  /// Conecta à sala LiveKit com o token fornecido e ativa o microfone.
  ///
  /// [url] — URL WebSocket do servidor (ex: wss://welber-s7yegwse.livekit.cloud)
  /// [token] — JWT gerado pela Edge Function
  /// [listenOnly] — Se true, conecta apenas como ouvinte (não liga microfone)
  ///
  /// Lança exceção em caso de falha de conexão.
  Future<void> connect({
    required String url,
    required String token,
    bool listenOnly = false,
  }) async {
    // Garante que não há sala anterior pendurada
    await disconnect();

    // RoomOptions vai no construtor do Room (API >= 2.x)
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: false,
        dynacast: false,
        defaultAudioPublishOptions: AudioPublishOptions(
          name: 'colow-audio',
        ),
      ),
    );

    // Propaga mudanças de estado para o stream
    room.addListener(() {
      if (!_connectionController.isClosed) {
        _connectionController.add(room.connectionState);
      }
    });

    await room.connect(url, token);

    _room = room;

    if (!listenOnly) {
      // Habilita apenas o microfone (sem câmera)
      await room.localParticipant?.setMicrophoneEnabled(true);
    }
  }

  /// Desconecta da sala e libera todos os recursos.
  Future<void> disconnect() async {
    if (_room != null) {
      try {
        await _room!.localParticipant?.setMicrophoneEnabled(false);
        await _room!.disconnect();
      } catch (_) {
        // Ignora erros ao desconectar — sala pode já estar fechada
      }
      _room = null;
    }
  }

  /// Libera o StreamController ao descartar o service.
  Future<void> dispose() async {
    await disconnect();
    await _connectionController.close();
  }
}
