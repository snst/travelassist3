import 'package:flutter/material.dart';

class CurrencySelector extends StatelessWidget {
  final List<String> codes;
  final String selectedCode;
  final ValueChanged<String>? onSelected;

  const CurrencySelector({
    super.key,
    required this.codes,
    required this.selectedCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerRight,
      heightFactor: 1,
      child: PopupMenuButton<String>(
        tooltip: 'Select currency',
        enabled: onSelected != null && codes.isNotEmpty,
        onSelected: onSelected,
        padding: EdgeInsets.zero,
        itemBuilder: (context) => [
          for (final code in codes)
            PopupMenuItem<String>(
              value: code,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(code),
                  if (selectedCode == code) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.check, size: 18),
                  ],
                ],
              ),
            ),
        ],
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                selectedCode,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
