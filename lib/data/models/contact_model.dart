import '../../domain/entities/contact.dart';

class ContactModel extends Contact {
  const ContactModel({
    required super.nome,
    required super.telefone,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      nome: json['nome'] as String,
      telefone: json['telefone'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'telefone': telefone,
    };
  }

  factory ContactModel.fromEntity(Contact contact) {
    return ContactModel(
      nome: contact.nome,
      telefone: contact.telefone,
    );
  }
}
