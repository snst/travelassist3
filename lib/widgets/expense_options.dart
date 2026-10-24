import 'package:flutter/material.dart';

enum _ExpenseOption { planned, noAverage, calendar, custom }

/// Compact, independently selectable options for an expense.
class ExpenseOptions extends StatelessWidget {
  final bool isPlanned;
  final int? averageDays;
  final bool? inCalendar;
  final ValueChanged<bool> onPlannedChanged;
  final ValueChanged<int>? onAverageDaysChanged;
  final ValueChanged<bool>? onCalendarChanged;
  final String? customOptionLabel;
  final bool customOptionSelected;
  final ValueChanged<bool>? onCustomOptionChanged;

  const ExpenseOptions({
    super.key,
    required this.isPlanned,
    required this.onPlannedChanged,
    this.averageDays,
    this.inCalendar,
    this.onAverageDaysChanged,
    this.onCalendarChanged,
    this.customOptionLabel,
    this.customOptionSelected = false,
    this.onCustomOptionChanged,
  }) : assert((averageDays == null) == (onAverageDaysChanged == null)),
       assert((inCalendar == null) == (onCalendarChanged == null)),
       assert((customOptionLabel == null) == (onCustomOptionChanged == null)),
       assert(customOptionLabel != null || !customOptionSelected);

  @override
  Widget build(BuildContext context) {
    final noAverage = averageDays == 0;
    final selected = <_ExpenseOption>{
      if (isPlanned) _ExpenseOption.planned,
      if (noAverage) _ExpenseOption.noAverage,
      if (inCalendar == true) _ExpenseOption.calendar,
      if (customOptionSelected) _ExpenseOption.custom,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SegmentedButton<_ExpenseOption>(
        multiSelectionEnabled: true,
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: _ExpenseOption.planned,
            label: Text('Planned'),
            //icon: Icon(Icons.schedule),
          ),
          if (customOptionLabel != null)
            ButtonSegment(
              value: _ExpenseOption.custom,
              label: Text(customOptionLabel!),
            ),
          if (averageDays != null)
            const ButtonSegment(
              value: _ExpenseOption.noAverage,
              label: Text('No average'),
            ),
          if (inCalendar != null)
            const ButtonSegment(
              value: _ExpenseOption.calendar,
              label: Text('Calendar'),
            ),
        ],
        selected: selected,
        onSelectionChanged: (newSelection) {
          final nowPlanned = newSelection.contains(_ExpenseOption.planned);
          if (nowPlanned != isPlanned) {
            onPlannedChanged(nowPlanned);
          }

          if (averageDays != null) {
            final nowNoAverage = newSelection.contains(
              _ExpenseOption.noAverage,
            );
            if (nowNoAverage != noAverage) {
              onAverageDaysChanged?.call(nowNoAverage ? 0 : 1);
            }
          }

          if (inCalendar != null) {
            final nowInCalendar = newSelection.contains(
              _ExpenseOption.calendar,
            );
            if (nowInCalendar != inCalendar) {
              onCalendarChanged?.call(nowInCalendar);
            }
          }

          if (customOptionLabel != null) {
            final nowCustomOption = newSelection.contains(
              _ExpenseOption.custom,
            );
            if (nowCustomOption != customOptionSelected) {
              onCustomOptionChanged?.call(nowCustomOption);
            }
          }
        },
      ),
    );
  }
}
