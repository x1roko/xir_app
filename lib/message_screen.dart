import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Добавлен импорт для работы с клавиатурой
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'auth_model.dart';
import 'database_helper.dart';
import 'network_helper.dart';
import 'message_widget.dart';
import 'settings_screen.dart';
import 'auth_screen.dart';
import 'account_screen.dart';

class MessageScreen extends StatefulWidget {
  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  String _message = '';
  TextEditingController _textController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final loadedMessages = await DatabaseHelper.getMessages();
    setState(() {
      messages = List<Map<String, dynamic>>.from(loadedMessages);
      print('Loaded messages: $messages');
    });
  }

  Future<void> _clearMessages() async {
    bool? confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Подтверждение'),
        content: Text('Вы уверены, что хотите удалить все сообщения?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      await DatabaseHelper.clearMessages();
      setState(() {
        messages.clear();
        print('Messages cleared.');
      });
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      messages.add({'message': message, 'isSentByUser': 1});
    });

    final chatHistory = await DatabaseHelper.getContextChat();
    _scrollToBottom();

    final http.Response? response = await NetworkHelper.sendMessage(context, message, chatHistory);

    if (response == null || response.statusCode != 200) {
      print('Ошибка при отправке сообщения: ${response?.statusCode}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при отправке сообщения: ${response?.statusCode}')),
      );
      return;
    }

    final responseMessage = response.body;
    await DatabaseHelper.saveMessage(message, true);
    await DatabaseHelper.saveMessage(responseMessage, false);
    setState(() {
      messages.add({'message': responseMessage, 'isSentByUser': 0});
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final atBottom = _scrollController.offset >=
        (_scrollController.position.maxScrollExtent - 50);
    setState(() {
      _showScrollToBottom = !atBottom;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Чат'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen()));
            },
          ),
          Consumer<AuthModel>(
            builder: (context, authModel, child) {
              return IconButton(
                icon: Icon(authModel.isAuthenticated ? Icons.account_circle : Icons.login),
                onPressed: () {
                  if (authModel.isAuthenticated) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountScreen()));
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AuthScreen()));
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
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
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: _clearMessages,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 5, // Ограничиваем количество строк до 5
                        keyboardType: TextInputType.multiline, // Многократный ввод
                        textInputAction: TextInputAction.done, // Переход на новую строку
                        onChanged: (value) {
                          setState(() {
                            _message = value;
                          });
                        },
                        onSubmitted: (value) {
                          _sendMessage(_message);
                        },
                        decoration: InputDecoration(
                          labelText: 'Введите текст',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.send), // Кнопка отправки
                      onPressed: () {
                        _sendMessage(_message);
                        _textController.clear();
                        setState(() {
                          _message = '';
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_showScrollToBottom)
            Positioned(
              bottom: 70,
              right: 20,
              child: FloatingActionButton(
                mini: true,
                onPressed: _scrollToBottom,
                child: Icon(Icons.arrow_downward),
              ),
            ),
        ],
      ),
    );
  }
}
