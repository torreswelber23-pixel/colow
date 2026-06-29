import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/app_location.dart';
import '../../domain/entities/contact.dart';
import '../../domain/repositories/alert_repository.dart';
import '../datasources/supabase_datasource.dart';

class AlertRepositoryImpl implements AlertRepository {
  final SupabaseDatasource _remote;

  AlertRepositoryImpl(this._remote);

  @override
  Future<Result<Map<String, dynamic>>> sendSos({
    required AppLocation location,
    required String nome,
    required String message,
    required List<Contact> contacts,
    String? protegidoId,
  }) async {
    try {
      final data = await _remote.sendAlert(
        lat: location.lat,
        lng: location.lng,
        nome: nome,
        mensagem: message,
        protegidoId: protegidoId,
      );
      // Alerta em tempo real para a familia (independe do FCM).
      if (protegidoId != null) {
        await _remote.insertFamilyAlerts(
          protegidoId: protegidoId,
          nome: nome,
          lat: location.lat,
          lng: location.lng,
          tipo: 'sos',
        );
      }
      return Success(data);
    } catch (e) {
      return Error(ServerFailure('Erro ao enviar SOS: $e'));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> notifyRouteStarted({
    required String protegidoId,
    required String nome,
    required AppLocation? location,
  }) async {
    try {
      final data = await _remote.sendAlert(
        lat: location?.lat ?? 0,
        lng: location?.lng ?? 0,
        nome: nome,
        mensagem: 'Iniciou uma rota protegida',
        protegidoId: protegidoId,
        tipo: 'rota',
      );
      return Success(data);
    } catch (e) {
      return Error(ServerFailure('Erro ao notificar rota: $e'));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> notifyListeningStarted({
    required String protegidoId,
    required String nome,
    required AppLocation? location,
  }) async {
    try {
      final data = await _remote.sendAlert(
        lat: location?.lat ?? 0,
        lng: location?.lng ?? 0,
        nome: nome,
        mensagem: 'Ativou a escuta ao vivo',
        protegidoId: protegidoId,
        tipo: 'escuta',
      );
      await _remote.insertFamilyAlerts(
        protegidoId: protegidoId,
        nome: nome,
        lat: location?.lat ?? 0,
        lng: location?.lng ?? 0,
        tipo: 'escuta',
      );
      return Success(data);
    } catch (e) {
      return Error(ServerFailure('Erro ao notificar escuta: $e'));
    }
  }

  @override
  Future<Result<String>> getLiveKitToken({
    required String roomName,
    required String participantName,
  }) async {
    try {
      final token = await _remote.getLiveKitToken(
        roomName: roomName,
        participantName: participantName,
      );
      return Success(token);
    } catch (e) {
      return Error(ServerFailure('Erro ao obter token LiveKit: $e'));
    }
  }
}
