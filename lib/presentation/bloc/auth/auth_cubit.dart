import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../domain/entities/profile.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../../core/utils/result.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;

  AuthCubit(this._authRepository, this._profileRepository)
      : super(const AuthState());

  Future<void> checkAuth() async {
    emit(state.copyWith(status: AuthStatus.loading));

    final isAuth = await _authRepository.isAuthenticated();
    if (!isAuth) {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
      return;
    }

    final result = await _profileRepository.getCurrentProfile();
    switch (result) {
      case Success(data: final profile):
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          profile: profile,
        ));
      case Error(failure: _):
        emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> signInWithGoogle() async {
    emit(state.copyWith(status: AuthStatus.loading));

    final result = await _authRepository.signInWithGoogle();
    switch (result) {
      case Success(data: final profile):
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          profile: profile,
        ));
      case Error(failure: final failure):
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: failure.message,
        ));
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    emit(state.copyWith(status: AuthStatus.unauthenticated, profile: null));
  }
}
