import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:xir_app/bloc/auth/auth_bloc.dart';
import 'package:xir_app/bloc/auth/auth_event.dart';
import 'package:xir_app/bloc/auth/auth_state.dart';
import '../models/auth_model.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authBloc = BlocProvider.of<AuthBloc>(context);
    final authState = authBloc.state;

    return Scaffold(
      appBar: AppBar(title: Text('Аккаунт')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (authState is AuthAuthenticated)
              Text('Вы авторизованы как: ${authState.token}'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                authBloc.add(ClearToken());
                Navigator.of(context).pop();
              },
              child: Text('Выйти'),
            ),
          ],
        ),
      ),
    );
  }
}
