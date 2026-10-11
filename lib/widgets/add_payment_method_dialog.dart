import 'package:flutter/material.dart';

/// Asks for a new payment method; returns the trimmed name, or null if cancelled.
Future<String?> showAddPaymentMethodDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      void submit() {
        final trimmed = controller.text.trim();
        if (trimmed.isNotEmpty) Navigator.of(dialogContext).pop(trimmed);
      }

      return AlertDialog(
        title: const Text('Add Payment Method'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Credit Card, PayPal, Revolut',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(onPressed: submit, child: const Text('Add')),
        ],
      );
    },
  );
}
