import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/widgets/expense_options.dart';

void main() {
  testWidgets(
    'Expense options are compact, independently selectable segments',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      TransactionState? state;
      int? averageDays;
      bool? inCalendar;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseOptions(
              state: TransactionState.planned,
              averageDays: 0,
              inCalendar: true,
              onStateChanged: (value) => state = value,
              onAverageDaysChanged: (value) => averageDays = value,
              onCalendarChanged: (value) => inCalendar = value,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate((widget) => widget is SegmentedButton),
        findsOneWidget,
      );
      expect(find.text('Is Planned'), findsOneWidget);
      expect(find.text('No average'), findsOneWidget);
      expect(find.text('In calendar'), findsOneWidget);

      await tester.tap(find.text('Is Planned'));
      await tester.tap(find.text('No average'));
      await tester.tap(find.text('In calendar'));

      expect(state, TransactionState.paid);
      expect(averageDays, 1);
      expect(inCalendar, isFalse);
    },
  );
}
