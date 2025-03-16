import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:xir_app/bloc/auth/auth_bloc.dart';
import 'package:xir_app/bloc/auth/auth_event.dart';
import 'package:xir_app/bloc/message/message_bloc.dart';
import 'package:xir_app/models/theme_model.dart';
import 'package:xir_app/screens/auth_screen.dart';
import 'package:xir_app/screens/settings_screen.dart';
import 'package:xir_app/screens/account_screen.dart';
import 'package:xir_app/screens/message_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModel()..loadTheme()),
        BlocProvider(create: (_) => AuthBloc()..add(LoadToken())),
        BlocProvider(create: (_) => MessageBloc()),
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
