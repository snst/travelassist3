import 'dart:ffi';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/screens/home_page.dart';

void main() {
  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () {
      return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
    });
  });

  Future<void> openDatabaseContent(
    WidgetTester tester,
    AppDatabase database,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(title: 'Travel Assist', database: database),
      ),
    );
    await tester.tap(find.byTooltip('Cash tools'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Manage database content'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('database content deletion requires confirmation and is scoped', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addCurrency(
      name: 'Euro',
      shortName: 'EUR',
      rate: 1,
      isHome: true,
    );
    await database.addTodoItem(name: 'Passport');
    await database.addNote(comment: 'Travel note');
    await database.addTransaction(
      kind: TransactionKind.expense,
      amount: 10,
      currency: 'EUR',
    );

    await openDatabaseContent(tester, database);

    for (final label in ['Currencies', 'Checklist', 'Notes', 'Transactions']) {
      expect(
        find.descendant(
          of: find.byType(Dialog).last,
          matching: find.text(label),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Import $label'), findsOneWidget);
      expect(find.byTooltip('Export $label'), findsOneWidget);
    }

    await tester.tap(find.byTooltip('Delete Notes'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Are you sure you want to delete all notes from the '
        'database? This cannot be undone.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Notes deleted'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());

    expect(await database.select(database.notes).get(), isEmpty);
    expect(await database.select(database.currencies).get(), hasLength(1));
    expect(await database.select(database.todoItems).get(), hasLength(1));
    expect(
      await database.select(database.moneyTransactions).get(),
      hasLength(1),
    );
  });

  testWidgets('cancelling database content deletion preserves the data', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addNote(comment: 'Travel note');

    await openDatabaseContent(tester, database);
    await tester.tap(find.byTooltip('Delete Notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());

    expect(await database.select(database.notes).get(), hasLength(1));
  });

  test('database content JSON round-trips every content category', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final transactionDate = DateTime(2025, 3, 14, 9, 26);
    await database.addCurrency(
      name: 'Euro',
      shortName: 'EUR',
      rate: 1,
      isHome: true,
    );
    await database.addTodoItem(
      name: 'Passport',
      category: 'Documents',
      comment: 'Check expiry',
      quantity: 2,
      used: 1,
      state: 2,
    );
    await database.addNote(
      comment: 'Travel note',
      link: 'https://example.com',
      tags: const ['trip', 'important'],
    );
    await database.addTransaction(
      kind: TransactionKind.expense,
      amount: 12.5,
      currency: 'EUR',
      method: 'Card',
      comment: 'Lunch',
      tags: const ['food'],
      date: transactionDate,
      days: 2,
      state: TransactionState.booked,
      link: 'https://example.com/receipt',
      showInCalendar: true,
    );

    final exports = <DatabaseContent, String>{
      for (final content in DatabaseContent.values)
        content: await database.exportContentAsJson(content),
    };
    for (final content in DatabaseContent.values) {
      await database.clearContent(content);
    }
    for (final content in DatabaseContent.values) {
      await database.importContentFromJson(
        content,
        exports[content]!,
        deleteExisting: true,
      );
    }

    final currencies = await database.select(database.currencies).get();
    expect(currencies.single.name, 'Euro');
    expect(currencies.single.isHome, isTrue);

    final todoItems = await database.select(database.todoItems).get();
    expect(todoItems.single.name, 'Passport');
    expect(todoItems.single.quantity, 2);
    expect(todoItems.single.state, 2);

    final notes = await database.select(database.notes).get();
    expect(notes.single.comment, 'Travel note');
    expect(notes.single.tags, 'trip,important');

    final transactions = await database
        .select(database.moneyTransactions)
        .get();
    expect(transactions.single.amount, 12.5);
    expect(transactions.single.date, transactionDate);
    expect(transactions.single.showInCalendar, isTrue);
    expect(transactions.single.state, TransactionState.booked.index);
  });

  test(
    'appending JSON preserves existing rows and assigns fresh IDs',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.addNote(comment: 'Existing note');
      final exportedNote = await database.exportContentAsJson(
        DatabaseContent.notes,
      );

      await database.importContentFromJson(
        DatabaseContent.notes,
        exportedNote,
        deleteExisting: false,
      );

      final notes = await database.select(database.notes).get();
      expect(notes.map((note) => note.comment), everyElement('Existing note'));
      expect(notes.map((note) => note.id).toSet(), hasLength(2));
    },
  );

  test('invalid JSON does not delete existing records', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addNote(comment: 'Keep this note');

    await expectLater(
      database.importContentFromJson(
        DatabaseContent.notes,
        '{"formatVersion":1,"content":"currencies","records":[]}',
        deleteExisting: true,
      ),
      throwsFormatException,
    );

    final notes = await database.select(database.notes).get();
    expect(notes.single.comment, 'Keep this note');
  });
}
