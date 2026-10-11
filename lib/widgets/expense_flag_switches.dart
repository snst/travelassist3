import 'package:flutter/material.dart';

/// The "Planned" and "In average" switches of an expense.
class ExpenseFlagSwitches extends StatelessWidget {
  final bool isPlanned;
  final bool includeInAverage;
  final ValueChanged<bool> onPlannedChanged;
  final ValueChanged<bool> onIncludeInAverageChanged;

  const ExpenseFlagSwitches({
    super.key,
    required this.isPlanned,
    required this.includeInAverage,
    required this.onPlannedChanged,
    required this.onIncludeInAverageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('In average'),
            value: includeInAverage,
            onChanged: onIncludeInAverageChanged,
          ),
        ),
      ],
    );
  }
}
