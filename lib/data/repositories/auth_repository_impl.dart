import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/supabase_datasource.dart';
import '../models/profile_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseDatasource _remote;
  final LocalStorageDatasource _local;

  AuthRepositoryImpl(this._remote, this._local);

  @override
  Stream<bool> get authStateChanges {
    return _remote.authStateChanges.map((state) {
      return state.session?.user != null;
    });
  }

  @override
  Future<bool> isAuthenticated() async {
    return _remote.currentSession?.user != null;
  }

  @override
  Future<Result<Profile>> signInWithGoogle() async {
    try {
      final authCompleter = Completer<User>();

      final subscription = _remote.authStateChanges.listen((data) {
        if (data.session?.user != null && !authCompleter.isCompleted) {
          authCompleter.complete(data.session!.user);
        }
      });

      await _remote.signInWithGoogle('colow://login-callback');

      final user = await authCompleter.future.timeout(const Duration(seconds: 60));
      await subscription.cancel();

      final profile = await _ensureProfileForUser(user);
      await _local.saveProfile(ProfileModel.fromEntity(profile));

      return Success(profile);
    } catch (e) {
      return Error(AuthFailure('Erro no login: $e'));
    }
  }

  @override
  Future<Result<Profile>> signInWithEmail(String email, String password) async {
    try {
      final user = await _remote.signInWithEmail(email, password);
      final profile = await _ensureProfileForUser(user);
      await _local.saveProfile(ProfileModel.fromEntity(profile));
      return Success(profile);
    } catch (e) {
      return Error(AuthFailure('Email ou senha incorretos'));
    }
  }

  @override
  Future<Result<Profile>> signUpWithEmail(String email, String password, String nome) async {
    try {
      final user = await _remote.signUpWithEmail(email, password);
      final existing = await _remote.getProfileByUserId(user.id);
      if (existing != null) {
        await _local.saveProfile(existing);
        return Success(existing);
      }
      final profile = await _remote.createProfile(
        deviceId: user.id,
        nome: nome.trim().isEmpty ? email.split('@').first : nome.trim(),
        userId: user.id,
      );
      await _local.saveProfile(ProfileModel.fromEntity(profile));
      return Success(profile);
    } catch (e) {
      return Error(AuthFailure('Erro ao criar conta: $e'));
    }
  }

  @override
  Future<void> signOut() async {
    await _remote.signOut();
    await _local.clearProfile();
  }

  Future<Profile> _ensureProfileForUser(User user) async {
    final existing = await _remote.getProfileByUserId(user.id);
    if (existing != null) return existing;

    final meta = user.userMetadata ?? {};
    final nome = meta['full_name'] as String? ??
        meta['name'] as String? ??
        (user.email ?? '').split('@').firstOrNull ??
        'Usuaria';

    return await _remote.createProfile(
      deviceId: user.id,
      nome: nome,
      userId: user.id,
    );
  }
}
