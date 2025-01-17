import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import 'package:highlight/languages/dart.dart'; // Поддерживаемые языки
import 'package:flutter_highlight/themes/github.dart'; // Тема подсветки синтаксиса

class MessageWidget extends StatelessWidget {
  final String message;
  final bool isSentByUser;

  MessageWidget({required this.message, required this.isSentByUser});

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // Функция для парсинга текста и извлечения блоков кода
    List<Map<String, String?>> _parseMessage(String text) {
      final regex = RegExp(r'```(\w+)?\n([\s\S]*?)```');
      final matches = regex.allMatches(text);
      List<Map<String, String?>> parsedBlocks = [];

      for (var match in matches) {
        parsedBlocks.add({
          'language': match.group(1), // Язык программирования
          'code': match.group(2), // Блок кода
        });
      }

      // Остальной текст (не код) в сообщении
      String remainingText = text.replaceAll(regex, '').trim();
      parsedBlocks.add({
        'text': remainingText,
      });

      return parsedBlocks;
    }

    final parsedBlocks = _parseMessage(message);

    return Align(
      alignment: isSentByUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.all(15),
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSentByUser
              ? const Color.fromARGB(255, 65, 65, 65)
              : const Color.fromARGB(255, 41, 41, 41), // Сообщение серое
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              offset: Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Отображаем обычный текст
            for (var block in parsedBlocks)
              if (block['text'] != null && block['text']!.isNotEmpty)
                SelectableText(
                  block['text']!,
                  style: TextStyle(
                    color: Colors.white, // Текст сообщения
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            // Отображаем код
            for (var block in parsedBlocks)
              if (block['code'] != null && block['code']!.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(top: 12),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black, // Чёрный фон для кода
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (block['language'] != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              block['language']!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.copy, size: 20),
                              onPressed: () {
                                // Проверяем, если блок кода пустой или null, передаем пустую строку
                                String code = block['code'] ?? '';
                                Clipboard.setData(ClipboardData(text: code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Код скопирован в буфер обмена')),
                                );
                              },
                            ),
                          ],
                        ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black, // Чёрный фон для кода
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText.rich(
                          TextSpan(
                            children: highlight.parse(block['code']!,
                                    language: block['language'])
                                .nodes
                                ?.map((node) {
                                  return _convertNodeToTextSpan(node);
                                }).toList(),
                          ),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            color: Colors.white70, // Текст в коде — светло-белый
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // Конвертируем ноды подсветки в TextSpan
  TextSpan _convertNodeToTextSpan(Node node) {
    if (node.value != null) {
      return TextSpan(text: node.value);
    } else if (node.children != null) {
      return TextSpan(
        children: node.children!.map(_convertNodeToTextSpan).toList(),
        style: TextStyle(
          color: _getColorForType(node.className),
        ),
      );
    }
    return TextSpan();
  }

  // Получаем цвет для типа подсветки
  Color? _getColorForType(String? type) {
    switch (type) {
      case 'keyword':
        return Colors.blue;
      case 'string':
        return Colors.green;
      case 'number':
        return Colors.orange;
      case 'comment':
        return Colors.grey;
      case 'built_in':
      case 'type':
        return Colors.purple;
      default:
        return null;
    }
  }
}
