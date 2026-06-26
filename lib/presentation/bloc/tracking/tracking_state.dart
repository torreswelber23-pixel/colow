part of 'tracking_cubit.dart';

enum TrackingStatus { initial, active, finished, error }
enum AudioListenStatus { idle, connecting, playing, error }

class TrackingState extends Equatable {
  final TrackingStatus status;
  final Profile alvo;
  final AppLocation? lastLocation;
  final DateTime? lastUpdate;
  final bool isAlvoEmRota;
  final String? errorMessage;
  final AudioListenStatus audioStatus;
  final String? audioError;

  const TrackingState({
    this.status = TrackingStatus.initial,
    required this.alvo,
    this.lastLocation,
    this.lastUpdate,
    this.isAlvoEmRota = false,
    this.errorMessage,
    this.audioStatus = AudioListenStatus.idle,
    this.audioError,
  });

  TrackingState copyWith({
    TrackingStatus? status,
    Profile? alvo,
    AppLocation? lastLocation,
    DateTime? lastUpdate,
    bool? isAlvoEmRota,
    String? errorMessage,
    AudioListenStatus? audioStatus,
    String? audioError,
    bool clearAudioError = false,
  }) {
    return TrackingState(
      status: status ?? this.status,
      alvo: alvo ?? this.alvo,
      lastLocation: lastLocation ?? this.lastLocation,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      isAlvoEmRota: isAlvoEmRota ?? this.isAlvoEmRota,
      errorMessage: errorMessage ?? this.errorMessage,
      audioStatus: audioStatus ?? this.audioStatus,
      audioError: clearAudioError ? null : (audioError ?? this.audioError),
    );
  }

  @override
  List<Object?> get props => [
        status,
        alvo,
        lastLocation,
        lastUpdate,
        isAlvoEmRota,
        errorMessage,
        audioStatus,
        audioError,
      ];
}
