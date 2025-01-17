import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart'; // Импортируем конфигурацию

class AuthModel extends ChangeNotifier {
  String _token = '';
  Database? _database;

  String get token => _token;

  bool get isAuthenticated => _token.isNotEmpty;

  Future<void> setToken(String token) async {
    _token = token;
    notifyListeners();
  }

  Future<void> clearToken() async {
    _token = '';
    notifyListeners();
    if (_database != null) {
      await _database!.delete('auth');
    }
  }

  Future<void> initDatabase() async {
    _database = await openDatabase(
      p.join(await getDatabasesPath(), 'auth_database.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE auth(id INTEGER PRIMARY KEY, token TEXT)',
        );
      },
      version: 1,
    );
  }

  Future<void> saveTokenToDatabase(String token) async {
    if (_database == null) {
      await initDatabase();
    }
    await _database!.insert(
      'auth',
      {'token': token},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> loadToken() async {
    if (_database == null) {
      await initDatabase();
    }
    final List<Map<String, dynamic>> maps = await _database!.query('auth');
    if (maps.isNotEmpty) {
      _token = maps.first['token'];
      notifyListeners();
      await refreshToken();  // Автоматически обновляем токен при загрузке
    }
  }

  Future<void> refreshToken() async {
    final response = await http.post(
      Uri.parse(refreshTokenUrl), // Используем URL из конфигурации
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode == 200) {
      final responseBody = response.body;
      if (responseBody.isNotEmpty) {
        final responseData = jsonDecode(responseBody);
        final newToken = responseData['token'];
        await setToken(newToken);
        await saveTokenToDatabase(newToken);
      }
    } else {
      clearToken();
    }
  }
}
