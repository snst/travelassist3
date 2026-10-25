import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../database/database.dart';
import 'balance_page.dart';
import 'calculator_page.dart';
import 'currency_settings_screen.dart';
import 'expense_page.dart';
import 'calendar_page.dart';
import 'hotel_page.dart';
import 'note_item_page.dart';
import 'note_list_page.dart';
import 'todo_list_page.dart';
import 'expenses_list_page.dart';
import 'database_content_page.dart';

const _settingsMenuItem = 'settings';
const _databaseContentMenuItem = 'database-content';

class _Feature {
  final String label;
  final IconData icon;
  final Widget Function(AppDatabase database) builder;

  const _Feature(this.label, this.icon, this.builder);
}

class _FeatureGroup {
  final List<_Feature> features;

  const _FeatureGroup(this.features);
}

final _currencies = _Feature(
  'Currencies',
  Icons.currency_exchange,
  (db) => CurrencySettingsScreen(database: db),
);

final _calculator = _Feature(
  'Calculator',
  Icons.calculate,
  (db) => CalculatorPage(database: db),
);

final _groups = <_FeatureGroup>[
  _FeatureGroup([_calculator]),
  _FeatureGroup([
    _Feature(
      'Add Hotel',
      Icons.hotel,
      (db) => HotelPage(database: db, openExpensesListOnSave: true),
    ),
    _Feature(
      'Add Note',
      Icons.note_add,
      (db) => NoteItemPage(database: db, openListOnSave: true),
    ),
    _Feature(
      'Add Position',
      Icons.add_location_alt,
      (db) => NoteItemPage(
        database: db,
        initialTags: const [positionTag],
        captureGpsLocation: true,
        openListOnSave: true,
      ),
    ),
    _Feature(
      'Add Expense',
      Icons.shopping_bag_outlined,
      (db) => ExpensePage(database: db, openExpensesListOnSave: true),
    ),
  ]),
  _FeatureGroup([
    _Feature(
      'Expenses',
      Icons.receipt_long,
      (db) => ExpensesListPage(database: db),
    ),
    _Feature('Balance', Icons.pie_chart, (db) => BalancePage(database: db)),
    _Feature(
      'Calendar',
      Icons.calendar_month,
      (db) => CalendarPage(database: db),
    ),
    _Feature('Checklist', Icons.checklist, (db) => TodoListPage(database: db)),
    _Feature('Notes', Icons.note_alt, (db) => NoteListPage(database: db)),
    _Feature(
      'Starred Notes',
      Icons.star,
      (db) => NoteListPage(database: db, initialFilterTags: const [starTag]),
    ),
  ]),
];

class HomePage extends StatelessWidget {
  final String title;
  final AppDatabase database;
  final List<DatabaseProfile> databaseProfiles;
  final String activeDatabaseId;
  final Future<void> Function(String id)? onDatabaseSelected;
  final Future<void> Function(String name)? onDatabaseCreated;
  final Future<void> Function(String id)? onDatabaseDeleted;
  final bool darkModeEnabled;
  final Future<void> Function(bool enabled)? onDarkModeChanged;

  const HomePage({
    super.key,
    required this.title,
    required this.database,
    this.databaseProfiles = const [],
    this.activeDatabaseId = '',
    this.onDatabaseSelected,
    this.onDatabaseCreated,
    this.onDatabaseDeleted,
    this.darkModeEnabled = false,
    this.onDarkModeChanged,
  });

  Future<void> _showSettings(BuildContext context) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<bool>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Settings'),
        content: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Dark mode'),
          value: darkModeEnabled,
          onChanged: (enabled) => Navigator.of(dialogContext).pop(enabled),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    final enabled = await navigator.push<bool>(route);
    // The route completes when its exit animation ends; its widgets are only
    // unmounted in the following frame, so wait for that before changing theme.
    await route.completed;
    await WidgetsBinding.instance.endOfFrame;
    if (enabled != null && context.mounted) {
      await onDarkModeChanged?.call(enabled);
    }
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
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
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
              } else if (item == _databaseContentMenuItem) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DatabaseContentPage(
                      database: database,
                      databaseProfiles: databaseProfiles,
                      activeDatabaseId: activeDatabaseId,
                      onDatabaseSelected: onDatabaseSelected,
                      onDatabaseCreated: onDatabaseCreated,
                      onDatabaseDeleted: onDatabaseDeleted,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<Object>(
                value: _currencies,
                child: Row(
                  children: [
                    Icon(_currencies.icon, size: 20),
                    const SizedBox(width: 12),
                    Text(_currencies.label),
                  ],
                ),
              ),
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
              const PopupMenuItem<Object>(
                value: _databaseContentMenuItem,
                child: Row(
                  children: [
                    Icon(Icons.storage_outlined, size: 20),
                    SizedBox(width: 12),
                    Flexible(child: Text('Database')),
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
    final scheme = Theme.of(context).colorScheme;
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
          // Clamped: the first frame can be laid out with a zero-width viewport.
          final width = math.max(
            0.0,
            (constraints.maxWidth - 8 * (columns - 1)) / columns,
          );
          final height = 40 + MediaQuery.textScalerOf(context).scale(14);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < group.features.length; i++)
                    SizedBox(
                      width:
                          i == group.features.length - 1 &&
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

  const _FeatureCard({
    required this.feature,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerLow,
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
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
