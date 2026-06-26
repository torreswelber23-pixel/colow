import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/utils/result.dart';
import '../../../domain/entities/app_location.dart';
import '../../../domain/entities/contact.dart';
import '../../../domain/repositories/alert_repository.dart';
import '../../../domain/repositories/contacts_repository.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../../services/location_service.dart';

part 'emergency_state.dart';

class EmergencyCubit extends Cubit<EmergencyState> {
  final AlertRepository _alertRepository;
  final ProfileRepository _profileRepository;
  final ContactsRepository _contactsRepository;
  final LocationService _locationService;

  EmergencyCubit(
    this._alertRepository,
    this._profileRepository,
    this._contactsRepository,
    this._locationService,
  ) : super(const EmergencyState());

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
    emit(const EmergencyState());
  }
}
