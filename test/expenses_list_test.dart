import 'dart:ffi';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/screens/expenses_list_page.dart';

void main() {
  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () {
      return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
    });
  });

  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.addCurrency(
      name: 'Euro',
      shortName: 'EUR',
      rate: 1,
      isHome: true,
    );
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('Shows info on the first line and tags below', (tester) async {
    const info = 'A long note about this expense';
    await database.addTransaction(
      kind: TransactionKind.expense,
      amount: 12,
      currency: 'EUR',
      comment: info,
      tags: ['food', 'lunch', 'calendar'],
      method: 'Visa',
    );

    await tester.pumpWidget(
      MaterialApp(home: ExpensesListPage(database: database)),
    );
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(find.byType(ListTile).first);
    final title = tile.title! as Text;
    final subtitle = tile.subtitle! as Column;

    expect(title.data, info);
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    final tagWrap = subtitle.children.first as Wrap;
    expect(tagWrap.children.whereType<InkWell>().length, 3);
    expect(
      find.descendant(of: find.byType(Wrap).first, matching: find.text('Visa')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(Wrap).first, matching: find.text('food')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Wrap).first,
        matching: find.text('lunch'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Wrap).first,
        matching: find.text('calendar'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Planned transactions use a blue outline instead of a badge', (
    tester,
  ) async {
    await database.addTransaction(
      kind: TransactionKind.expense,
      amount: 12,
      currency: 'EUR',
      tags: ['planned'],
    );

    await tester.pumpWidget(
      MaterialApp(home: ExpensesListPage(database: database)),
    );
    await tester.pumpAndSettle();

    expect(find.text('PLANNED'), findsNothing);
    final avatar = find.descendant(
      of: find.byType(ListTile).first,
      matching: find.byType(CircleAvatar),
    );
    final outline = find.ancestor(of: avatar, matching: find.byType(Container));
    final decoration =
        tester.widget<Container>(outline.first).decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(
      border.top.color,
      Theme.of(tester.element(avatar.first)).colorScheme.primary,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'Shows expense type on the first line and tags below when info is empty',
    (tester) async {
      await database.addTransaction(
        kind: TransactionKind.expense,
        amount: 12,
        currency: 'EUR',
        tags: ['food', 'lunch'],
      );

      await tester.pumpWidget(
        MaterialApp(home: ExpensesListPage(database: database)),
      );
      await tester.pumpAndSettle();

      final tile = tester.widget<ListTile>(find.byType(ListTile).first);
      final title = tile.title! as Text;

      expect(title.data, 'Expense');
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(tile.subtitle, isNotNull);
      final foodTag = find.descendant(
        of: find.byType(Wrap).first,
        matching: find.text('food'),
      );
      expect(foodTag, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Wrap).first,
          matching: find.text('lunch'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Wrap).first,
          matching: find.text('Cash'),
        ),
        findsOneWidget,
      );

      await tester.tap(foodTag);
      await tester.pumpAndSettle();
      final foodFilter = tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .firstWhere((chip) => (chip.label as Text).data == 'food');
      expect(foodFilter.selected, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
