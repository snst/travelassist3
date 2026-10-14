import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database.dart';
import 'screens/home_page.dart';
import 'screens/share_target.dart';
import 'utils/shared_content.dart';

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
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _darkModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _database.seedInitialCurrenciesIfEmpty();
    unawaited(_loadDarkModePreference());
    ShareChannel.listen(_onShare);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final content = await ShareChannel.initialShare();
      if (content != null) _onShare(content);
    });
  }

  void _onShare(SharedContent content) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    unawaited(handleSharedContent(context, _database, content));
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
      navigatorKey: _navigatorKey,
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
