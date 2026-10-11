import 'package:flutter/material.dart';
import 'average_days_input.dart';

/// The "Planned" switch and the "In average" day count of an expense.
class ExpenseOptions extends StatelessWidget {
  final bool isPlanned;
  final int averageDays;
  final ValueChanged<bool> onPlannedChanged;
  final ValueChanged<int> onAverageDaysChanged;

  const ExpenseOptions({
    super.key,
    required this.isPlanned,
    required this.averageDays,
    required this.onPlannedChanged,
    required this.onAverageDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Planned'),
            value: isPlanned,
            onChanged: onPlannedChanged,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: AverageDaysInput(
            days: averageDays,
            onChanged: onAverageDaysChanged,
          ),
        ),
      ],
    );
  }
}
