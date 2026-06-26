part of 'onboarding_cubit.dart';

class OnboardingState extends Equatable {
  final bool isOnboarded;
  final bool isLoading;

  const OnboardingState({
    this.isOnboarded = false,
    this.isLoading = true,
  });

  OnboardingState copyWith({
    bool? isOnboarded,
    bool? isLoading,
  }) {
    return OnboardingState(
      isOnboarded: isOnboarded ?? this.isOnboarded,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [isOnboarded, isLoading];
}
