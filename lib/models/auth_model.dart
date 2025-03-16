import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart'; // Импорт конфигурации
import '../helpers/database_helper.dart'; // Импорт DatabaseHelper

class AuthModel extends ChangeNotifier {
  String _token = '';

  String get token => _token;

  bool get isAuthenticated => _token.isNotEmpty;

  Future<void> setToken(String token) async {
    _token = token;
    notifyListeners();
    await DatabaseHelper().saveToken(token);
  }

  Future<void> clearToken() async {
    _token = '';
    notifyListeners();
    await DatabaseHelper().clearToken();
  }

  Future<void> loadToken() async {
    _token = await DatabaseHelper().getToken() ?? '';
    notifyListeners();
    print('Token loaded from database: $_token');
    if (_token.isNotEmpty) {
      await refreshToken(); // Автоматически обновляем токен при загрузке
    }
  }

  Future<void> refreshToken() async {
    final response = await http.post(
      Uri.parse(Config.refreshTokenUrl), // Используем URL из конфигурации
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode == 200) {
      final responseBody = response.body;
      if (responseBody.isNotEmpty) {
        final responseData = jsonDecode(responseBody);
        final newToken = responseData['token'];
        await setToken(newToken);
      }
    } else {
      clearToken();
    }
  }
}
