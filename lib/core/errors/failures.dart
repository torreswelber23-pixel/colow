import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([String message = 'Erro no servidor']) : super(message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'Sem conexao']) : super(message);
}

class CacheFailure extends Failure {
  const CacheFailure([String message = 'Erro ao acessar dados locais']) : super(message);
}

class PermissionFailure extends Failure {
  const PermissionFailure([String message = 'Permissao negada']) : super(message);
}

class AuthFailure extends Failure {
  const AuthFailure([String message = 'Erro de autenticacao']) : super(message);
}

class ValidationFailure extends Failure {
  const ValidationFailure([String message = 'Dados invalidos']) : super(message);
}
