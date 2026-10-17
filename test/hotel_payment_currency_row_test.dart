import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelassist3/widgets/payment_currency_amount_input.dart';
import 'package:travelassist3/widgets/currency_selector.dart';

void main() {
  testWidgets('payment method and currency inputs fit in one phone-width row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PaymentCurrencyAmountInput(
              methods: const ['Cash'],
              selectedMethod: 'Cash',
              onMethodSelected: (_) {},
              onAddMethod: () {},
              currencyCodes: const ['USD', 'EUR', 'GBP'],
              selectedCurrencyCode: 'USD',
              onCurrencySelected: (_) {},
              amountController: TextEditingController(),
              autofocus: false,
              onAmountChanged: null,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(CurrencySelector)).width,
      lessThan(tester.getSize(find.byType(TextFormField)).width),
    );
  });
}
