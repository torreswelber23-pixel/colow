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
      // No mobile, o Supabase abre o navegador/in-app e retorna a sessao.
      // O redirect fica a cargo do supabase_flutter + deep link config.
      final response = await _remote.signInWithGoogle('colow://login-callback');

      final user = _remote.currentSession?.user;
      if (user == null) {
        return const Error(AuthFailure('Login nao completado'));
      }

      final profile = await _ensureProfileForUser(user);
      await _local.saveProfile(ProfileModel.fromEntity(profile));

      return Success(profile);
    } catch (e) {
      return Error(AuthFailure('Erro no login: $e'));
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
