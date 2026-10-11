import 'package:flutter/material.dart';
import '../database/database.dart';

/// App bar button that asks for confirmation, deletes [transaction] and closes the page.
class DeleteEntryButton extends StatelessWidget {
  final AppDatabase database;
  final MoneyTransaction transaction;

  const DeleteEntryButton({
    super.key,
    required this.database,
    required this.transaction,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await database.deleteTransaction(transaction.id);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      tooltip: 'Delete Entry',
      onPressed: () => _confirmDelete(context),
    );
  }
}
