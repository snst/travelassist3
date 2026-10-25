import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database/database.dart';

class DatabaseContentPage extends StatelessWidget {
  final AppDatabase database;
  final List<DatabaseProfile> databaseProfiles;
  final String activeDatabaseId;
  final Future<void> Function(String id)? onDatabaseSelected;
  final Future<void> Function(String name)? onDatabaseCreated;
  final Future<void> Function(String id)? onDatabaseDeleted;

  const DatabaseContentPage({
    super.key,
    required this.database,
    this.databaseProfiles = const [],
    this.activeDatabaseId = '',
    this.onDatabaseSelected,
    this.onDatabaseCreated,
    this.onDatabaseDeleted,
  });

  Future<String?> _promptForDatabaseName(BuildContext context) async {
    final controller = TextEditingController();
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<String>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add database'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Database name',
            hintText: 'e.g. Japan trip',
          ),
          onSubmitted: (name) => Navigator.of(dialogContext).pop(name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    try {
      final name = await navigator.push<String>(route);
      await route.completed;
      await WidgetsBinding.instance.endOfFrame;
      return name;
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _runDatabaseAction(
    BuildContext context,
    Future<void> Function()? action,
  ) async {
    if (action == null) return true;
    try {
      await action();
      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update database: $error')),
        );
      }
      return false;
    }
  }

  Future<void> _confirmDeleteDatabase(
    BuildContext context,
    DatabaseProfile profile,
  ) async {
    if (databaseProfiles.length <= 1) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmationContext) => AlertDialog(
        title: Text('Delete ${profile.name}?'),
        content: Text(
          'This will permanently delete "${profile.name}" and all of its data. '
          'This cannot be undone. If it is the active database, the app will '
          'switch to another database.',
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

    final deleted = await _runDatabaseAction(
      context,
      () async => await onDatabaseDeleted?.call(profile.id),
    );
    if (deleted && context.mounted) {
      Navigator.of(context).pop();
    }
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
      final imported = await database.importContentFromJson(
        content,
        json,
        onConflict: (conflict) => _resolveImportConflict(context, conflict),
      );
      if (imported == null || !context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Import complete'),
          content: Text(
            'Added: ${imported.added}\n'
            'Skipped: ${imported.skipped}\n'
            'Updated: ${imported.updated}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import ${content.label}: $error')),
      );
    }
  }

  Future<ImportConflictResolution> _resolveImportConflict(
    BuildContext context,
    ImportConflict conflict,
  ) async {
    final existingComment = conflict.existingComment?.trim();
    final importedComment = conflict.comment?.trim();
    final resolution = await showDialog<ImportConflictResolution>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('${conflict.content.label} item conflict'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An item with this UUID already exists, but its last-modified '
              'timestamp differs.\n\n'
              'Existing: ${conflict.existingLastModified.toLocal()}\n'
              'Imported: ${conflict.incomingLastModified.toLocal()}\n\n'
              'UUID: ${conflict.uuid}',
            ),
            if (existingComment != null && existingComment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Existing comment: $existingComment'),
            ],
            if (importedComment != null &&
                importedComment.isNotEmpty &&
                importedComment != existingComment) ...[
              const SizedBox(height: 12),
              Text('Imported comment: $importedComment'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext)
                    .pop(ImportConflictResolution.cancelImport),
            child: const Text('Cancel import'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(ImportConflictResolution.skip),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext)
                    .pop(ImportConflictResolution.overwrite),
            child: const Text('Overwrite'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext)
                    .pop(ImportConflictResolution.skipAll),
            child: const Text('Skip all'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext)
                    .pop(ImportConflictResolution.overwriteAll),
            child: const Text('Overwrite all'),
          ),
        ],
      ),
    );
    return resolution ?? ImportConflictResolution.cancelImport;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Database')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Databases', style: Theme.of(context).textTheme.titleMedium),
          for (final profile in databaseProfiles)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                profile.id == activeDatabaseId
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(profile.name),
              selected: profile.id == activeDatabaseId,
              trailing: IconButton(
                tooltip: databaseProfiles.length <= 1
                    ? 'Cannot delete the last database'
                    : 'Delete ${profile.name}',
                onPressed: databaseProfiles.length <= 1
                    ? null
                    : () => _confirmDeleteDatabase(context, profile),
                icon: const Icon(Icons.delete_outline),
              ),
              onTap: () async {
                if (profile.id == activeDatabaseId) {
                  Navigator.of(context).pop();
                  return;
                }
                final updated = await _runDatabaseAction(
                  context,
                  () async => await onDatabaseSelected?.call(profile.id),
                );
                if (updated && context.mounted) Navigator.of(context).pop();
              },
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final name = await _promptForDatabaseName(context);
                if (name == null || !context.mounted) return;
                final created = await _runDatabaseAction(
                  context,
                  () async => await onDatabaseCreated?.call(name),
                );
                if (created && context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add database'),
            ),
          ),
          const Divider(),
          for (final content in DatabaseContent.values)
            _DatabaseContentRow(
              content: content,
              onDelete: () => _confirmDeleteContent(context, content),
              onImport: () => _importContent(context, content),
              onExport: () => _exportContent(context, content),
            ),
        ],
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
    final canImportExport = content != DatabaseContent.currencies;
    return Row(
      children: [
        Expanded(child: Text(content.label)),
        IconButton(
          tooltip: 'Delete ${content.label}',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
        if (canImportExport) ...[
          IconButton(
            tooltip: 'Import ${content.label}',
            onPressed: onImport,
            icon: const Icon(Icons.file_open),
          ),
          IconButton(
            tooltip: 'Export ${content.label}',
            onPressed: onExport,
            icon: const Icon(Icons.save),
          ),
        ],
      ],
    );
  }
}
