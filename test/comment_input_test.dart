import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelassist3/widgets/comment_input.dart';
import 'package:travelassist3/widgets/large_text_dialog.dart';

void main() {
  testWidgets('Can show a fullscreen text dialog from another widget',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showLargeTextDialog(context, 'Details from another widget'),
              child: const Text('Open details'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();

    expect(find.text('Details from another widget'), findsOneWidget);
    await tester.tap(find.text('Details from another widget'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Shows centered fullscreen info and closes when tapped',
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

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    final preview = tester.widget<Text>(find.text(text));
    expect(preview.data, text);
    expect(preview.textAlign, TextAlign.center);
    expect(preview.style?.fontSize, 26);
    expect(controller.text, text);

    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
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

  testWidgets('Long info is scrollable in the fullscreen view on a phone',
      (tester) async {
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
    expect(tester.widget<Text>(find.text(text)).data, text);
    final scrollView = find.byType(SingleChildScrollView);
    final scrollable = find.descendant(
      of: scrollView,
      matching: find.byType(Scrollable),
    ).first;
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    expect(find.byType(AppBar), findsNothing);
    expect(tester.getSize(find.byType(Dialog)), const Size(393, 820));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Copies the current info to the clipboard', (tester) async {
    final controller = TextEditingController(text: 'Info to copy');
    addTearDown(controller.dispose);
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<String, dynamic>)['text'] as String;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommentInput(controller: controller)),
      ),
    );

    await tester.tap(find.byTooltip('Copy info'));
    await tester.pumpAndSettle();

    expect(copiedText, 'Info to copy');
    expect(find.text('Info copied to clipboard'), findsOneWidget);
  });
}
