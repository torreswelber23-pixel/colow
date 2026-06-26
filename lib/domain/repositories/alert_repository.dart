import '../../core/utils/result.dart';
import '../entities/app_location.dart';
import '../entities/contact.dart';

abstract class AlertRepository {
  Future<Result<Map<String, dynamic>>> sendSos({
    required AppLocation location,
    required String nome,
    required String message,
    required List<Contact> contacts,
    String? protegidoId,
  });

  Future<Result<Map<String, dynamic>>> notifyRouteStarted({
    required String protegidoId,
    required String nome,
    required AppLocation? location,
  });

  Future<Result<Map<String, dynamic>>> notifyListeningStarted({
    required String protegidoId,
    required String nome,
    required AppLocation? location,
  });

  /// Solicita um token JWT do LiveKit para entrar em uma sala de áudio.
  Future<Result<String>> getLiveKitToken({
    required String roomName,
    required String participantName,
  });
}
