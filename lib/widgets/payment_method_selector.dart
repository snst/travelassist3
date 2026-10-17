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
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: PopupMenuButton<_PaymentMethodAction>(
        tooltip: 'Select payment method',
        onSelected: (action) {
          final method = action.method;
          if (method == null) {
            onAddMethod();
          } else {
            onSelected(method);
          }
        },
        itemBuilder: (context) => [
          for (final method in methods)
            PopupMenuItem(
              value: _PaymentMethodAction.method(method),
              child: Text(method),
            ),
          if (methods.isNotEmpty) const PopupMenuDivider(),
          const PopupMenuItem(
            value: _PaymentMethodAction.add(),
            child: Row(
              children: [
                Icon(Icons.add),
                SizedBox(width: 12),
                Expanded(child: Text('Add payment method')),
              ],
            ),
          ),
        ],
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedMethod.isNotEmpty
                      ? selectedMethod
                      : 'Select payment method',
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodAction {
  const _PaymentMethodAction.method(this.method);
  const _PaymentMethodAction.add() : method = null;

  final String? method;
}
