import 'package:equatable/equatable.dart';

class Profile extends Equatable {
  final String id;
  final String? userId;
  final String deviceId;
  final String nome;
  final String codigo;
  final String? pushToken;

  const Profile({
    required this.id,
    this.userId,
    required this.deviceId,
    required this.nome,
    required this.codigo,
    this.pushToken,
  });

  Profile copyWith({
    String? id,
    String? userId,
    String? deviceId,
    String? nome,
    String? codigo,
    String? pushToken,
  }) {
    return Profile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      nome: nome ?? this.nome,
      codigo: codigo ?? this.codigo,
      pushToken: pushToken ?? this.pushToken,
    );
  }

  @override
  List<Object?> get props => [id, userId, deviceId, nome, codigo, pushToken];
}
