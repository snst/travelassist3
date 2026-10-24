import 'package:flutter/material.dart';

/// A switch for marking a hotel reservation as planned.
class ReservationState extends StatelessWidget {
  final bool isPlanned;
  final ValueChanged<bool> onPlannedChanged;

  const ReservationState({
    super.key,
    required this.isPlanned,
    required this.onPlannedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Planned'),
      value: isPlanned,
      onChanged: onPlannedChanged,
      secondary: const Icon(Icons.schedule),
    );
  }
}
