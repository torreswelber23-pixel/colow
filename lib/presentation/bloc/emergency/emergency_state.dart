part of 'emergency_cubit.dart';

enum EmergencyStatus { idle, loading, success, error }

class EmergencyState extends Equatable {
  final EmergencyStatus status;
  final String? errorMessage;
  final bool isPanicking;

  const EmergencyState({
    this.status = EmergencyStatus.idle,
    this.errorMessage,
    this.isPanicking = false,
  });

  EmergencyState copyWith({
    EmergencyStatus? status,
    String? errorMessage,
    bool? isPanicking,
    bool clearError = false,
  }) {
    return EmergencyState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isPanicking: isPanicking ?? this.isPanicking,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, isPanicking];
}
