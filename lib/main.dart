import 'package:flutter/material.dart';
import 'database/database.dart';
import 'screens/calculator_page.dart';
import 'screens/currency_settings_screen.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            tooltip: 'Calculator',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CalculatorPage(
                    database: widget.database,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Menu',
            onSelected: (value) {
              if (value == 'calculator') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CalculatorPage(
                      database: widget.database,
                    ),
                  ),
                );
              } else if (value == 'currency_settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CurrencySettingsScreen(
                      database: widget.database,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'calculator',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calculate, color: Colors.deepPurple),
                    SizedBox(width: 12),
                    Flexible(child: Text('Currency Calculator')),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'currency_settings',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.currency_exchange, color: Colors.deepPurple),
                    SizedBox(width: 12),
                    Flexible(child: Text('Currency Settings')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Currency>>(
        stream: widget.database.watchAllCurrencies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final currencies = snapshot.data ?? [];
          final homeCurrency = currencies.firstWhere(
            (c) => c.isHome,
            orElse: () => currencies.isNotEmpty
                ? currencies.first
                : const Currency(
                    id: 0,
                    name: 'None',
                    shortName: '---',
                    rate: 1.0,
                    isHome: false,
                  ),
          );

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.home, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Home Currency',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${homeCurrency.name} (${homeCurrency.shortName})',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Saved Currencies',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => CurrencySettingsScreen(
                              database: widget.database,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Manage'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: currencies.isEmpty
                      ? const Center(child: Text('No currencies available'))
                      : ListView.builder(
                          itemCount: currencies.length,
                          itemBuilder: (context, index) {
                            final currency = currencies[index];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  currency.shortName.isNotEmpty
                                      ? currency.shortName.substring(0, 1)
                                      : '\$',
                                ),
                              ),
                              title: Text(
                                '${currency.name} (${currency.shortName})',
                              ),
                              subtitle: Text('Rate: ${currency.rate}'),
                              trailing: currency.isHome
                                  ? const Chip(
                                      avatar: Icon(Icons.check, size: 16),
                                      label: Text('Home'),
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CalculatorPage(
                database: widget.database,
              ),
            ),
          );
        },
        icon: const Icon(Icons.calculate),
        label: const Text('Calculator'),
      ),
    );
  }
}
