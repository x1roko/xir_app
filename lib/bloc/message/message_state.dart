import 'package:equatable/equatable.dart';

abstract class MessageState extends Equatable {
  const MessageState();

  @override
  List<Object> get props => [];
}

class MessageInitial extends MessageState {}

class MessageLoadInProgress extends MessageState {}

class MessageLoadSuccess extends MessageState {
  final List<Map<String, dynamic>> messages;

  const MessageLoadSuccess(this.messages);

  @override
  List<Object> get props => [messages];
}

class MessageLoadFailure extends MessageState {}

class MessageSendSuccess extends MessageState {
  final String message;

  const MessageSendSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class MessageSendFailure extends MessageState {}

class MessageDeleteSuccess extends MessageState {}

class MessageDeleteFailure extends MessageState {}
