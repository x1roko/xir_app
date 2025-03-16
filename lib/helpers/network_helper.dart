import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import 'database_helper.dart';

class NetworkHelper {
  static Future<void> sendMessage(String message) async {
    final channel = await connectWebSocket();

    channel.sink.add(jsonEncode({'text': message}));

    channel.stream.listen((data) {
      final responseMessage = data;
      // Сообщения больше не сохраняются в локальной базе данных
    }, onError: (error) {
      print('WebSocket error: $error');
    }, onDone: () {
      print('WebSocket connection closed');
    });

    channel.sink.close();
  }

  static Future<IOWebSocketChannel> connectWebSocket() async {
    final token = await DatabaseHelper().getToken();
    final channel = IOWebSocketChannel.connect(
      Uri.parse(Config.webSocketUrl),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    print('Connecting to WebSocket');

    return channel;
  }

  static Future<List<Map<String, dynamic>>> loadMessages() async {
    final token = await DatabaseHelper().getToken();
    print('Token: $token'); // Логирование токена
    final response = await http.get(
      Uri.parse('${Config.apiUrl}/messages'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept-Charset': 'utf-8', // Ensure the server sends the response in UTF-8
      },
    );
    print('Loading messages');
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
