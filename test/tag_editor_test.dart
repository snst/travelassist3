import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/widgets/tag_editor.dart';

void main() {
  testWidgets('reserved transaction tags are hidden and cannot be added', (
    tester,
  ) async {
    final addedTags = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagEditor(
            tags: [plannedTag, bookedTag, calendarTag, starTag, 'food'],
            availableTags: [
              plannedTag,
              bookedTag,
              calendarTag,
              starTag,
              'lunch',
            ],
            onTagAdded: addedTags.add,
            onTagRemoved: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(Chip), findsOneWidget);
    expect(find.text('food'), findsOneWidget);
    expect(find.text(plannedTag), findsNothing);
    expect(find.text(bookedTag), findsNothing);
    expect(find.text(calendarTag), findsNothing);
    expect(find.text(starTag), findsNothing);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('lunch'), findsOneWidget);

    await tester.enterText(find.byType(TextField), plannedTag);
    await tester.tap(find.byIcon(Icons.add));
    expect(addedTags, isEmpty);
    expect(find.text(plannedTag), findsNothing);
    await tester.enterText(find.byType(TextField), starTag);
    await tester.tap(find.byIcon(Icons.add));
    expect(addedTags, isEmpty);
  });

  testWidgets('star button adds and removes the hidden star tag', (
    tester,
  ) async {
    final tags = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TagEditor(
              tags: tags,
              availableTags: const [],
              onTagAdded: (tag) => setState(() => tags.add(tag)),
              onTagRemoved: (tag) => setState(() => tags.remove(tag)),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Add star tag'));
    await tester.pump();
    expect(tags, [starTag]);
    expect(find.text(starTag), findsNothing);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.star)).color,
      Colors.yellow.shade700,
    );

    await tester.tap(find.byTooltip('Remove star tag'));
    await tester.pump();
    expect(tags, isEmpty);
    expect(tester.widget<Icon>(find.byIcon(Icons.star)).color, isNull);
  });
}
