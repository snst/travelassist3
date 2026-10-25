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

  testWidgets('Swiping left does not delete an expense entry', (tester) async {
    final id = await database.addTransaction(
      kind: TransactionKind.expense,
      amount: 12,
      currency: 'EUR',
      comment: 'Keep this entry',
    );

    await tester.pumpWidget(
      MaterialApp(home: ExpensesListPage(database: database)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Dismissible), findsNothing);
    await tester.drag(find.byType(ListTile), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Keep this entry'), findsOneWidget);
    final entries = await database.select(database.moneyTransactions).get();
    expect(entries.map((entry) => entry.id), [id]);
    expect(find.text('Entry deleted'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
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
    expect(tagWrap.children.whereType<InkWell>().length, 2);
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
      findsNothing,
    );
    expect(find.widgetWithText(FilterChip, 'calendar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Shows hotel nights as a number overlay on the hotel icon', (
    tester,
  ) async {
    await database.addTransaction(
      kind: TransactionKind.hotel,
      amount: 120,
      currency: 'EUR',
      comment: 'Hotel booking',
      days: 3,
    );

    await tester.pumpWidget(
      MaterialApp(home: ExpensesListPage(database: database)),
    );
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(find.byType(ListTile).first);
    expect(tile.leading, isA<Stack>());
    expect(find.text('3'), findsOneWidget);
    expect(find.text('3 nights'), findsNothing);
    expect(find.text('1 night'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Transaction kinds are available as implicit tag filters', (
    tester,
  ) async {
    final kinds = {
      TransactionKind.expense: expenseTag,
      TransactionKind.withdrawal: atmTag,
      TransactionKind.cashCount: countTag,
      TransactionKind.deposit: depositTag,
      TransactionKind.hotel: hotelTag,
    };
    for (final kind in kinds.keys) {
      await database.addTransaction(
        kind: kind,
        amount: 12,
        currency: 'EUR',
        tags: kind == TransactionKind.expense ? [calendarTag] : [],
      );
    }

    await tester.pumpWidget(
      MaterialApp(home: ExpensesListPage(database: database)),
    );
    await tester.pumpAndSettle();

    for (final tag in kinds.values) {
      expect(find.widgetWithText(FilterChip, tag), findsOneWidget);
      expect(
        find.descendant(of: find.byType(ListTile), matching: find.text(tag)),
        tag == depositTag ? findsOneWidget : findsNothing,
      );
    }

    final atmFilterFinder = find.byWidgetPredicate(
      (widget) => widget is FilterChip && (widget.label as Text).data == atmTag,
    );
    expect(atmFilterFinder, findsOneWidget);
    await tester.tap(atmFilterFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(atmFilterFinder).selected, isTrue);
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('ATM'), findsOneWidget);

    await tester.tap(find.text('Clear filter'));
    await tester.pumpAndSettle();
    final calendarFilterFinder = find.widgetWithText(FilterChip, calendarTag);
    await tester.tap(calendarFilterFinder);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text(calendarTag), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Booked hotels have a green nights badge', (tester) async {
    await database.addTransaction(
      kind: TransactionKind.hotel,
      amount: 120,
      currency: 'EUR',
      comment: 'Booked hotel',
      tags: ['booked'],
      days: 3,
    );

    await tester.pumpWidget(
      MaterialApp(home: ExpensesListPage(database: database)),
    );
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(find.byType(ListTile).first);
    final leading = tile.leading! as Stack;
    final badge = (leading.children[1] as Positioned).child as Container;
    final decoration = badge.decoration! as BoxDecoration;
    expect(decoration.color, Colors.green.shade700);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  for (final brightness in Brightness.values) {
    for (final isPlanned in [true, false]) {
      testWidgets(
        '${brightness.name} transactions use a red icon background only when planned: $isPlanned',
        (tester) async {
          await database.addTransaction(
            kind: TransactionKind.expense,
            amount: 12,
            currency: 'EUR',
            tags: isPlanned ? ['planned'] : [],
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness: brightness,
                ),
              ),
              home: ExpensesListPage(database: database),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('PLANNED'), findsNothing);
          final tile = tester.widget<ListTile>(find.byType(ListTile).first);
          expect(tile.leading, isA<CircleAvatar>());
          final avatar = tile.leading! as CircleAvatar;
          final icon = avatar.child! as Icon;
          final scheme = Theme.of(tester.element(find.byType(ListTile).first))
              .colorScheme;
          expect(icon.color, isPlanned ? scheme.onErrorContainer : isNull);
          expect(
            avatar.backgroundColor,
            isPlanned ? scheme.errorContainer : scheme.surfaceContainerHigh,
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
        },
      );
    }
  }

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
          matching: find.text('cash'),
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
