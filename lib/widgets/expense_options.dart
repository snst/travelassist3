import 'package:flutter/material.dart';
import '../database/database.dart';

/// The "Planned" and "In average" switches for an expense.
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
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('In average'),
            value: averageDays > 0,
            onChanged: (included) => onAverageDaysChanged(included ? 1 : 0),
          ),
        ),
      ],
    );
  }
}
