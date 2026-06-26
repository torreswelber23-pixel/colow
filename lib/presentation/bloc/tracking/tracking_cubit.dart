import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../config/app_constants.dart';
import '../../../config/env.dart';
import '../../../core/utils/result.dart';
import '../../../domain/entities/app_location.dart';
import '../../../domain/entities/profile.dart';
import '../../../domain/repositories/alert_repository.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../../services/livekit_service.dart';

part 'tracking_state.dart';

class TrackingCubit extends Cubit<TrackingState> {
  final ProfileRepository _profileRepository;
  final AlertRepository _alertRepository;
  final LiveKitService _liveKitService;

  Timer? _pollingTimer;
  StreamSubscription<ConnectionState>? _audioStateSub;

  TrackingCubit(
    this._profileRepository,
    this._alertRepository,
    this._liveKitService,
    Profile alvo,
  ) : super(TrackingState(alvo: alvo));

  void startTracking() {
    emit(state.copyWith(status: TrackingStatus.active));
    _fetchLocation();

    _pollingTimer = Timer.periodic(
      const Duration(seconds: AppConstants.trackingLocationIntervalSeconds),
      (_) => _fetchLocation(),
    );
  }

  Future<void> _fetchLocation() async {
    final result = await _profileRepository.getProtectedLocation(state.alvo.id);
    switch (result) {
      case Success(data: final locData):
        if (locData != null) {
          final lat = (locData['lat'] as num).toDouble();
          final lng = (locData['lng'] as num).toDouble();
          final emRota = locData['em_rota'] == true;
          
          emit(state.copyWith(
            lastLocation: AppLocation(lat: lat, lng: lng),
            lastUpdate: DateTime.now(),
            isAlvoEmRota: emRota,
          ));

          if (!emRota) {
            // Se não está mais em rota, a corrida acabou
            stopTracking();
          }
        }
      case Error():
        // Pode haver erro temporário de rede, não paramos o tracking
        break;
    }
  }

  void stopTracking() {
    _pollingTimer?.cancel();
    _disconnectAudio();
    if (!isClosed) {
      emit(state.copyWith(status: TrackingStatus.finished));
    }
  }

  // ---------------------------------------------------------------------------
  // Áudio ao vivo — LiveKit (Apenas ouvir)
  // ---------------------------------------------------------------------------
  Future<void> toggleListening() async {
    switch (state.audioStatus) {
      case AudioListenStatus.idle:
      case AudioListenStatus.error:
        await _startListening();
      case AudioListenStatus.connecting:
      case AudioListenStatus.playing:
        await _disconnectAudio();
    }
  }

  Future<void> _startListening() async {
    emit(state.copyWith(
      audioStatus: AudioListenStatus.connecting,
      clearAudioError: true,
    ));

    // A sala que o protegido cria tem o nome colow-{protegidoId}
    final roomName = 'colow-${state.alvo.id}';
    
    // Obter nosso próprio perfil para passar como nome de participante
    final myProfileResult = await _profileRepository.getCurrentProfile();
    final myName = switch (myProfileResult) {
      Success(data: final p) => p?.nome ?? 'Guardião',
      Error() => 'Guardião',
    };

    final tokenResult = await _alertRepository.getLiveKitToken(
      roomName: roomName,
      participantName: myName,
    );

    switch (tokenResult) {
      case Error(failure: final f):
        emit(state.copyWith(
          audioStatus: AudioListenStatus.error,
          audioError: f.message,
        ));
        return;
      case Success(data: final token):
        try {
          // Conecta apenas como ouvinte (listenOnly: true)
          await _liveKitService.connect(
            url: Env.livekitUrl,
            token: token,
            listenOnly: true,
          );

          emit(state.copyWith(audioStatus: AudioListenStatus.playing));

          _audioStateSub?.cancel();
          _audioStateSub = _liveKitService.onConnectionState.listen(
            (cs) {
              if (isClosed) return;
              if (cs == ConnectionState.disconnected &&
                  state.audioStatus == AudioListenStatus.playing) {
                emit(state.copyWith(
                  audioStatus: AudioListenStatus.error,
                  audioError: 'Áudio encerrado pelo protegido ou conexão perdida.',
                ));
              }
            },
          );
        } catch (e) {
          emit(state.copyWith(
            audioStatus: AudioListenStatus.error,
            audioError: 'Falha ao ouvir: ${e.toString()}',
          ));
        }
    }
  }

  Future<void> _disconnectAudio() async {
    _audioStateSub?.cancel();
    _audioStateSub = null;
    await _liveKitService.disconnect();
    if (!isClosed) {
      emit(state.copyWith(
        audioStatus: AudioListenStatus.idle,
        clearAudioError: true,
      ));
    }
  }

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    _audioStateSub?.cancel();
    _liveKitService.disconnect();
    return super.close();
  }
}
