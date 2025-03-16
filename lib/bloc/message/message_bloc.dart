import 'package:bloc/bloc.dart';
import 'package:xir_app/helpers/network_helper.dart';
import 'message_event.dart';
import 'message_state.dart';

class MessageBloc extends Bloc<MessageEvent, MessageState> {
  MessageBloc() : super(MessageInitial()) {
    on<LoadMessages>((event, emit) async {
      emit(MessageLoadInProgress());
      try {
        final messages = await NetworkHelper.loadMessages();
        print('Loaded messages: $messages'); // Логирование загруженных сообщений
        emit(MessageLoadSuccess(messages));
      } catch (_) {
        emit(MessageLoadFailure());
      }
    });

    on<SendMessage>((event, emit) async {
      try {
        await NetworkHelper.sendMessage(event.message);
        emit(MessageSendSuccess(event.message));
      } catch (_) {
        emit(MessageSendFailure());
      }
    });

    on<DeleteMessages>((event, emit) {
      emit(MessageDeleteSuccess());
    });
  }
}
