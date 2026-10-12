import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calculator/currency_value.dart';
import 'currency_selector.dart';

class CurrencyAmountInput extends StatelessWidget {
  final List<String> currencyCodes;
  final String selectedCurrencyCode;
  final ValueChanged<String>? onCurrencySelected;
  final TextEditingController amountController;
  final bool readOnly;
  final bool autofocus;
  final bool allowNegative;
  final String amountLabel;
  final ValueChanged<String>? onAmountChanged;
  final FormFieldValidator<String>? amountValidator;

  const CurrencyAmountInput({
    super.key,
    required this.currencyCodes,
    required this.selectedCurrencyCode,
    required this.onCurrencySelected,
    required this.amountController,
    this.readOnly = false,
    this.autofocus = true,
    this.allowNegative = false,
    this.amountLabel = 'Amount',
    required this.onAmountChanged,
    this.amountValidator = positiveAmountValidator,
  });

  /// Requires a non-empty amount greater than 0.
  static String? positiveAmountValidator(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Please enter an amount';
    if (CurrencyValue.safeConvertToDouble(value!) < 0) {
      return 'Amount must be >= 0';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CurrencySelector(
            codes: currencyCodes,
            selectedCode: selectedCurrencyCode,
            onSelected: onCurrencySelected,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 200,
          child: TextFormField(
            controller: amountController,
            readOnly: readOnly,
            autofocus: autofocus,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 18),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(allowNegative ? r'[0-9.,-]' : r'[0-9.,]'),
              ),
            ],
            decoration: InputDecoration(
              labelText: amountLabel,
              border: const OutlineInputBorder(),
            ),
            onChanged: onAmountChanged,
            validator: amountValidator,
          ),
        ),
      ],
    );
  }
}
