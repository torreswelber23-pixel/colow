import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

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

part 'emergency_state.dart';

class EmergencyCubit extends Cubit<EmergencyState> {
  final AlertRepository _alertRepository;
  final ProfileRepository _profileRepository;
  final ContactsRepository _contactsRepository;
  final LocationService _locationService;
  final LiveKitService _liveKitService;

  EmergencyCubit(
    this._alertRepository,
    this._profileRepository,
    this._contactsRepository,
    this._locationService,
    this._liveKitService,
  ) : super(const EmergencyState());

  Timer? _locTimer;

  /// Envia a localizacao continuamente (estilo Uber) para a tabela
  /// localizacoes, que a familia acompanha em tempo real no mapa.
  void _iniciarEnvioLocalizacao(String perfilId) {
    _locTimer?.cancel();
    Future<void> enviar() async {
      final loc = await _locationService.getCurrentLocation();
      if (loc == null) return;
      await _profileRepository.updateMyLocation(
        perfilId: perfilId,
        lat: loc.lat,
        lng: loc.lng,
        emRota: true,
      );
    }

    enviar(); // primeiro ponto imediato
    _locTimer = Timer.periodic(const Duration(seconds: 5), (_) => enviar());
  }

  void pararEnvioLocalizacao() {
    _locTimer?.cancel();
    _locTimer = null;
  }

  /// Liga o microfone transmitindo para a sala da pessoa, pra familia ouvir
  /// ao vivo assim que tocar "Ouvir ao vivo". Best-effort: nao derruba o SOS.
  Future<void> _ligarAudioTransmissao(Profile profile) async {
    try {
      final tokenResult = await _alertRepository.getLiveKitToken(
        roomName: 'colow-${profile.id}',
        participantName: profile.nome,
      );
      if (tokenResult case Success(data: final token)) {
        await _liveKitService.connect(
          url: Env.livekitUrl,
          token: token,
          // listenOnly: false -> publica o microfone (transmite).
        );
      }
    } catch (_) {
      // Sem audio nao impede o alerta/localizacao.
    }
  }

  Future<void> triggerSos() async {
    if (state.status == EmergencyStatus.loading || state.isPanicking) return;

    emit(state.copyWith(
      status: EmergencyStatus.loading,
      isPanicking: true,
      clearError: true,
    ));

    try {
      // 1. Obter Perfil
      final profileResult = await _profileRepository.getCurrentProfile();
      final profile = switch (profileResult) {
        Success(data: final p) => p,
        Error() => null,
      };

      if (profile == null) {
        emit(state.copyWith(
          status: EmergencyStatus.error,
          errorMessage: 'Perfil não encontrado. Faça login novamente.',
          isPanicking: false,
        ));
        return;
      }

      // 2. Obter Contatos
      final contactsResult = await _contactsRepository.getContacts();
      final contacts = switch (contactsResult) {
        Success(data: final c) => c,
        Error() => <Contact>[],
      };

      if (contacts.isEmpty) {
        emit(state.copyWith(
          status: EmergencyStatus.error,
          errorMessage: 'Você não tem contatos de emergência cadastrados.',
          isPanicking: false,
        ));
        return;
      }

      // 3. Obter Localização atual
      final loc = await _locationService.getCurrentLocation();
      final appLoc = loc ?? AppLocation(lat: 0, lng: 0);

      // 4. Disparar SOS
      final sosResult = await _alertRepository.sendSos(
        location: appLoc,
        nome: profile.nome,
        message: 'EMERGÊNCIA! ${profile.nome} precisa de ajuda urgente!',
        contacts: contacts,
        protegidoId: profile.id,
      );

      switch (sosResult) {
        case Success():
          // Liga o audio ao vivo (microfone transmitindo) e o envio continuo
          // de localizacao (estilo Uber) para a familia acompanhar no mapa.
          await _ligarAudioTransmissao(profile);
          _iniciarEnvioLocalizacao(profile.id);
          emit(state.copyWith(status: EmergencyStatus.success));
        case Error(failure: final f):
          emit(state.copyWith(
            status: EmergencyStatus.error,
            errorMessage: f.message,
            isPanicking: false, // se falhou silenciosamente, podemos manter ou não, mas é erro
          ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: EmergencyStatus.error,
        errorMessage: 'Erro inesperado: $e',
        isPanicking: false,
      ));
    }
  }

  void resetEmergency() {
    pararEnvioLocalizacao();
    emit(const EmergencyState());
  }

  @override
  Future<void> close() {
    _locTimer?.cancel();
    return super.close();
  }
}
