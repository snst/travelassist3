import 'package:flutter/material.dart';

class CashCountHint extends StatelessWidget {
  final double expected;
  final String currencyCode;

  /// The amount entered so far; null while nothing has been entered.
  final double? counted;

  const CashCountHint({
    super.key,
    required this.expected,
    required this.currencyCode,
    required this.counted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difference = counted == null ? null : counted! - expected;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'Expected cash: ${expected.toStringAsFixed(2)} $currencyCode'
        '${difference == null ? '' : '   Difference: ${difference >= 0 ? '+' : ''}${difference.toStringAsFixed(2)}'}',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: difference != null && difference < 0
              ? theme.colorScheme.error
              : null,
        ),
      ),
    );
  }
}
