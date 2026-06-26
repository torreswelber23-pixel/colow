import '../entities/profile.dart';
import '../../core/utils/result.dart';

abstract class AuthRepository {
  Stream<bool> get authStateChanges;
  Future<bool> isAuthenticated();
  Future<Result<Profile>> signInWithGoogle();
  Future<void> signOut();
}
