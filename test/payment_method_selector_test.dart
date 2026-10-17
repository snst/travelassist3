import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelassist3/widgets/payment_method_selector.dart';

void main() {
  testWidgets('selects a payment method from the popup menu', (tester) async {
    String? selectedMethod;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaymentMethodSelector(
            methods: const ['Cash', 'Card'],
            selectedMethod: 'Cash',
            onSelected: (method) => selectedMethod = method,
            onAddMethod: () {},
          ),
        ),
      ),
    );

    expect(find.text('Cash'), findsOneWidget);
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Card').last);
    await tester.pumpAndSettle();

    expect(selectedMethod, 'Card');
  });

  testWidgets('adds a payment method from the popup menu', (tester) async {
    var addMethodTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaymentMethodSelector(
            methods: const [],
            selectedMethod: '',
            onSelected: (_) {},
            onAddMethod: () => addMethodTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Select payment method'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add payment method'));
    expect(addMethodTapped, isTrue);
  });
}
