import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/utils/result.dart';
import '../../../domain/entities/profile.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/profile_repository.dart';

part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository _profileRepository;
  final AuthRepository _authRepository;

  ProfileCubit(this._profileRepository, this._authRepository)
      : super(const ProfileState());

  Future<void> loadProfile() async {
    emit(state.copyWith(status: ProfileStatus.loading));

    final result = await _profileRepository.getCurrentProfile();
    switch (result) {
      case Success(data: final profile):
        emit(state.copyWith(
          status: ProfileStatus.loaded,
          profile: profile,
        ));
        loadCircle();
      case Error(failure: final failure):
        emit(state.copyWith(
          status: ProfileStatus.error,
          errorMessage: failure.message,
        ));
    }
  }

  Future<void> createProfile(String nome) async {
    if (nome.trim().isEmpty) {
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: 'Digite seu nome',
      ));
      return;
    }

    emit(state.copyWith(status: ProfileStatus.loading));
    final result = await _profileRepository.createProfile(nome.trim());
    switch (result) {
      case Success(data: final profile):
        emit(state.copyWith(
          status: ProfileStatus.loaded,
          profile: profile,
        ));
      case Error(failure: final failure):
        emit(state.copyWith(
          status: ProfileStatus.error,
          errorMessage: failure.message,
        ));
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    emit(const ProfileState(status: ProfileStatus.initial));
  }

  Future<void> loadCircle() async {
    final result = await _profileRepository.getMyCircle();
    switch (result) {
      case Success(data: final circle):
        emit(state.copyWith(circle: circle));
      case Error():
        // ignora silenciosamente ou faz log
        break;
    }
  }

  Future<void> linkByCode(String code) async {
    if (code.trim().length != 6) {
      emit(state.copyWith(
        errorMessage: 'O código deve ter 6 caracteres',
        clearLinkSuccess: true,
      ));
      return;
    }

    emit(state.copyWith(isLinking: true, errorMessage: null, clearLinkSuccess: true));
    
    final result = await _profileRepository.addProtectedByCode(code.trim());
    switch (result) {
      case Success():
        emit(state.copyWith(isLinking: false, linkSuccess: true));
        // recarrega o círculo para incluir o novo acompanhado
        await loadCircle();
      case Error(failure: final failure):
        emit(state.copyWith(isLinking: false, errorMessage: failure.message));
    }
  }
}
