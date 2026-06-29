import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../domain/entities/profile.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../../core/utils/result.dart';
import '../../../services/push_service.dart';
import '../../../services/family_alert_service.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final PushService _pushService;
  final FamilyAlertService _familyAlertService;

  AuthCubit(
    this._authRepository,
    this._profileRepository,
    this._pushService,
    this._familyAlertService,
  ) : super(const AuthState());

  /// Apos autenticar: liga a escuta de alertas em tempo real (Realtime) e,
  /// SEPARADAMENTE, tenta salvar o token FCM. O FCM nao pode bloquear o
  /// Realtime — por isso roda sem await encadeado e com timeout.
  Future<void> _onAuthenticated(Profile? profile) async {
    // 1) Realtime PRIMEIRO (e o que realmente funciona hoje).
    try {
      if (profile != null && profile.id.isNotEmpty) {
        await _familyAlertService.start(profile.id);
      }
    } catch (_) {
      // Realtime indisponivel — ignora.
    }

    // 2) Token FCM em segundo plano, sem travar nada (timeout de seguranca).
    unawaited(_trySavePushToken());
  }

  Future<void> _trySavePushToken() async {
    // getToken() na primeira vez pode demorar (registro nos servidores FCM).
    // Tenta algumas vezes com tempo generoso antes de desistir.
    for (var tentativa = 1; tentativa <= 3; tentativa++) {
      try {
        final token = await _pushService
            .init()
            .timeout(const Duration(seconds: 30), onTimeout: () => null);
        if (token != null && token.isNotEmpty) {
          await _profileRepository.savePushToken(token);
          await _familyAlertService.logDebug('fcm_ok_len${token.length}');
          return;
        } else {
          await _familyAlertService.logDebug('fcm_null_t$tentativa');
        }
      } catch (e) {
        // Grava o erro real do Firebase no banco para diagnostico.
        await _familyAlertService.logDebug('fcm_err_t$tentativa: $e');
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

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
        await _onAuthenticated(profile);
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
        await _onAuthenticated(profile);
      case Error(failure: final failure):
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: failure.message,
        ));
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    final result = await _authRepository.signInWithEmail(email, password);
    switch (result) {
      case Success(data: final profile):
        emit(state.copyWith(status: AuthStatus.authenticated, profile: profile));
        await _onAuthenticated(profile);
      case Error(failure: final failure):
        emit(state.copyWith(status: AuthStatus.unauthenticated, errorMessage: failure.message));
    }
  }

  Future<void> signUpWithEmail(String email, String password, String nome) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    final result = await _authRepository.signUpWithEmail(email, password, nome);
    switch (result) {
      case Success(data: final profile):
        emit(state.copyWith(status: AuthStatus.authenticated, profile: profile));
        await _onAuthenticated(profile);
      case Error(failure: final failure):
        emit(state.copyWith(status: AuthStatus.unauthenticated, errorMessage: failure.message));
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    emit(state.copyWith(status: AuthStatus.unauthenticated, profile: null));
  }
}
