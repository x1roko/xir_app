import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import 'auth_model.dart';
import 'theme_model.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';
import 'account_screen.dart';
import 'message_screen.dart'; // Импортируем MessageScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация для sqflite_common_ffi
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthModel()..loadToken()),
        ChangeNotifierProvider(create: (_) => ThemeModel()..loadTheme()),
      ],
      child: Consumer<ThemeModel>(
        builder: (context, themeModel, child) {
          return MaterialApp(
            theme: themeModel.isDark ? ThemeData.dark() : ThemeData.light(),
            home: MessageScreen(),
          );
        },
      ),
    );
  }
}
