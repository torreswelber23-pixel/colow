import '../entities/profile.dart';
import '../../core/utils/result.dart';

abstract class ProfileRepository {
  Future<Result<Profile?>> getCurrentProfile();
  Future<Result<Profile>> ensureProfile({String? nome});
  Future<Result<Profile>> createProfile(String nome);
  Future<Result<Profile>> updateProfile(Profile profile);
  Future<Result<void>> savePushToken(String token);
  Future<Result<void>> updateMyLocation({
    required String perfilId,
    required double lat,
    required double lng,
    required bool emRota,
  });
  Future<Result<Profile>> addProtectedByCode(String code);
  Future<Result<List<Profile>>> getMyCircle();
  Future<Result<Map<String, dynamic>?>> getProtectedLocation(String alvoId);
}
