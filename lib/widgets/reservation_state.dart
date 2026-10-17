import 'package:flutter/material.dart';

import '../database/database.dart';

/// The planned, booked, or paid status selector for a hotel reservation.
class ReservationState extends StatelessWidget {
  final TransactionState state;
  final ValueChanged<TransactionState> onStateChanged;

  const ReservationState({
    super.key,
    required this.state,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
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
              onSelectionChanged: (selection) =>
                  onStateChanged(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}
