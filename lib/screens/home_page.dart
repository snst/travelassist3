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

const _settingsMenuItem = 'settings';

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

final _cashTools = <_Feature>[
  _Feature.add('ATM', Icons.atm, (db) => WithdrawalPage(database: db)),
  _Feature.add('Deposit', Icons.savings_outlined, (db) => DepositPage(database: db)),
  _Feature.add('Count Cash', Icons.fact_check_outlined, (db) => CashCountPage(database: db)),
  _Feature.view('Currencies', Icons.currency_exchange, (db) => CurrencySettingsScreen(database: db)),
];

final _calculator = _Feature.view(
  'Calculator',
  Icons.calculate,
  (db) => CalculatorPage(database: db),
);

final _groups = <_FeatureGroup>[
  _FeatureGroup('Add', [
    _Feature.add('Add Hotel', Icons.hotel, (db) => HotelPage(database: db)),
    _Feature.add('Add Note', Icons.note_add, (db) => NoteItemPage(database: db)),
    _Feature.add('Add Expense', Icons.shopping_bag_outlined, (db) => ExpensePage(database: db)),
  ]),
  _FeatureGroup('View', [
    _Feature.view('Expenses', Icons.receipt_long, (db) => TransactionListPage(database: db)),
    _Feature.view('Balance', Icons.pie_chart, (db) => BalancePage(database: db)),
    _Feature.view('Hotels', Icons.calendar_month, (db) => HotelCalendarPage(database: db)),
    _Feature.view('Checklist', Icons.checklist, (db) => TodoListPage(database: db)),
    _Feature.view('Notes', Icons.note_alt, (db) => NoteListPage(database: db)),
  ]),
];

class HomePage extends StatelessWidget {
  final String title;
  final AppDatabase database;
  final bool darkModeEnabled;
  final Future<void> Function(bool enabled)? onDarkModeChanged;

  const HomePage({
    super.key,
    required this.title,
    required this.database,
    this.darkModeEnabled = false,
    this.onDarkModeChanged,
  });

  Future<void> _showSettings(BuildContext context) async {
    var selectedDarkMode = darkModeEnabled;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Settings'),
          content: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dark mode'),
            value: selectedDarkMode,
            onChanged: (enabled) async {
              await onDarkModeChanged?.call(enabled);
              setDialogState(() => selectedDarkMode = enabled);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.travel_explore,
                color: scheme.onPrimary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        actions: [
          PopupMenuButton<Object>(
            tooltip: 'Cash tools',
            icon: const Icon(Icons.more_vert),
            onSelected: (item) {
              if (item is _Feature) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => item.builder(database)),
                );
              } else if (item == _settingsMenuItem) {
                _showSettings(context);
              }
            },
            itemBuilder: (context) => [
              for (final feature in _cashTools)
                PopupMenuItem<Object>(
                  value: feature,
                  child: Row(
                    children: [
                      Icon(feature.icon, size: 20),
                      const SizedBox(width: 12),
                      Text(feature.label),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem<Object>(
                value: _settingsMenuItem,
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 40 + MediaQuery.textScalerOf(context).scale(14),
                    child: _FeatureCard(
                      feature: _calculator,
                      accent: scheme.secondary,
                      //prominent: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _calculator.builder(database),
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < _groups.length; i++) ...[
                    const SizedBox(height: 10),
                    _GroupSection(
                      group: _groups[i],
                      database: database,
                      accent: scheme.secondary,
                    ),
                  ],
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
  final Color accent;

  const _GroupSection({
    required this.group,
    required this.database,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 600 ? 2 : 4;
          final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
          final height = 40 + MediaQuery.textScalerOf(context).scale(14);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    group.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < group.features.length; i++)
                    SizedBox(
                      width: i == group.features.length - 1 &&
                              group.features.length % columns == 1
                          ? constraints.maxWidth
                          : width,
                      height: height,
                      child: _FeatureCard(
                        feature: group.features[i],
                        accent: accent,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => group.features[i].builder(database),
                          ),
                        ),
                      ),
                    ),
                ],
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
  final Color accent;
  final bool prominent;

  const _FeatureCard({
    required this.feature,
    required this.onTap,
    required this.accent,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAdd = feature.kind == _FeatureKind.add;
    return Material(
      clipBehavior: Clip.antiAlias,
      color: prominent ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(feature.icon, color: accent, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feature.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: prominent
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              /*if (isAdd)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.add, color: accent, size: 16),
                ),*/
            ],
          ),
        ),
      ),
    );
  }
}
