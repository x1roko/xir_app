import 'package:bloc/bloc.dart';
import 'package:xir_app/helpers/database_helper.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<LoadToken>((event, emit) async {
      final token = await DatabaseHelper().getToken();
      print('Loaded token: $token'); // Логирование загруженного токена
      if (token != null) {
        emit(AuthAuthenticated(token));
      } else {
        emit(AuthUnauthenticated());
      }
    });

    on<SetToken>((event, emit) async {
      await DatabaseHelper().saveToken(event.token);
      emit(AuthAuthenticated(event.token));
    });

    on<ClearToken>((event, emit) async {
      await DatabaseHelper().clearToken();
      emit(AuthUnauthenticated());
    });
  }
}