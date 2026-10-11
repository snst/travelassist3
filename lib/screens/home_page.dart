import 'package:flutter/material.dart';
import '../database/database.dart';
import 'balance_page.dart';
import 'calculator_page.dart';
import 'cash_count_page.dart';
import 'currency_settings_screen.dart';
import 'deposit_page.dart';
import 'expense_page.dart';
import 'note_list_page.dart';
import 'todo_list_page.dart';
import 'transaction_list_page.dart';
import 'withdrawal_page.dart';

class _Feature {
  final String label;
  final IconData icon;
  final Widget Function(AppDatabase database) builder;

  const _Feature(this.label, this.icon, this.builder);
}

final _features = <_Feature>[
  _Feature('Calculator', Icons.calculate, (db) => CalculatorPage(database: db)),
  _Feature('Entries', Icons.receipt_long, (db) => TransactionListPage(database: db)),
  _Feature('Expense', Icons.shopping_bag_outlined, (db) => ExpensePage(database: db)),
  _Feature('ATM', Icons.atm, (db) => WithdrawalPage(database: db)),
  _Feature('Deposit', Icons.savings_outlined, (db) => DepositPage(database: db)),
  _Feature('Count Cash', Icons.fact_check_outlined, (db) => CashCountPage(database: db)),
  _Feature('Balance', Icons.pie_chart, (db) => BalancePage(database: db)),
  _Feature('Checklist', Icons.checklist, (db) => TodoListPage(database: db)),
  _Feature('Notes', Icons.note_alt, (db) => NoteListPage(database: db)),
  _Feature('Currencies', Icons.currency_exchange, (db) => CurrencySettingsScreen(database: db)),
];

class HomePage extends StatelessWidget {
  final String title;
  final AppDatabase database;

  const HomePage({super.key, required this.title, required this.database});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: _features.length,
        itemBuilder: (context, index) {
          final feature = _features[index];
          return _FeatureCard(
            feature: feature,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => feature.builder(database)),
            ),
          );
        },
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  final VoidCallback onTap;

  const _FeatureCard({required this.feature, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(feature.icon, size: 48, color: scheme.onPrimaryContainer),
            const SizedBox(height: 12),
            Text(
              feature.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
