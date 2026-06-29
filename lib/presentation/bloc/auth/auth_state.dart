part of 'auth_cubit.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final Profile? profile;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.profile,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    Profile? profile,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, profile, errorMessage];
}
