import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelassist3/widgets/comment_input.dart';

void main() {
  testWidgets('Shows the current info in large text without changing it',
      (tester) async {
    final controller = TextEditingController(text: 'Original info');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommentInput(controller: controller)),
      ),
    );

    const text = 'Updated info\nSecond line';
    await tester.enterText(find.byType(TextFormField), text);
    await tester.tap(find.byTooltip('Show large text'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    final preview = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(preview.data, text);
    expect(preview.style?.fontSize, 26);
    expect(controller.text, text);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(controller.text, text);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Shows an explicit empty state for blank info', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommentInput(controller: controller)),
      ),
    );

    await tester.tap(find.byTooltip('Show large text'));
    await tester.pumpAndSettle();
    expect(find.text('No info entered.'), findsOneWidget);
    expect(controller.text, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Long info is scrollable in the popup on a phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 820);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final text = List.generate(60, (index) => 'Info line $index').join('\n');
    final controller = TextEditingController(text: text);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommentInput(controller: controller)),
      ),
    );

    await tester.tap(find.byTooltip('Show large text'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      text,
    );
    final scrollView = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(SingleChildScrollView),
    );
    final scrollable = find.descendant(
      of: scrollView,
      matching: find.byType(Scrollable),
    ).first;
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    expect(find.text('Close').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
