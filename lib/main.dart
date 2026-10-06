import 'package:flutter/material.dart';
import 'database/database.dart';
import 'screens/home_page.dart';

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

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _database.seedInitialCurrenciesIfEmpty();
    _database.seedInitialTodoItemsIfEmpty();
    _database.seedInitialNotesIfEmpty();
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
      home: HomePage(title: 'Travel Assist', database: _database),
    );
  }
}
