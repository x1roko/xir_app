import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class LoadToken extends AuthEvent {}

class SetToken extends AuthEvent {
  final String token;

  const SetToken(this.token);

  @override
  List<Object> get props => [token];
}

class ClearToken extends AuthEvent {}
