import 'package:flutter/material.dart';

/// Stepper for the number of days an expense counts in the daily average.
/// 0 means the expense is not included.
class DaysInput extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChanged;

  const DaysInput({
    super.key,
    required this.days,
    required this.onChanged,
  });

  String get _summary => switch (days) {
        1 => '1 night',
        _ => '$days nights',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //Text('Days', style: Theme.of(context).textTheme.bodyLarge),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Fewer days',
              visualDensity: VisualDensity.compact,
              onPressed: days > 0 ? () => onChanged(days - 1) : null,
            ),
            Expanded(
              child: Text(
                _summary,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'More days',
              visualDensity: VisualDensity.compact,
              onPressed: () => onChanged(days + 1),
            ),
          ],
        ),
      ],
    );
  }
}
