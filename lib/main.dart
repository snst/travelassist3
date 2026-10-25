import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database/database.dart';
import 'screens/home_page.dart';
import 'screens/share_target.dart';
import 'utils/shared_content.dart';

const _darkModePreferenceKey = 'darkModeEnabled';
const _databaseProfilesPreferenceKey = 'databaseProfiles';
const _activeDatabasePreferenceKey = 'activeDatabaseId';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  final AppDatabase Function(String name)? databaseFactory;
  final Future<void> Function(String id)? databaseDeleter;

  const MyApp({super.key, this.databaseFactory, this.databaseDeleter});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppDatabase? _database;
  List<DatabaseProfile> _databaseProfiles = const [];
  String? _activeDatabaseId;
  Object? _initializationError;
  final _navigatorKey = GlobalKey<NavigatorState>();
  final List<SharedContent> _pendingShares = [];
  bool _darkModeEnabled = false;

  AppDatabase _openDatabase(String name) {
    return widget.databaseFactory?.call(name) ?? AppDatabase(name: name);
  }

  @override
  void initState() {
    super.initState();
    // Multiple independent database instances are intentional when switching.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    unawaited(_initializeDatabase());
    unawaited(_loadDarkModePreference());
    ShareChannel.listen(_onShare);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final content = await ShareChannel.initialShare();
      if (content != null) _onShare(content);
    });
  }

  void _onShare(SharedContent content) {
    final database = _database;
    if (database == null) {
      _pendingShares.add(content);
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    unawaited(handleSharedContent(context, database, content));
  }

  Future<void> _initializeDatabase() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedProfiles = preferences.getString(
        _databaseProfilesPreferenceKey,
      );
      final profiles = savedProfiles == null
          ? const [
              DatabaseProfile(id: defaultDatabaseName, name: 'Travel Assist'),
            ]
          : _decodeDatabaseProfiles(savedProfiles);
      if (profiles.isEmpty) {
        throw const FormatException('At least one database must be available.');
      }

      final savedActiveId = preferences.getString(_activeDatabasePreferenceKey);
      final matchingProfiles = profiles.where(
        (profile) => profile.id == savedActiveId,
      );
      final activeProfile = matchingProfiles.isEmpty
          ? profiles.first
          : matchingProfiles.first;

      if (savedProfiles == null) {
        final saved = await preferences.setString(
          _databaseProfilesPreferenceKey,
          _encodeDatabaseProfiles(profiles),
        );
        if (!saved) {
          throw StateError('Failed to save the database list.');
        }
      }
      if (savedActiveId != activeProfile.id) {
        final saved = await preferences.setString(
          _activeDatabasePreferenceKey,
          activeProfile.id,
        );
        if (!saved) {
          throw StateError('Failed to save the active database.');
        }
      }
      final database = _openDatabase(activeProfile.id);
      if (!mounted) {
        await database.close();
        return;
      }
      setState(() {
        _databaseProfiles = profiles;
        _activeDatabaseId = activeProfile.id;
        _database = database;
      });
      for (final content in _pendingShares) {
        _onShare(content);
      }
      _pendingShares.clear();
      try {
        await database.seedInitialCurrenciesIfEmpty();
      } catch (error) {
        final context = _navigatorKey.currentContext;
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not initialize the database: $error'),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _initializationError = error);
      }
    }
  }

  List<DatabaseProfile> _decodeDatabaseProfiles(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('The saved database list is invalid.');
    }
    return decoded.map((entry) {
      if (entry is! Map || entry['id'] is! String || entry['name'] is! String) {
        throw const FormatException('A saved database entry is invalid.');
      }
      final id = entry['id'] as String;
      final name = entry['name'] as String;
      if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id) || name.trim().isEmpty) {
        throw const FormatException('A saved database entry is invalid.');
      }
      return DatabaseProfile(id: id, name: name);
    }).toList();
  }

  String _encodeDatabaseProfiles(List<DatabaseProfile> profiles) {
    return jsonEncode([
      for (final profile in profiles) {'id': profile.id, 'name': profile.name},
    ]);
  }

  Future<void> _selectDatabase(String id) async {
    if (id == _activeDatabaseId) return;
    final profile = _databaseProfiles.firstWhere((profile) => profile.id == id);
    final database = _openDatabase(profile.id);
    try {
      await database.seedInitialCurrenciesIfEmpty();
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _activeDatabasePreferenceKey,
        profile.id,
      );
      if (!saved) {
        throw StateError('Failed to save the active database.');
      }
      if (!mounted) {
        await database.close();
        return;
      }
      final previousDatabase = _database;
      setState(() {
        _activeDatabaseId = profile.id;
        _database = database;
      });
      await previousDatabase?.close();
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  String _databaseIdForName(String name) {
    final trimmedName = name.trim();
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9 _-]{0,39}$').hasMatch(trimmedName)) {
      throw const FormatException(
        'Use 1-40 letters, numbers, spaces, or hyphens for the database name.',
      );
    }
    return trimmedName.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  }

  Future<void> _createDatabase(String name) async {
    final id = _databaseIdForName(name);
    if (_databaseProfiles.any((profile) => profile.id == id)) {
      throw const FormatException('A database with that name already exists.');
    }
    final profile = DatabaseProfile(id: id, name: name.trim());
    final profiles = [..._databaseProfiles, profile];
    final database = _openDatabase(id);
    try {
      await database.seedInitialCurrenciesIfEmpty();
      final preferences = await SharedPreferences.getInstance();
      final profilesSaved = await preferences.setString(
        _databaseProfilesPreferenceKey,
        _encodeDatabaseProfiles(profiles),
      );
      if (!profilesSaved) {
        throw StateError('Failed to save the database list.');
      }
      final activeSaved = await preferences.setString(
        _activeDatabasePreferenceKey,
        profile.id,
      );
      if (!activeSaved) {
        throw StateError('Failed to save the active database.');
      }
      if (!mounted) {
        await database.close();
        return;
      }
      final previousDatabase = _database;
      setState(() {
        _databaseProfiles = profiles;
        _activeDatabaseId = profile.id;
        _database = database;
      });
      await previousDatabase?.close();
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  Future<void> _deleteDatabase(String id) async {
    if (_databaseProfiles.length <= 1) {
      throw StateError('The last database cannot be deleted.');
    }
    if (!_databaseProfiles.any((profile) => profile.id == id)) {
      throw StateError('The selected database is not available.');
    }

    final profiles = _databaseProfiles
        .where((profile) => profile.id != id)
        .toList();
    if (_activeDatabaseId == id) {
      await _selectDatabase(profiles.first.id);
    }

    final deleter = widget.databaseDeleter;
    if (deleter == null) {
      await AppDatabase.deleteDatabaseFile(id);
    } else {
      await deleter(id);
    }

    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _databaseProfilesPreferenceKey,
      _encodeDatabaseProfiles(profiles),
    );
    if (!saved) {
      throw StateError('Failed to save the database list.');
    }
    if (mounted) {
      setState(() => _databaseProfiles = profiles);
    }
  }

  Future<void> _loadDarkModePreference() async {
    final preferences = await SharedPreferences.getInstance();
    final darkModeEnabled =
        preferences.getBool(_darkModePreferenceKey) ?? false;
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
    _database?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Reise',
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
      home: _database == null
          ? Scaffold(
              body: Center(
                child: _initializationError == null
                    ? const CircularProgressIndicator(value: 0.5)
                    : Text(
                        'Could not open the database: $_initializationError',
                      ),
              ),
            )
          : HomePage(
              title: _databaseProfiles
                  .firstWhere((profile) => profile.id == _activeDatabaseId)
                  .name,
              database: _database!,
              databaseProfiles: _databaseProfiles,
              activeDatabaseId: _activeDatabaseId!,
              onDatabaseSelected: _selectDatabase,
              onDatabaseCreated: _createDatabase,
              onDatabaseDeleted: _deleteDatabase,
              darkModeEnabled: _darkModeEnabled,
              onDarkModeChanged: _setDarkModeEnabled,
            ),
    );
  }
}
