part of 'route_cubit.dart';

enum RouteStatus { initial, loading, active, finished }

/// Estado da conexão de áudio ao vivo (LiveKit).
enum AudioStatus {
  /// Desconectado — botão disponível para iniciar.
  idle,

  /// Conectando ao servidor LiveKit (aguardando token + handshake).
  connecting,

  /// Conectado e transmitindo áudio ao vivo.
  live,

  /// Falha na conexão ou transmissão.
  error,
}

class RouteState extends Equatable {
  final RouteStatus status;
  final Profile? profile;
  final List<Contact> contacts;
  final AppLocation? location;
  final bool isSendingSos;
  final bool sosSent;
  final AudioStatus audioStatus;
  final String? audioError;
  final bool promptCall190;
  final String? errorMessage;

  const RouteState({
    this.status = RouteStatus.initial,
    this.profile,
    this.contacts = const [],
    this.location,
    this.isSendingSos = false,
    this.sosSent = false,
    this.audioStatus = AudioStatus.idle,
    this.audioError,
    this.promptCall190 = false,
    this.errorMessage,
  });

  /// Atalho semântico: família está ouvindo ao vivo.
  bool get isFamilyListening => audioStatus == AudioStatus.live;

  RouteState copyWith({
    RouteStatus? status,
    Profile? profile,
    List<Contact>? contacts,
    AppLocation? location,
    bool? isSendingSos,
    bool? sosSent,
    AudioStatus? audioStatus,
    String? audioError,
    bool? promptCall190,
    String? errorMessage,
    bool clearAudioError = false,
    bool clearErrorMessage = false,
  }) {
    return RouteState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      contacts: contacts ?? this.contacts,
      location: location ?? this.location,
      isSendingSos: isSendingSos ?? this.isSendingSos,
      sosSent: sosSent ?? this.sosSent,
      audioStatus: audioStatus ?? this.audioStatus,
      audioError: clearAudioError ? null : (audioError ?? this.audioError),
      promptCall190: promptCall190 ?? this.promptCall190,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        profile,
        contacts,
        location,
        isSendingSos,
        sosSent,
        audioStatus,
        audioError,
        promptCall190,
        errorMessage,
      ];
}
