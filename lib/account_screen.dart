import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_model.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authModel = Provider.of<AuthModel>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Аккаунт')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Вы авторизованы как: ${authModel.token}'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                authModel.clearToken();
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
