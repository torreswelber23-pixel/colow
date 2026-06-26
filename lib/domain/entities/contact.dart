import 'package:equatable/equatable.dart';

class Contact extends Equatable {
  final String nome;
  final String telefone;

  const Contact({
    required this.nome,
    required this.telefone,
  });

  Contact copyWith({
    String? nome,
    String? telefone,
  }) {
    return Contact(
      nome: nome ?? this.nome,
      telefone: telefone ?? this.telefone,
    );
  }

  @override
  List<Object?> get props => [nome, telefone];
}
