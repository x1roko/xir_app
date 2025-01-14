import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'auth_model.dart';
import 'message_widget.dart';
import 'settings_screen.dart';
import 'auth_screen.dart';
import 'account_screen.dart';
import 'config.dart'; // Импортируем конфигурацию

class MessageScreen extends StatefulWidget {
  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  String _message = '';
  TextEditingController _textController = TextEditingController();
  Database? database;
  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initDatabase() async {
    String dbPath = p.join(await getDatabasesPath(), 'my_database.db');
    print('Database path: $dbPath');

    if (await databaseExists(dbPath)) {
      print('Database already exists. Deleting the existing database.');
      await deleteDatabase(dbPath);
    }

    database = await openDatabase(
      dbPath,
      onCreate: (db, version) {
        print('Creating new database with messages table.');
        return db.execute(
          '''
          CREATE TABLE messages(
            id INTEGER PRIMARY KEY, 
            message TEXT, 
            token TEXT, 
            isSentByUser INTEGER
          )
          '''
        );
      },
      version: 1,
    );
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    if (database == null) {
      print('Database is not initialized.');
      return;
    }
    print('Loading messages from database.');
    final List<Map<String, dynamic>> loadedMessages = await database!.query('messages');
    setState(() {
      messages = List<Map<String, dynamic>>.from(loadedMessages);
      print('Loaded messages: $messages');
    });
  }

  Future<void> _clearMessages() async {
    if (database == null) {
      print('Database is not initialized.');
      return;
    }
    print('Clearing messages from database.');
    await database!.delete('messages');
    setState(() {
      messages.clear();
      print('Messages cleared.');
    });
  }

  Future<void> _saveMessage(String message, bool isSentByUser) async {
    if (database == null) {
      print('Database is not initialized.');
      return;
    }
    print('Saving message: $message, sent by user: $isSentByUser');
    await database!.insert(
      'messages',
      {'message': message, 'token': '', 'isSentByUser': isSentByUser ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _sendMessage(String message) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    if (!authModel.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, авторизуйтесь перед отправкой сообщения.')),
      );
      return;
    }

    if (database == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('База данных не инициализирована.')),
      );
      return;
    }

    print('Sending message with token: ${authModel.token}');

    final response = await http.post(
      Uri.parse(groqUrl), // Используем URL из конфигурации
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${authModel.token}',
      },
      body: jsonEncode({'text': message}),
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 401) {
      // Токен недействителен, обновляем токен и пробуем снова
      await authModel.refreshToken();
      return _sendMessage(message);  // Повторный вызов функции после обновления токена
    }

    if (response.statusCode == 200) {
      final responseMessage = response.body;
      await _saveMessage(message, true);
      await _saveMessage(responseMessage, false);
      setState(() {
        messages = List<Map<String, dynamic>>.from(messages);  // Создаем новый список сообщений
        messages.add({'message': message, 'isSentByUser': 1});
        messages.add({'message': responseMessage, 'isSentByUser': 0});
        _message = '';
        _textController.clear();
        print('Message sent and saved: $message');
      });
    } else {
      print('Ошибка при отправке сообщения: ${response.statusCode}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при отправке сообщения: ${response.statusCode}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Сообщение'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen()));
            },
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              _clearMessages();
            },
          ),
          Consumer<AuthModel>(
            builder: (ctx, authModel, child) {
              return IconButton(
                icon: Icon(authModel.isAuthenticated ? Icons.account_circle : Icons.login),
                onPressed: () {
                  if (authModel.isAuthenticated) {
                    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => AccountScreen()));
                  } else {
                    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => AuthScreen()));
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return MessageWidget(
                  message: message['message'],
                  isSentByUser: message['isSentByUser'] == 1,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onChanged: (value) {
                      setState(() {
                        _message = value;
                        _textController.value = TextEditingValue(
                          text: value,
                          selection: TextSelection.fromPosition(
                            TextPosition(offset: value.length),
                          ),
                        );
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Введите текст',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _sendMessage(_message);
                  },
                  child: Text('Отправить'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
