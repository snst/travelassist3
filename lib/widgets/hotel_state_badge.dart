import 'package:flutter/material.dart';
import '../database/database.dart';

/// A colored pill showing the booking state of a hotel: planned, booked or paid.
class HotelStateBadge extends StatelessWidget {
  final TransactionState state;
  final bool compact;

  const HotelStateBadge({super.key, required this.state, this.compact = false});

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
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 8,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: state == TransactionState.planned ? foreground : background),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
