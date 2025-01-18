import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart'; 
import 'dart:convert';
import 'auth_model.dart';
import 'config.dart';
import 'database_helper.dart';

class NetworkHelper {
  
  static Future<http.Response?> sendMessage(BuildContext context, String message, List<String> chatHistory) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    if (!authModel.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, авторизуйтесь перед отправкой сообщения.')),
      );
      return null;
    }

    print('Sending message with token: ${authModel.token}');

    final messageToSend = "Контекст:${chatHistory.toString()}\nЗапрос: $message";

    final response = await http.post(
      Uri.parse(groqUrl), // Используем URL из конфигурации
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${authModel.token}',
      },
      body: jsonEncode({'text': messageToSend}),
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 401) {
      // Токен недействителен, обновляем токен и пробуем снова
      await authModel.refreshToken();
      return sendMessage(context, message, chatHistory);  // Повторный вызов функции после обновления токена
    }

    return response;
  }
}
