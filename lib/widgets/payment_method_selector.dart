import 'package:flutter/material.dart';

class PaymentMethodSelector extends StatelessWidget {
  final List<String> methods;
  final String selectedMethod;
  final ValueChanged<String> onSelected;
  final VoidCallback onAddMethod;

  const PaymentMethodSelector({
    super.key,
    required this.methods,
    required this.selectedMethod,
    required this.onSelected,
    required this.onAddMethod,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment method',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final method in methods)
              ActionChip(
                backgroundColor: selectedMethod == method
                    ? Theme.of(context).colorScheme.primary
                    : null,
                label: Text(
                  method,
                  style: TextStyle(
                    fontWeight: selectedMethod == method
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: selectedMethod == method
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
                  ),
                ),
                onPressed: () => onSelected(method),
              ),
            ActionChip(
              avatar: const Icon(Icons.more_horiz, size: 18),
              label: const Text(''),
              onPressed: onAddMethod,
            ),
          ],
        ),
      ],
    );
  }
}
