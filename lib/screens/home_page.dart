import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database/database.dart';
import 'balance_page.dart';
import 'calculator_page.dart';
import 'cash_count_page.dart';
import 'currency_settings_screen.dart';
import 'deposit_page.dart';
import 'expense_page.dart';
import 'calendar_page.dart';
import 'hotel_page.dart';
import 'note_item_page.dart';
import 'note_list_page.dart';
import 'todo_list_page.dart';
import 'expenses_list_page.dart';
import 'withdrawal_page.dart';

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

final _cashTools = <_Feature>[
  _Feature('ATM', Icons.atm, (db) => WithdrawalPage(database: db)),
  _Feature(
    'Deposit',
    Icons.savings_outlined,
    (db) => DepositPage(database: db),
  ),
  _Feature(
    'Count Cash',
    Icons.fact_check_outlined,
    (db) => CashCountPage(database: db),
  ),
  _Feature(
    'Currencies',
    Icons.currency_exchange,
    (db) => CurrencySettingsScreen(database: db),
  ),
];

final _calculator = _Feature(
  'Calculator',
  Icons.calculate,
  (db) => CalculatorPage(database: db),
);

final _groups = <_FeatureGroup>[
  _FeatureGroup([_calculator]),
  _FeatureGroup([
    _Feature('Add Hotel', Icons.hotel, (db) => HotelPage(database: db)),
    _Feature('Add Note', Icons.note_add, (db) => NoteItemPage(database: db)),
    _Feature(
      'Add Position',
      Icons.add_location_alt,
      (db) => NoteItemPage(
        database: db,
        initialTags: const ['📍'],
        captureGpsLocation: true,
      ),
    ),
    _Feature(
      'Add Expense',
      Icons.shopping_bag_outlined,
      (db) => ExpensePage(database: db),
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
      (db) => NoteListPage(database: db, initialFilterTags: const ['⭐']),
    ),
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
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<bool>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark mode'),
              value: darkModeEnabled,
              onChanged: (enabled) => Navigator.of(context).pop(enabled),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
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

  Future<void> _showDatabaseContent(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Manage database content'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final content in DatabaseContent.values)
                _DatabaseContentRow(
                  content: content,
                  onDelete: () => _confirmDeleteContent(dialogContext, content),
                  onImport: () => _importContent(dialogContext, content),
                  onExport: () => _exportContent(dialogContext, content),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteContent(
    BuildContext context,
    DatabaseContent content,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmationContext) => AlertDialog(
        title: Text('Delete ${content.label}?'),
        content: Text(
          'Are you sure you want to delete all ${content.label.toLowerCase()} '
          'from the database? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmationContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(confirmationContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await database.clearContent(content);
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not delete ${content.label.toLowerCase()}: $error',
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('${content.label} deleted')));
  }

  Future<void> _importContent(
    BuildContext context,
    DatabaseContent content,
  ) async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Import ${content.label}',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null || !context.mounted) return;

      final json = utf8.decode(await file.readAsBytes());
      if (!context.mounted) return;
      final existingCount = await database.countContent(content);
      var deleteExisting = false;
      if (existingCount > 0) {
        if (!context.mounted) return;
        final choice = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Import ${content.label}?'),
            content: Text(
              'There are already $existingCount ${content.label.toLowerCase()}. '
              'Delete the existing items before importing?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel import'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep existing'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete and import'),
              ),
            ],
          ),
        );
        if (choice == null) return;
        deleteExisting = choice;
      }

      await database.importContentFromJson(
        content,
        json,
        deleteExisting: deleteExisting,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${content.label} imported')));
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import ${content.label}: $error')),
      );
    }
  }

  Future<void> _exportContent(
    BuildContext context,
    DatabaseContent content,
  ) async {
    try {
      final now = DateTime.now();
      final date =
          '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final time =
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';
      final json = await database.exportContentAsJson(content);
      final savedFile = await FilePicker.saveFile(
        dialogTitle: 'Export ${content.label}',
        fileName: '${content.name}_${date}_$time.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
      );
      if (savedFile == null || !context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${content.label} exported')));
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export ${content.label}: $error')),
      );
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
                _showDatabaseContent(context);
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
              const PopupMenuItem<Object>(
                value: _databaseContentMenuItem,
                child: Row(
                  children: [
                    Icon(Icons.storage_outlined, size: 20),
                    SizedBox(width: 12),
                    Flexible(child: Text('Manage database content')),
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

class _DatabaseContentRow extends StatelessWidget {
  final DatabaseContent content;
  final VoidCallback onDelete;
  final VoidCallback onImport;
  final VoidCallback onExport;

  const _DatabaseContentRow({
    required this.content,
    required this.onDelete,
    required this.onImport,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(content.label)),
        IconButton(
          tooltip: 'Delete ${content.label}',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
        IconButton(
          tooltip: 'Import ${content.label}',
          onPressed: onImport,
          icon: const Icon(Icons.file_upload_outlined),
        ),
        IconButton(
          tooltip: 'Export ${content.label}',
          onPressed: onExport,
          icon: const Icon(Icons.file_download_outlined),
        ),
      ],
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
