import '../entities/profile.dart';
import '../../core/utils/result.dart';

abstract class AuthRepository {
  Stream<bool> get authStateChanges;
  Future<bool> isAuthenticated();
  Future<Result<Profile>> signInWithGoogle();
  Future<Result<Profile>> signInWithEmail(String email, String password);
  Future<Result<Profile>> signUpWithEmail(String email, String password, String nome);
  Future<void> signOut();
}
