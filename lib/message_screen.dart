import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/scheduler.dart';
import 'auth_model.dart';
import 'database_helper.dart';
import 'message_widget.dart';
import 'network_helper.dart';
import 'settings_screen.dart';
import 'auth_screen.dart';
import 'account_screen.dart';
import 'dart:convert';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final _messagesController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final List<Map<String, dynamic>> _messages = [];
  static const platform = MethodChannel('com.example.xir_app/process_text');
  String _message = '';
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _player = AudioPlayer();
  WebSocketChannel? _channel;
  String _currentMessage = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadTokenAndConnect();
    });
  }

  Future<void> _loadTokenAndConnect() async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    await authModel.loadToken();
    print('Token loaded: ${authModel.token}');

    if (authModel.isAuthenticated) {
      await _loadMessagesFromServer();
      await _connectWebSocket();
    } else {
      _showSnackBar('Пожалуйста, авторизуйтесь.');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _player.dispose();
    _timer?.cancel();
    _recorder.closeRecorder();
    _channel?.sink.close();
    _messagesController.close();
    super.dispose();
  }

  Future<void> _loadMessagesFromServer() async {
    try {
      final loadedMessages = await NetworkHelper.loadMessages(context);
      for (var msg in loadedMessages) {
        _messages.add({
          'message': msg['text'],
          'isSentByUser': msg['is_user'] ? 1 : 0,
        });
      }
      _messagesController.add(_messages); // Добавляем данные в StreamController
    } catch (e) {
      print('Error loading messages: $e');
      _showSnackBar('Ошибка загрузки сообщений: $e');
    }
  }

  Future<void> _initializeRecorder() async {
    try {
      await _recorder.openRecorder();
    } catch (e) {
      print('Error initializing recorder: $e');
      _showSnackBar('Ошибка инициализации записи');
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    try {
      await _recorder.startRecorder(
        toFile: 'temp_audio.aac',
        codec: Codec.aacMP4,
      );

      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });

      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _recordDuration = Duration(seconds: _recordDuration.inSeconds + 1);
        });
      });
    } catch (e) {
      print('Ошибка при начале записи: $e');
      _showSnackBar('Не удалось начать запись');
    }
  }

  void _stopRecording({bool cancel = false}) async {
    if (!_isRecording) return;

    _timer?.cancel();

    try {
      final path = await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });

      if (!cancel && path != null) {
        String recognizedText = await _recognizeSpeech(path);
        _sendMessage(recognizedText, null);
        await File(path).delete(); // Удаляем временный файл
      }
    } catch (e) {
      print('Ошибка при остановке записи: $e');
      _showSnackBar('Не удалось остановить запись');
    }
  }

  Future<String> _recognizeSpeech(String filePath) async {
    // Здесь должна быть логика для распознавания речи
    // Например, использование библиотеки speech_to_text или другой
    // Верните распознанный текст
    return "распознанный текст"; // Замените на реальный распознанный текст
  }

  Future<void> _sendMessage(String message, String? filePath) async {
    if (message.trim().isEmpty) return;

    final newMessage = {'message': message, 'isSentByUser': 1};
    _messages.add(newMessage);
    _messagesController.add(_messages);

    _scrollToBottom();

    _channel?.sink.add(jsonEncode({'text': message}));
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

  void _onMessageTap(String message, String? filePath) async {
    if (filePath != null) {
      String recognizedText = await _recognizeSpeech(filePath);
      setState(() {
        _message = recognizedText;
        _textController.text = recognizedText;
      });
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      _channel?.sink.close(); // Закрываем предыдущее подключение, если оно существует
      _channel = await NetworkHelper.connectWebSocket(context);

      if (_channel != null) {
        print('WebSocket connected successfully');
        _channel!.stream.listen((message) {
          print('WebSocket message received: $message');
          setState(() {
            _currentMessage += message;
            if (message.endsWith('?')) {
              final newMessage = {'message': _currentMessage, 'isSentByUser': 0};
              _messages.add(newMessage);
              _messagesController.add(_messages);
              _scrollToBottom();
              _currentMessage = '';
            }
          });
        }, onError: (error) {
          print('WebSocket error: $error');
          _showSnackBar('Ошибка WebSocket: $error');
        }, onDone: () {
          print('WebSocket connection closed');
        });
      }
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      _showSnackBar('Ошибка подключения к WebSocket: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _messagesController.stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return ListView.builder(
                        controller: _scrollController,
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final message = snapshot.data![index];
                          final messageText = message['message'] ?? '';
                          final isSentByUser = message['isSentByUser'] == 1;
                          return GestureDetector(
                            onTap: () => _onMessageTap(messageText, message['filePath']),
                            child: MessageWidget(
                              message: messageText,
                              isSentByUser: isSentByUser,
                            ),
                          );
                        },
                      );
                    } else {
                      return Center(child: CircularProgressIndicator());
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () async {
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
                          _messages.clear();
                          _messagesController.add(_messages);
                          print('Messages cleared.');
                        }
                      },
                    ),
                    Expanded(
                      child: RawKeyboardListener(
                        focusNode: FocusNode(),
                        onKey: (event) {
                          if (event is RawKeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.enter && !event.isShiftPressed) {
                              if (_message.trim().isNotEmpty) {
                                _sendMessage(_message, null);
                                setState(() {
                                  _message = '';
                                });
                                _textController.clear();
                              }
                            }
                          }
                        },
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          onChanged: (value) {
                            setState(() {
                              _message = value;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Введите текст',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    _message.trim().isEmpty
                        ? Stack(
                            children: [
                              if (_isRecording)
                                Positioned(
                                  bottom: 60,
                                  right: 0,
                                  child: IconButton(
                                    icon: Icon(Icons.stop, color: Colors.red),
                                    onPressed: () => _stopRecording(),
                                  ),
                                ),
                              IconButton(
                                icon: Icon(_isRecording ? Icons.cancel : Icons.mic),
                                onPressed: () {
                                  if (_isRecording) {
                                    _stopRecording(cancel: true);
                                  } else {
                                    _startRecording();
                                  }
                                },
                              ),
                            ],
                          )
                        : IconButton(
                            icon: Icon(Icons.send),
                            onPressed: () {
                              _sendMessage(_message, null);
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
          if (_isRecording)
            Positioned(
              bottom: 140,
              left: 20,
              child: Text(
                "Запись: ${_recordDuration.inMinutes.toString().padLeft(2, '0')}:${_recordDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}",
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }
}
