part of 'profile_cubit.dart';

enum ProfileStatus { initial, loading, loaded, error }

class ProfileState extends Equatable {
  final ProfileStatus status;
  final Profile? profile;
  final String? errorMessage;
  final List<Profile> circle;
  final bool isLinking;
  final bool linkSuccess;

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.errorMessage,
    this.circle = const [],
    this.isLinking = false,
    this.linkSuccess = false,
  });

  ProfileState copyWith({
    ProfileStatus? status,
    Profile? profile,
    String? errorMessage,
    List<Profile>? circle,
    bool? isLinking,
    bool? linkSuccess,
    bool clearLinkSuccess = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      errorMessage: errorMessage ?? this.errorMessage,
      circle: circle ?? this.circle,
      isLinking: isLinking ?? this.isLinking,
      linkSuccess: clearLinkSuccess ? false : (linkSuccess ?? this.linkSuccess),
    );
  }

  @override
  List<Object?> get props => [status, profile, errorMessage, circle, isLinking, linkSuccess];
}
