import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database.dart';
import 'screens/home_page.dart';

const _darkModePreferenceKey = 'darkModeEnabled';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppDatabase _database;
  bool _darkModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _database.seedInitialCurrenciesIfEmpty();
    _database.seedInitialTodoItemsIfEmpty();
    _database.seedInitialNotesIfEmpty();
    unawaited(_loadDarkModePreference());
  }

  Future<void> _loadDarkModePreference() async {
    final preferences = await SharedPreferences.getInstance();
    final darkModeEnabled = preferences.getBool(_darkModePreferenceKey) ?? false;
    if (mounted) {
      setState(() => _darkModeEnabled = darkModeEnabled);
    }
  }

  Future<void> _setDarkModeEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(_darkModePreferenceKey, enabled);
    if (!saved) {
      throw StateError('Failed to save the dark mode preference.');
    }
    if (mounted) {
      setState(() => _darkModeEnabled = enabled);
    }
  }

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Assist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(
        title: 'Travel Assist',
        database: _database,
        darkModeEnabled: _darkModeEnabled,
        onDarkModeChanged: _setDarkModeEnabled,
      ),
    );
  }
}
