import 'dart:math';

import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/supabase_datasource.dart';
import '../models/profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseDatasource _remote;
  final LocalStorageDatasource _local;

  ProfileRepositoryImpl(this._remote, this._local);

  @override
  Future<Result<Profile?>> getCurrentProfile() async {
    try {
      final cached = await _local.getProfile();
      if (cached != null) return Success(cached);

      final deviceId = await _local.getDeviceId();
      if (deviceId == null) return const Success(null);

      final remote = await _remote.getProfileByDeviceId(deviceId);
      if (remote != null) {
        await _local.saveProfile(remote);
      }
      return Success(remote);
    } catch (e) {
      return Error(CacheFailure('Erro ao carregar perfil: $e'));
    }
  }

  @override
  Future<Result<Profile>> ensureProfile({String? nome}) async {
    try {
      final current = await _local.getProfile();
      if (current != null) return Success(current);

      final deviceId = await _getOrCreateDeviceId();
      final remote = await _remote.getProfileByDeviceId(deviceId);

      if (remote != null) {
        await _local.saveProfile(remote);
        return Success(remote);
      }

      return createProfile(nome ?? 'Usuario');
    } catch (e) {
      return Error(ServerFailure('Erro ao garantir perfil: $e'));
    }
  }

  @override
  Future<Result<Profile>> createProfile(String nome) async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      final profile = await _remote.createProfile(
        deviceId: deviceId,
        nome: nome.trim(),
      );
      await _local.saveProfile(profile);
      return Success(profile);
    } catch (e) {
      return Error(ServerFailure('Erro ao criar perfil: $e'));
    }
  }

  @override
  Future<Result<Profile>> updateProfile(Profile profile) async {
    try {
      final updated = await _remote.updateProfile(ProfileModel.fromEntity(profile));
      await _local.saveProfile(updated);
      return Success(updated);
    } catch (e) {
      return Error(ServerFailure('Erro ao atualizar perfil: $e'));
    }
  }

  @override
  Future<Result<void>> savePushToken(String token) async {
    try {
      final profile = await _local.getProfile();
      if (profile == null) return const Error(CacheFailure('Sem perfil'));

      final updated = profile.copyWith(pushToken: token);
      await _remote.updateProfile(ProfileModel.fromEntity(updated));
      await _local.saveProfile(ProfileModel.fromEntity(updated));
      return const Success(null);
    } catch (e) {
      return Error(ServerFailure('Erro ao salvar push token: $e'));
    }
  }

  @override
  Future<Result<void>> updateMyLocation({
    required String perfilId,
    required double lat,
    required double lng,
    required bool emRota,
  }) async {
    try {
      await _remote.updateLocation(
        perfilId: perfilId,
        lat: lat,
        lng: lng,
        emRota: emRota,
      );
      return const Success(null);
    } catch (e) {
      return Error(ServerFailure('Erro ao atualizar localizacao: $e'));
    }
  }

  @override
  Future<Result<Profile>> addProtectedByCode(String code) async {
    try {
      final profile = await _local.getProfile();
      if (profile == null) return const Error(CacheFailure('Perfil não encontrado'));

      final alvo = await _remote.addByCode(profile.id, code);
      if (alvo == null) return const Error(ServerFailure('Código inválido ou expirado'));

      return Success(alvo);
    } catch (e) {
      if (e.toString().contains('proprio_codigo')) {
        return const Error(ServerFailure('Você não pode adicionar seu próprio código'));
      }
      return Error(ServerFailure('Erro ao vincular pelo código: $e'));
    }
  }

  @override
  Future<Result<List<Profile>>> getMyCircle() async {
    try {
      final profile = await _local.getProfile();
      if (profile == null) return const Error(CacheFailure('Perfil não encontrado'));

      final list = await _remote.getCircle(profile.id);
      return Success(list);
    } catch (e) {
      return Error(ServerFailure('Erro ao buscar círculo: $e'));
    }
  }

  @override
  Future<Result<Map<String, dynamic>?>> getProtectedLocation(String alvoId) async {
    try {
      final profile = await _local.getProfile();
      if (profile == null) return const Error(CacheFailure('Perfil não encontrado'));

      final loc = await _remote.getLocation(solicitanteId: profile.id, alvoId: alvoId);
      return Success(loc);
    } catch (e) {
      return Error(ServerFailure('Erro ao buscar localização: $e'));
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    var id = await _local.getDeviceId();
    if (id != null) return id;

    id = 'dev_${Random().nextInt(999999)}_${DateTime.now().millisecondsSinceEpoch}';
    await _local.saveDeviceId(id);
    return id;
  }
}
