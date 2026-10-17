import 'package:flutter/material.dart';

import '../database/database.dart';

enum _ExpenseOption { planned, noAverage, calendar }

/// Compact, independently selectable options for an expense.
class ExpenseOptions extends StatelessWidget {
  final TransactionState state;
  final int averageDays;
  final bool inCalendar;
  final ValueChanged<TransactionState> onStateChanged;
  final ValueChanged<int> onAverageDaysChanged;
  final ValueChanged<bool> onCalendarChanged;

  const ExpenseOptions({
    super.key,
    required this.state,
    required this.averageDays,
    required this.inCalendar,
    required this.onStateChanged,
    required this.onAverageDaysChanged,
    required this.onCalendarChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isPlanned = state == TransactionState.planned;
    final noAverage = averageDays == 0;
    final selected = <_ExpenseOption>{
      if (isPlanned) _ExpenseOption.planned,
      if (noAverage) _ExpenseOption.noAverage,
      if (inCalendar) _ExpenseOption.calendar,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SegmentedButton<_ExpenseOption>(
        multiSelectionEnabled: true,
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: _ExpenseOption.planned,
            label: Text('Is Planned'),
          ),
          ButtonSegment(
            value: _ExpenseOption.noAverage,
            label: Text('No average'),
          ),
          ButtonSegment(
            value: _ExpenseOption.calendar,
            label: Text('In calendar'),
          ),
        ],
        selected: selected,
        onSelectionChanged: (newSelection) {
          final nowPlanned = newSelection.contains(_ExpenseOption.planned);
          if (nowPlanned != isPlanned) {
            onStateChanged(
              nowPlanned ? TransactionState.planned : TransactionState.paid,
            );
          }

          final nowNoAverage = newSelection.contains(_ExpenseOption.noAverage);
          if (nowNoAverage != noAverage) {
            onAverageDaysChanged(nowNoAverage ? 0 : 1);
          }

          final nowInCalendar = newSelection.contains(_ExpenseOption.calendar);
          if (nowInCalendar != inCalendar) {
            onCalendarChanged(nowInCalendar);
          }
        },
      ),
    );
  }
}
