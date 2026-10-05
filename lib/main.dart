import 'package:flutter/material.dart';
import 'database/database.dart';
import 'screens/calculator_page.dart';
import 'screens/currency_settings_screen.dart';
import 'screens/note_list_page.dart';
import 'screens/todo_list_page.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(title: 'Travel Assist', database: _database),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final AppDatabase database;

  const MyHomePage({
    super.key,
    required this.title,
    required this.database,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    CalculatorPage(database: widget.database),
    TodoListPage(database: widget.database),
    NoteListPage(database: widget.database),
    CurrencySettingsScreen(database: widget.database),
  ];

  @override
  Widget build(BuildContext context) {
    // IndexedStack keeps every feature mounted so switching tabs preserves its state.
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Calculator',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Checklist',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.currency_exchange_outlined),
            selectedIcon: Icon(Icons.currency_exchange),
            label: 'Currencies',
          ),
        ],
      ),
    );
  }
}
