import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static Database? _database;

  static Future<Database?> get database async {
    if (_database != null) return _database;
    _database = await _initDatabase();
    return _database;
  }

  static Future<Database> _initDatabase() async {
    String dbPath = p.join(await getDatabasesPath(), 'my_database.db');
    print('Database path: $dbPath');

    if (await databaseExists(dbPath)) {
      print('Database already exists.');
    } else {
      print('Creating new database.');
      return await openDatabase(
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
    }

    return await openDatabase(dbPath);
  }

  static Future<List<Map<String, dynamic>>> getMessages() async {
    final db = await database;
    if (db == null) {
      print('Database is not initialized.');
      return [];
    }
    print('Loading messages from database.');
    return await db.query('messages');
  }

  static Future<void> clearMessages() async {
    final db = await database;
    if (db == null) {
      print('Database is not initialized.');
      return;
    }
    print('Clearing messages from database.');
    await db.delete('messages');
  }

  static Future<void> saveMessage(String message, bool isSentByUser) async {
    final db = await database;
    if (db == null) {
      print('Database is not initialized.');
      return;
    }
    print('Saving message: $message, sent by user: $isSentByUser');
    await db.insert(
      'messages',
      {'message': message, 'token': '', 'isSentByUser': isSentByUser ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<String>> getContextChat() async {
    final db = await database;
    if (db == null) {
      print('Database is not initialized.');
      return [];
    }
    print('Fetching chat history from database.');

    // Получаем все сообщения из таблицы
    final List<Map<String, dynamic>> messages = await db.query(
      'messages',
      orderBy: 'id DESC',
      limit: 10
      );

    // Извлекаем только текст сообщений
    return messages.map((msg) => msg['message'] as String).toList();
  }

  static Future<List<String>> getChatHistory() async {
    final db = await database;
    if (db == null) {
      print('Database is not initialized.');
      return [];
    }
    print('Fetching chat history from database.');

    // Получаем все сообщения из таблицы
    final List<Map<String, dynamic>> messages = await db.query('messages');

    // Извлекаем только текст сообщений
    return messages.map((msg) => msg['message'] as String).toList();
  }
}
