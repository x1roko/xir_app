import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_model.dart';
import 'config.dart';

class NetworkHelper {
  static Future<void> sendMessage(BuildContext context, String message) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    if (!authModel.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, авторизуйтесь перед отправкой сообщения.')),
      );
      return;
    }

    print('Sending message with token: ${authModel.token}');

    final channel = await connectWebSocket(context);

    channel.sink.add(jsonEncode({'text': message}));

    channel.stream.listen((data) {
      final responseMessage = data;
      // Сообщения больше не сохраняются в локальной базе данных
    }, onError: (error) {
      print('WebSocket error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка WebSocket: $error')),
      );
    }, onDone: () {
      print('WebSocket connection closed');
    });

    channel.sink.close();
  }

  static Future<IOWebSocketChannel> connectWebSocket(BuildContext context) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    if (!authModel.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, авторизуйтесь перед отправкой сообщения.')),
      );
      throw Exception('User not authenticated');
    }

    final channel = IOWebSocketChannel.connect(
      Uri.parse(Config.webSocketUrl),
      headers: {
        'Authorization': 'Bearer ${authModel.token}',
      },
    );
    print('Connecting to WebSocket with token: ${authModel.token}');
    channel.stream.listen(
      (data) {
        print('WebSocket data received: $data');
      },
      onError: (error) {
        print('WebSocket error: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка WebSocket: $error')),
        );
      },
      onDone: () {
        print('WebSocket connection closed');
      },
    );

    return channel;
  }

  static Future<List<Map<String, dynamic>>> loadMessages(BuildContext context) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    if (!authModel.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, авторизуйтесь для загрузки сообщений.')),
      );
      throw Exception('User not authenticated');
    }

    final response = await http.get(
      Uri.parse('${Config.apiUrl}/messages'),
      headers: {
        'Authorization': 'Bearer ${authModel.token}',
        'Accept-Charset': 'utf-8', // Ensure the server sends the response in UTF-8
      },
    );
    print('Loading messages with token: ${authModel.token}');
    print('Response status: ${response.statusCode}');
    print('Response headers: ${response.headers}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      // Decode the response body using utf8
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Failed to load messages');
    }
  }
}
