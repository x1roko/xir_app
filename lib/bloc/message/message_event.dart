import 'package:equatable/equatable.dart';

abstract class MessageEvent extends Equatable {
  const MessageEvent();

  @override
  List<Object> get props => [];
}

class LoadMessages extends MessageEvent {}

class SendMessage extends MessageEvent {
  final String message;

  const SendMessage(this.message);

  @override
  List<Object> get props => [message];
}

class DeleteMessages extends MessageEvent {}
