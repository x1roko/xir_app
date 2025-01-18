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

    return await openDatabase(
      dbPath,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          print('Adding audioPath column to messages table.');
          await db.execute('ALTER TABLE messages ADD COLUMN audioPath TEXT');
        }
      },
      onCreate: (db, version) async {
        print('Creating new database with messages table.');
        await db.execute(
          '''
          CREATE TABLE messages(
            id INTEGER PRIMARY KEY, 
            message TEXT, 
            token TEXT, 
            isSentByUser INTEGER,
            audioPath TEXT
          )
          '''
        );
      },
    );
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

  static Future<void> saveMessage({
    required String? message,
    required bool isSentByUser,
    String? audioPath,
  }) async {
    final db = await database;
    if (db == null) {
      print('Database is not initialized.');
      return;
    }
    print('Saving message: $message, audioPath: $audioPath, sent by user: $isSentByUser');
    await db.insert(
      'messages',
      {
        'message': message,
        'token': '',
        'isSentByUser': isSentByUser ? 1 : 0,
        'audioPath': audioPath,
      },
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

    final List<Map<String, dynamic>> messages = await db.query(
      'messages',
      orderBy: 'id DESC',
      limit: 10,
    );

    return messages.map((msg) => msg['message'] as String? ?? '').toList();
  }

  static Future<List<Map<String, dynamic>>> getChatHistory() async {
    final db = await database;
    if (db == null) {
      print('Database is not initialized.');
      return [];
    }
    print('Fetching chat history from database.');

    return await db.query('messages');
  }
}
