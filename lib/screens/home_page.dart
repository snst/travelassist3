import 'package:flutter/material.dart';
import '../database/database.dart';
import 'balance_page.dart';
import 'calculator_page.dart';
import 'cash_count_page.dart';
import 'currency_settings_screen.dart';
import 'deposit_page.dart';
import 'expense_page.dart';
import 'hotel_calendar_page.dart';
import 'hotel_page.dart';
import 'note_item_page.dart';
import 'note_list_page.dart';
import 'todo_list_page.dart';
import 'transaction_list_page.dart';
import 'withdrawal_page.dart';

enum _FeatureKind { add, view }

class _Feature {
  final String label;
  final IconData icon;
  final _FeatureKind kind;
  final Widget Function(AppDatabase database) builder;

  const _Feature.add(this.label, this.icon, this.builder)
      : kind = _FeatureKind.add;
  const _Feature.view(this.label, this.icon, this.builder)
      : kind = _FeatureKind.view;
}

class _FeatureGroup {
  final String title;
  final List<_Feature> features;

  const _FeatureGroup(this.title, this.features);
}

const _columns = 4;

final _groups = <_FeatureGroup>[
  _FeatureGroup('Spending', [
    _Feature.view('Calculator', Icons.calculate, (db) => CalculatorPage(database: db)),
    _Feature.add('Expense', Icons.shopping_bag_outlined, (db) => ExpensePage(database: db)),
    _Feature.view('Entries', Icons.receipt_long, (db) => TransactionListPage(database: db)),
    _Feature.view('Balance', Icons.pie_chart, (db) => BalancePage(database: db)),
  ]),
  _FeatureGroup('Cash', [
    _Feature.add('ATM', Icons.atm, (db) => WithdrawalPage(database: db)),
    _Feature.add('Deposit', Icons.savings_outlined, (db) => DepositPage(database: db)),
    _Feature.add('Count Cash', Icons.fact_check_outlined, (db) => CashCountPage(database: db)),
    _Feature.view('Currencies', Icons.currency_exchange, (db) => CurrencySettingsScreen(database: db)),
  ]),
  _FeatureGroup('Stay', [
    _Feature.add('Hotel', Icons.hotel, (db) => HotelPage(database: db)),
    _Feature.view('Hotels', Icons.calendar_month, (db) => HotelCalendarPage(database: db)),
  ]),
  _FeatureGroup('Organize', [
    _Feature.view('Checklist', Icons.checklist, (db) => TodoListPage(database: db)),
    _Feature.view('Notes', Icons.note_alt, (db) => NoteListPage(database: db)),
    _Feature.add('Add Note', Icons.note_add, (db) => NoteItemPage(database: db)),
  ]),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final group in _groups)
                _GroupSection(group: group, database: database),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  final _FeatureGroup group;
  final AppDatabase database;

  const _GroupSection({required this.group, required this.database});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Text(
              group.title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < _columns; i++)
                Expanded(
                  child: i < group.features.length
                      ? _FeatureCard(
                          feature: group.features[i],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  group.features[i].builder(database),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ],
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
    final isAdd = feature.kind == _FeatureKind.add;
    final background =
        isAdd ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final foreground =
        isAdd ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.all(3),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 76,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(feature.icon, size: 28, color: foreground),
                    const SizedBox(height: 6),
                    Text(
                      feature.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
              if (isAdd)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, size: 12, color: scheme.onPrimary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
