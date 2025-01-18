import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeModel = Provider.of<ThemeModel>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Настройки')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              title: Text('Темная тема'),
              trailing: Switch(
                value: themeModel.isDark,
                onChanged: (value) {
                  themeModel.toggleTheme();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
