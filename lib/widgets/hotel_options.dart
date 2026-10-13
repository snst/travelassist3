import 'package:flutter/material.dart';
import '../database/database.dart';
import 'days_input.dart';

/// The planned / booked / paid selector and the "In average" day count of a hotel booking.
class HotelOptions extends StatelessWidget {
  final TransactionState state;
  final int days;
  final ValueChanged<TransactionState> onStateChanged;
  final ValueChanged<int> onDaysChanged;

  const HotelOptions({
    super.key,
    required this.state,
    required this.days,
    required this.onStateChanged,
    required this.onDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<TransactionState>(
            segments: const [
              ButtonSegment(
                value: TransactionState.planned,
                label: Text('Planned'),
                icon: Icon(Icons.schedule),
              ),
              ButtonSegment(
                value: TransactionState.booked,
                label: Text('Booked'),
                icon: Icon(Icons.event_available),
              ),
              ButtonSegment(
                value: TransactionState.paid,
                label: Text('Paid'),
                icon: Icon(Icons.paid_outlined),
              ),
            ],
            selected: {state},
            onSelectionChanged: (selection) => onStateChanged(selection.first),
          ),
        ),
        const SizedBox(height: 12),
        DaysInput(days: days, onChanged: onDaysChanged),
      ],
    );
  }
}
