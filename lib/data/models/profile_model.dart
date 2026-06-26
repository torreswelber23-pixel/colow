import '../../domain/entities/profile.dart';

class ProfileModel extends Profile {
  const ProfileModel({
    required super.id,
    super.userId,
    required super.deviceId,
    required super.nome,
    required super.codigo,
    super.pushToken,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      deviceId: json['device_id'] as String,
      nome: json['nome'] as String,
      codigo: json['codigo'] as String,
      pushToken: json['push_token'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'device_id': deviceId,
      'nome': nome,
      'codigo': codigo,
      'push_token': pushToken,
    };
  }

  factory ProfileModel.fromEntity(Profile profile) {
    return ProfileModel(
      id: profile.id,
      userId: profile.userId,
      deviceId: profile.deviceId,
      nome: profile.nome,
      codigo: profile.codigo,
      pushToken: profile.pushToken,
    );
  }
}
