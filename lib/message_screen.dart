import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for keyboard handling
import 'package:flutter_sound/flutter_sound.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'auth_model.dart';
import 'database_helper.dart';
import 'network_helper.dart';
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
  String _message = '';
  final TextEditingController _textController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  bool _isRecording = false;
  late stt.SpeechToText _speech;
  late FlutterSoundPlayer _audioPlayer;
  String? _audioFilePath;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _audioPlayer = FlutterSoundPlayer();
    _loadMessages();
    _scrollController.addListener(_onScroll);
    _initializeSpeech();
    _initializeAudioPlayer();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _audioPlayer.closePlayer();  // Optional cleanup (but not necessary in latest version)
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize();
    if (!available) {
      print("Speech recognition not available");
    }
  }

  Future<void> _initializeAudioPlayer() async {
    await _audioPlayer.openPlayer();  // Ensure this is called to open the session (even though it's automatic in the background).
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

  Future<void> _startListening() async {
    if (_isRecording) return;
    setState(() => _isRecording = true);
    await _speech.listen(onResult: (result) {
      setState(() {
        _message = result.recognizedWords;
      });
    });
  }

  Future<void> _stopListening() async {
    if (!_isRecording) return;
    await _speech.stop();
    setState(() => _isRecording = false);
    if (_message.isNotEmpty) {
      _sendMessage(_message);
      _textController.clear();
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

  Future<void> _playAudio(String filePath) async {
    if (filePath.isNotEmpty) {
      await _audioPlayer.startPlayer(
        fromURI: filePath,
        whenFinished: () {
          print("Audio playback finished");
        },
      );
    }
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
                      onPlayAudio: message['audioPath'] != null
                          ? () => _playAudio(message['audioPath'])
                          : null,
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
                      child: RawKeyboardListener(
                        focusNode: FocusNode(),
                        onKey: (event) {
                          if (event.logicalKey == LogicalKeyboardKey.enter && event.isShiftPressed) {
                            _textController.text += '\n';
                            _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
                          }
                          if (event.logicalKey == LogicalKeyboardKey.enter && !event.isShiftPressed) {
                            _sendMessage(_message);
                            _textController.clear();
                            setState(() {
                              _message = '';
                            });
                          }
                        },
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.done,
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
                        ? IconButton(
                            icon: Icon(Icons.mic),
                            onPressed: _startListening,
                          )
                        : IconButton(
                            icon: Icon(Icons.send),
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
