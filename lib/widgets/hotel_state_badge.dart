import 'package:flutter/material.dart';
import '../database/database.dart';

/// A colored pill showing the booking state of a hotel: planned, booked or paid.
class HotelStateBadge extends StatelessWidget {
  final TransactionState state;

  const HotelStateBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, background, foreground) = switch (state) {
      TransactionState.planned => (
          'PLANNED',
          Icons.schedule,
          scheme.surface,
          scheme.tertiary,
        ),
      TransactionState.booked => (
          'BOOKED',
          Icons.event_available,
          scheme.primary,
          scheme.onPrimary,
        ),
      TransactionState.paid => (
          'PAID',
          Icons.check_circle,
          Colors.green.shade700,
          Colors.white,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: state == TransactionState.planned ? foreground : background),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
