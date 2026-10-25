import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/widgets/tag_filter_bar.dart';

void main() {
  for (final specialTags in [
    <String>[],
    [starTag],
    [positionTag],
    [positionTag, starTag],
  ]) {
    testWidgets('Special tags lead the filter bar: $specialTags', (tester) async {
      final tags = ['zebra', ...specialTags, 'alpha'];
      final originalTags = List<String>.of(tags);
      String? tappedTag;
      var cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagFilterBar(
              tags: tags,
              selectedTags: const ['alpha'],
              onTagSelected: (tag) => tappedTag = tag,
              onClear: () => cleared = true,
            ),
          ),
        ),
      );

      final chips = tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .toList();
      expect(chips.map((chip) => (chip.label as Text).data), [
        if (specialTags.contains(starTag)) starTag,
        if (specialTags.contains(positionTag)) positionTag,
        'zebra',
        'alpha',
      ]);
      expect(tags, originalTags);
      expect(chips.last.selected, isTrue);

      await tester.tap(find.text('zebra'));
      expect(tappedTag, 'zebra');
      await tester.tap(find.text('Clear filter'));
      expect(cleared, isTrue);
    });
  }
}
