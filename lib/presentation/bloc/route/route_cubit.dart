import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../config/app_constants.dart';
import '../../../config/env.dart';
import '../../../core/utils/result.dart';
import '../../../domain/entities/app_location.dart';
import '../../../domain/entities/contact.dart';
import '../../../domain/entities/profile.dart';
import '../../../domain/repositories/alert_repository.dart';
import '../../../domain/repositories/contacts_repository.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../../services/livekit_service.dart';
import '../../../services/location_service.dart';
import '../../../services/messaging_service.dart';
import '../../../services/voice_service.dart';
import '../../../data/datasources/local_storage_datasource.dart';

part 'route_state.dart';

class RouteCubit extends Cubit<RouteState> {
  final AlertRepository _alertRepository;
  final ContactsRepository _contactsRepository;
  final ProfileRepository _profileRepository;
  final LocationService _locationService;
  final MessagingService _messagingService;
  final LiveKitService _liveKitService;
  final VoiceService _voiceService;
  final LocalStorageDatasource _storage;

  Timer? _locationTimer;
  StreamSubscription<AppLocation>? _locationSub;
  StreamSubscription<ConnectionState>? _audioStateSub;

  RouteCubit(
    this._alertRepository,
    this._contactsRepository,
    this._profileRepository,
    this._locationService,
    this._messagingService,
    this._liveKitService,
    this._voiceService,
    this._storage,
  ) : super(const RouteState());

  Future<void> startRoute() async {
    emit(state.copyWith(status: RouteStatus.loading));

    final profileResult = await _profileRepository.getCurrentProfile();
    final contactsResult = await _contactsRepository.getContacts();
    final location = await _locationService.getCurrentLocation();

    final profile = switch (profileResult) {
      Success(data: final p) => p,
      Error() => null,
    };

    final contacts = switch (contactsResult) {
      Success(data: final list) => list,
      Error() => <Contact>[],
    };

    emit(state.copyWith(
      status: RouteStatus.active,
      profile: profile,
      contacts: contacts,
      location: location,
    ));

    if (profile?.id != null) {
      await _alertRepository.notifyRouteStarted(
        protegidoId: profile!.id,
        nome: profile.nome,
        location: location,
      );
    }

    _startLocationUpdates(profile);
    await _startVoiceRecognition();
  }

  Future<void> _startVoiceRecognition() async {
    final codeWord = await _storage.getCodeWord();
    if (codeWord != null && codeWord.trim().isNotEmpty) {
      await _voiceService.startContinuousListening(
        targetWord: codeWord,
        onWordDetected: () async {
          if (!state.isSendingSos && !state.sosSent) {
            await sendSos();
            if (state.audioStatus != AudioStatus.live) {
              await toggleFamilyListening();
            }
          }
        },
      );
    }
  }

  void _startLocationUpdates(Profile? profile) {
    _locationSub?.cancel();
    _locationTimer?.cancel();

    _locationSub = _locationService.getLocationStream().listen((location) {
      emit(state.copyWith(location: location));
    });

    _locationTimer = Timer.periodic(
      const Duration(seconds: AppConstants.routeLocationIntervalSeconds),
      (_) async {
        final loc = state.location ?? await _locationService.getCurrentLocation();
        if (loc == null || profile?.id == null) return;

        // espelha quem me acompanha (lib/circulo.js -> atualizarLocal)
        await _profileRepository.updateMyLocation(
          perfilId: profile!.id,
          lat: loc.lat,
          lng: loc.lng,
          emRota: true,
        );
      },
    );
  }

  Future<void> sendSos() async {
    final location = state.location ?? await _locationService.getCurrentLocation();
    if (location == null) {
      emit(state.copyWith(errorMessage: 'Localizacao indisponivel'));
      return;
    }

    emit(state.copyWith(isSendingSos: true));

    // 1. dispara o alerta na rede (banco + push familia/guardioes)
    await _alertRepository.sendSos(
      location: location,
      nome: state.profile?.nome ?? 'Passageira',
      message: 'SOS na corrida',
      contacts: state.contacts,
      protegidoId: state.profile?.id,
    );

    emit(state.copyWith(
      isSendingSos: false,
      sosSent: true,
    ));

    // 2. abre WhatsApp/SMS pra familia — ou propoe ligar 190 se nao ha contatos
    if (state.contacts.isNotEmpty) {
      await _messagingService.sendSosToContacts(state.contacts, location);
    } else {
      emit(state.copyWith(promptCall190: true));
    }

    Future.delayed(const Duration(seconds: 5), () {
      if (!isClosed) emit(state.copyWith(sosSent: false));
    });
  }

  Future<void> arrived() async {
    final location = state.location ?? await _locationService.getCurrentLocation();
    await _messagingService.sendArrivalToContacts(state.contacts, location);
    _locationSub?.cancel();
    _locationTimer?.cancel();
    // Desconecta o áudio e voz ao encerrar a rota
    await _voiceService.stopListening();
    await _disconnectAudio();
    emit(state.copyWith(status: RouteStatus.finished));
  }

  /// Liga para a policia (190) e limpa o aviso.
  Future<void> call190() async {
    emit(state.copyWith(promptCall190: false));
    await _messagingService.call190();
  }

  void clearCall190Prompt() {
    emit(state.copyWith(promptCall190: false));
  }

  // ---------------------------------------------------------------------------
  // Áudio ao vivo — LiveKit
  // ---------------------------------------------------------------------------

  /// Ativa ou desativa a transmissão de áudio ao vivo para a família.
  ///
  /// - Se [AudioStatus.idle] ou [AudioStatus.error] → conecta ao LiveKit
  /// - Se [AudioStatus.live] ou [AudioStatus.connecting] → desconecta
  Future<void> toggleFamilyListening() async {
    switch (state.audioStatus) {
      case AudioStatus.idle:
      case AudioStatus.error:
        await _startAudio();
      case AudioStatus.connecting:
      case AudioStatus.live:
        await _disconnectAudio();
    }
  }

  Future<void> _startAudio() async {
    final profile = state.profile;
    if (profile == null) {
      emit(state.copyWith(
        audioStatus: AudioStatus.error,
        audioError: 'Perfil não disponível',
      ));
      return;
    }

    emit(state.copyWith(
      audioStatus: AudioStatus.connecting,
      clearAudioError: true,
    ));

    // 1. Busca o token JWT do LiveKit via Edge Function
    final roomName = 'colow-${profile.id}';
    final tokenResult = await _alertRepository.getLiveKitToken(
      roomName: roomName,
      participantName: profile.nome,
    );

    switch (tokenResult) {
      case Error(failure: final f):
        emit(state.copyWith(
          audioStatus: AudioStatus.error,
          audioError: f.message,
        ));
        return;
      case Success(data: final token):
        try {
          // 2. Conecta à sala LiveKit e ativa microfone
          await _liveKitService.connect(
            url: Env.livekitUrl,
            token: token,
          );

          // 3. Notifica a família que a escuta foi ativada
          if (profile.id.isNotEmpty) {
            await _alertRepository.notifyListeningStarted(
              protegidoId: profile.id,
              nome: profile.nome,
              location: state.location,
            );
          }

          emit(state.copyWith(audioStatus: AudioStatus.live));

          // 4. Monitora desconexões inesperadas do LiveKit
          _audioStateSub?.cancel();
          _audioStateSub = _liveKitService.onConnectionState.listen(
            (cs) {
              if (isClosed) return;
              // Se o servidor desconectar de forma inesperada
              if (cs == ConnectionState.disconnected &&
                  state.audioStatus == AudioStatus.live) {
                emit(state.copyWith(
                  audioStatus: AudioStatus.error,
                  audioError: 'Conexão perdida. Toque para reconectar.',
                ));
              }
            },
          );
        } catch (e) {
          emit(state.copyWith(
            audioStatus: AudioStatus.error,
            audioError: 'Falha ao conectar: ${e.toString()}',
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
        audioStatus: AudioStatus.idle,
        clearAudioError: true,
      ));
    }
  }

  @override
  Future<void> close() {
    _locationSub?.cancel();
    _locationTimer?.cancel();
    _audioStateSub?.cancel();
    _liveKitService.disconnect();
    _voiceService.stopListening();
    return super.close();
  }
}
