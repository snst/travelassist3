import 'package:flutter/material.dart';

import 'currency_amount_input.dart';
import 'payment_method_selector.dart';

class PaymentCurrencyAmountInput extends StatelessWidget {
  final List<String> methods;
  final String selectedMethod;
  final ValueChanged<String> onMethodSelected;
  final VoidCallback onAddMethod;
  final List<String> currencyCodes;
  final String selectedCurrencyCode;
  final ValueChanged<String>? onCurrencySelected;
  final TextEditingController amountController;
  final bool autofocus;
  final ValueChanged<String>? onAmountChanged;

  const PaymentCurrencyAmountInput({
    super.key,
    required this.methods,
    required this.selectedMethod,
    required this.onMethodSelected,
    required this.onAddMethod,
    required this.currencyCodes,
    required this.selectedCurrencyCode,
    required this.onCurrencySelected,
    required this.amountController,
    required this.autofocus,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: PaymentMethodSelector(
            methods: methods,
            selectedMethod: selectedMethod,
            onSelected: onMethodSelected,
            onAddMethod: onAddMethod,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: CurrencyAmountInput(
            currencyCodes: currencyCodes,
            selectedCurrencyCode: selectedCurrencyCode,
            onCurrencySelected: onCurrencySelected,
            amountController: amountController,
            autofocus: autofocus,
            onAmountChanged: onAmountChanged,
          ),
        ),
      ],
    );
  }
}
