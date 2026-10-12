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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: scheme.surface,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final group in _groups)
                    _GroupSection(group: group, database: database),
                ],
              ),
            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 520
              ? 2
              : constraints.maxWidth < 820
                  ? 3
                  : 4;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 6),
                child: Text(
                  group.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              GridView.builder(
                itemCount: group.features.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 54,
                ),
                itemBuilder: (context, index) {
                  final feature = group.features[index];
                  return _FeatureCard(
                    feature: feature,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => feature.builder(database),
                      ),
                    ),
                  );
                },
              ),
            ],
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
    final isAdd = feature.kind == _FeatureKind.add;
    final background =
        isAdd ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final foreground =
        isAdd ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(feature.icon, color: foreground, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  feature.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (isAdd)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.add, color: foreground, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
