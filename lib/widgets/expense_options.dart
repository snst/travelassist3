import 'package:flutter/material.dart';
import '../database/database.dart';
import 'average_days_input.dart';

/// The "Planned" switch (toggles between planned and paid) and the "In average" day count of an expense.
class ExpenseOptions extends StatelessWidget {
  final TransactionState state;
  final int averageDays;
  final ValueChanged<TransactionState> onStateChanged;
  final ValueChanged<int> onAverageDaysChanged;

  const ExpenseOptions({
    super.key,
    required this.state,
    required this.averageDays,
    required this.onStateChanged,
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
            value: state == TransactionState.planned,
            onChanged: (planned) => onStateChanged(
              planned ? TransactionState.planned : TransactionState.paid,
            ),
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
