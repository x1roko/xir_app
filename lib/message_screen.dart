import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'network_helper.dart';
import 'auth_model.dart';
import 'message_widget.dart';
import 'settings_screen.dart';
import 'auth_screen.dart';
import 'account_screen.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  static const platform = MethodChannel('com.example.xir_app/process_text');
  String _message = '';
  final TextEditingController _textController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  final AudioRecorder _record = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  String? _audioFilePath;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _scrollController.addListener(_onScroll);
    _getTextFromPlatform();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _player.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _getTextFromPlatform() async {
    String receivedText;
    try {
      final String result = await platform.invokeMethod('processText');
      receivedText = result ?? 'No text received';
    } on PlatformException catch (e) {
      receivedText = "";
    }

    setState(() {
      _message = receivedText;
      _textController.text = receivedText;
    });
  }

  Future<void> _loadMessages() async {
    final loadedMessages = await DatabaseHelper.getMessages();
    setState(() {
      messages = List<Map<String, dynamic>>.from(loadedMessages);
      print('Loaded messages: $messages');
    });
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    final directory = await getApplicationDocumentsDirectory();
    final _audioFilePath = '${directory.path}/audio_message.m4a';

    try {
      if (await _record.hasPermission()) {
        await _record.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _audioFilePath,
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
      }
    } catch (e) {
      print('Ошибка при начале записи: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось начать запись')),
      );
    }
  }


  void _stopRecording({bool cancel = false}) async {
    if (!_isRecording) return;

    _timer?.cancel();

    try {
      final path = await _record.stop();
      setState(() {
        _isRecording = false;
      });

      if (!cancel && path != null) {
        String recognizedText = await _recognizeSpeech(path);
        _sendMessage(recognizedText, path);
      }
    } catch (e) {
      print('Ошибка при остановке записи: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось остановить запись')),
      );
    }
  }

  void _playAudio(String filePath) async {
    try {
      await _player.setFilePath(filePath);
      _player.play();
    } catch (e) {
      print('Ошибка воспроизведения аудио: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось воспроизвести аудио')),
      );
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
    await DatabaseHelper.saveMessage(message: message, isSentByUser: true);
    await DatabaseHelper.saveMessage(message: responseMessage, isSentByUser: false);
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
                          await DatabaseHelper.clearMessages();
                          setState(() {
                            messages.clear();
                            print('Messages cleared.');
                          });
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
                                  _textController.clear();
                                  setState(() {
                                    _message = '';
                                });
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
