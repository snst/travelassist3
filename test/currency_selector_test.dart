import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelassist3/widgets/currency_selector.dart';

void main() {
  testWidgets('selects a currency from the popup menu', (tester) async {
    String? selectedCurrency;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CurrencySelector(
            codes: const ['USD', 'EUR', 'GBP'],
            selectedCode: 'USD',
            onSelected: (code) => selectedCurrency = code,
          ),
        ),
      ),
    );

    expect(find.text('USD'), findsOneWidget);
    expect(find.text('EUR'), findsNothing);
    expect(
      tester.getCenter(find.text('USD')).dx,
      tester.getCenter(find.byType(CurrencySelector)).dx,
    );

    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EUR'));
    await tester.pumpAndSettle();

    expect(selectedCurrency, 'EUR');
  });

  testWidgets('matches the amount field height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 150,
                child: CurrencySelector(
                  codes: const ['USD'],
                  selectedCode: 'USD',
                  onSelected: (_) {},
                ),
              ),
              SizedBox(
                width: 150,
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(CurrencySelector)).height,
      tester.getSize(find.byType(TextFormField)).height,
    );
  });
}
