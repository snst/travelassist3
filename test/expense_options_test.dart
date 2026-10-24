import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelassist3/widgets/expense_options.dart';

void main() {
  testWidgets(
    'Expense options are compact, independently selectable segments',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      bool? isPlanned;
      int? averageDays;
      bool? inCalendar;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseOptions(
              isPlanned: true,
              averageDays: 0,
              inCalendar: true,
              onPlannedChanged: (value) => isPlanned = value,
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
      final segmentedButton = tester
          .widgetList<SegmentedButton>(
            find.byWidgetPredicate((widget) => widget is SegmentedButton),
          )
          .single;
      expect(segmentedButton.segments, hasLength(3));
      expect(find.text('Planned'), findsOneWidget);
      expect(find.text('No average'), findsOneWidget);
      expect(find.text('In calendar'), findsOneWidget);

      await tester.tap(find.text('Planned'));
      await tester.tap(find.text('No average'));
      await tester.tap(find.text('In calendar'));

      expect(isPlanned, isFalse);
      expect(averageDays, 1);
      expect(inCalendar, isFalse);
    },
  );
}
