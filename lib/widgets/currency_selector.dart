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
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: [
        for (final code in codes)
          ChoiceChip(
            label: Text(code),
            selected: selectedCode == code,
            showCheckmark: false,
            selectedColor: Theme.of(context).colorScheme.primary,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: selectedCode == code
                  ? Theme.of(context).colorScheme.onPrimary
                  : null,
            ),
            onSelected: onSelected == null ? null : (_) => onSelected!(code),
          ),
      ],
    );
  }
}
