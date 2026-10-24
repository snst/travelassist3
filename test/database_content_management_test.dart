import 'dart:ffi';
import 'dart:convert';

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
    await tester.tap(find.text('Database'));
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
      expect(
        find.byTooltip('Import $label'),
        label == 'Currencies' ? findsNothing : findsOneWidget,
      );
      expect(
        find.byTooltip('Export $label'),
        label == 'Currencies' ? findsNothing : findsOneWidget,
      );
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
      tags: const ['food', 'calendar', 'planned'],
      date: transactionDate,
      days: 2,
      link: 'https://example.com/receipt',
    );

    final exportContents = DatabaseContent.values
        .where((content) => content != DatabaseContent.currencies)
        .toList();
    final exports = <DatabaseContent, String>{
      for (final content in exportContents)
        content: await database.exportContentAsJson(content),
    };
    final transactionExport = jsonDecode(
      exports[DatabaseContent.transactions]!,
    ) as Map<String, dynamic>;
    expect(transactionExport['currencies'], hasLength(1));
    for (final content in DatabaseContent.values) {
      await database.clearContent(content);
    }
    for (final content in exportContents) {
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
    expect(transactions.single.tagList, contains('calendar'));
    expect(transactions.single.isPlanned, isTrue);
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

  test('imports skip existing checklist items and notes', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addTodoItem(
      name: 'Passport',
      category: 'Documents',
      comment: 'Check expiry',
      quantity: 2,
      used: 1,
      state: 0,
    );
    await database.addNote(
      comment: 'Travel note',
      link: 'https://example.com',
      tags: const ['trip'],
    );
    final existingNote = (await database.select(database.notes).get()).single;
    await database.updateNoteEntry(
      existingNote.copyWith(createdAt: DateTime(2025)),
    );

    final checklistExport = jsonDecode(
      await database.exportContentAsJson(DatabaseContent.checklist),
    ) as Map<String, dynamic>;
    final checklistRecord = Map<String, dynamic>.from(
      (checklistExport['records'] as List<dynamic>).single as Map,
    );
    final duplicateChecklistItem = Map<String, dynamic>.from(checklistRecord)
      ..['id'] = (checklistRecord['id'] as int) + 1;
    final newChecklistItem = Map<String, dynamic>.from(checklistRecord)
      ..['id'] = (checklistRecord['id'] as int) + 2
      ..['name'] = 'Boarding pass';
    checklistExport['records'] = [
      duplicateChecklistItem,
      duplicateChecklistItem,
      newChecklistItem,
    ];

    final notesExport = jsonDecode(
      await database.exportContentAsJson(DatabaseContent.notes),
    ) as Map<String, dynamic>;
    final noteRecord = Map<String, dynamic>.from(
      (notesExport['records'] as List<dynamic>).single as Map,
    );
    final duplicateNote = Map<String, dynamic>.from(noteRecord)
      ..['id'] = (noteRecord['id'] as int) + 1
      ..['createdAt'] = DateTime(2026).toIso8601String();
    final newNote = Map<String, dynamic>.from(duplicateNote)
      ..['id'] = (noteRecord['id'] as int) + 2
      ..['comment'] = 'Another note';
    notesExport['records'] = [duplicateNote, duplicateNote, newNote];

    await database.importContentFromJson(
      DatabaseContent.checklist,
      jsonEncode(checklistExport),
      deleteExisting: false,
    );
    await database.importContentFromJson(
      DatabaseContent.notes,
      jsonEncode(notesExport),
      deleteExisting: false,
    );

    final todoItems = await database.select(database.todoItems).get();
    expect(todoItems.map((item) => item.name), ['Passport', 'Boarding pass']);
    final notes = await database.select(database.notes).get();
    expect(notes.map((note) => note.comment), ['Travel note', 'Another note']);
    expect(notes.first.createdAt, DateTime(2025));
  });

  test('transaction imports skip existing and repeated transactions', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addCurrency(
      name: 'Euro',
      shortName: 'EUR',
      rate: 1,
      isHome: true,
    );
    await database.addTransaction(
      kind: TransactionKind.expense,
      amount: 10,
      currency: 'EUR',
      method: 'Card',
      comment: 'Lunch',
      tags: const ['food'],
      date: DateTime(2025, 3, 14),
    );

    final exported = jsonDecode(
      await database.exportContentAsJson(DatabaseContent.transactions),
    ) as Map<String, dynamic>;
    final original = Map<String, dynamic>.from(
      (exported['records'] as List<dynamic>).single as Map,
    );
    final duplicate = Map<String, dynamic>.from(original)
      ..['id'] = (original['id'] as int) + 1;
    final newTransaction = Map<String, dynamic>.from(original)
      ..['id'] = (original['id'] as int) + 2
      ..['comment'] = 'Dinner';
    exported['records'] = [duplicate, duplicate, newTransaction];

    await database.importContentFromJson(
      DatabaseContent.transactions,
      jsonEncode(exported),
      deleteExisting: false,
    );

    final transactions = await database
        .select(database.moneyTransactions)
        .get();
    expect(transactions, hasLength(2));
    expect(transactions.map((transaction) => transaction.comment).toSet(), {
      'Lunch',
      'Dinner',
    });
    expect(await database.select(database.currencies).get(), hasLength(1));
  });

  test(
    'appending a transaction export does not duplicate existing currencies',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.addCurrency(
        name: 'Euro',
        shortName: 'EUR',
        rate: 1,
        isHome: true,
      );
      await database.addTransaction(
        kind: TransactionKind.expense,
        amount: 10,
        currency: 'EUR',
      );
      final exported = await database.exportContentAsJson(
        DatabaseContent.transactions,
      );

      await database.importContentFromJson(
        DatabaseContent.transactions,
        exported,
        deleteExisting: false,
      );

      expect(await database.select(database.currencies).get(), hasLength(1));
      expect(
        await database.select(database.moneyTransactions).get(),
        hasLength(2),
      );
    },
  );

  test('legacy transaction status fields are not converted to tags', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    for (var i = 0; i < 3; i++) {
      await database.addTransaction(
        kind: TransactionKind.hotel,
        amount: 10,
        currency: 'EUR',
      );
    }

    final exported = jsonDecode(
      await database.exportContentAsJson(DatabaseContent.transactions),
    ) as Map<String, dynamic>;
    exported.remove('currencies');
    final legacyRecords = (exported['records'] as List<dynamic>).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      row
        ..remove('planned')
        ..['state'] = (row['id'] as int) - 1
        ..['showInCalendar'] = row['id'] == 1;
      return row;
    }).toList();
    exported['records'] = legacyRecords;

    await database.importContentFromJson(
      DatabaseContent.transactions,
      jsonEncode(exported),
      deleteExisting: true,
    );

    final transactions = await database
        .select(database.moneyTransactions)
        .get();
    expect(transactions.map((transaction) => transaction.isPlanned), [
      false,
      false,
      false,
    ]);
    expect(transactions.map((transaction) => transaction.tagList), [
      [],
      [],
      [],
    ]);
  });

  test('legacy planned boolean is not converted to a tag', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addTransaction(
      kind: TransactionKind.expense,
      amount: 10,
      currency: 'EUR',
      tags: const ['food'],
    );

    final exported = jsonDecode(
      await database.exportContentAsJson(DatabaseContent.transactions),
    ) as Map<String, dynamic>;
    final records = exported['records'] as List<dynamic>;
    final row = Map<String, dynamic>.from(records.single as Map)
      ..['planned'] = true;
    exported['records'] = [row];

    await database.importContentFromJson(
      DatabaseContent.transactions,
      jsonEncode(exported),
      deleteExisting: true,
    );

    final transaction =
        (await database.select(database.moneyTransactions).get()).single;
    expect(transaction.isPlanned, isFalse);
    expect(transaction.tagList, ['food']);
  });

  test('legacy transaction state is not converted to a planned tag', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addTransaction(
      kind: TransactionKind.expense,
      amount: 10,
      currency: 'EUR',
      tags: const ['food'],
    );

    final exported = jsonDecode(
      await database.exportContentAsJson(DatabaseContent.transactions),
    ) as Map<String, dynamic>;
    final records = exported['records'] as List<dynamic>;
    final row = Map<String, dynamic>.from(records.single as Map)
      ..['state'] = 0
      ..['showInCalendar'] = true;
    exported['records'] = [row];

    await database.importContentFromJson(
      DatabaseContent.transactions,
      jsonEncode(exported),
      deleteExisting: true,
    );

    final transaction =
        (await database.select(database.moneyTransactions).get()).single;
    expect(transaction.isPlanned, isFalse);
    expect(transaction.tagList, ['food']);
  });

  test(
    'database upgrade drops legacy status without converting values',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (rawDatabase) {
            rawDatabase.execute('''
            CREATE TABLE money_transactions (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              kind INTEGER NOT NULL DEFAULT 0,
              amount REAL NOT NULL,
              currency TEXT NOT NULL,
              method TEXT NOT NULL DEFAULT '',
              comment TEXT NOT NULL DEFAULT '',
              tags TEXT NOT NULL DEFAULT '',
              date INTEGER NOT NULL,
              days INTEGER NOT NULL DEFAULT 1,
              state INTEGER NOT NULL DEFAULT 2,
              link TEXT NOT NULL DEFAULT '',
              show_in_calendar INTEGER NOT NULL DEFAULT 0
            )
          ''');
            rawDatabase.execute('''
            INSERT INTO money_transactions
              (kind, amount, currency, tags, state, date, show_in_calendar)
            VALUES
              (4, 10, 'EUR', 'keep', 0, 0, 1),
              (4, 20, 'EUR', '', 1, 0, 0),
              (4, 30, 'EUR', '', 2, 0, 1)
          ''');
            rawDatabase.execute('PRAGMA user_version = 10');
          },
        ),
      );
      addTearDown(database.close);

      final transactions = await database
          .select(database.moneyTransactions)
          .get();
      expect(transactions.map((transaction) => transaction.isPlanned), [
        false,
        false,
        false,
      ]);
      expect(transactions.map((transaction) => transaction.tagList), [
        ['keep'],
        [],
        [],
      ]);
      final columns = await database
          .customSelect('PRAGMA table_info(money_transactions)')
          .get();
      expect(
        columns.map((column) => column.read<String>('name')),
        isNot(contains('state')),
      );
      expect(
        columns.map((column) => column.read<String>('name')),
        isNot(contains('show_in_calendar')),
      );
      expect(
        columns.map((column) => column.read<String>('name')),
        isNot(contains('planned')),
      );
    },
  );

  test(
    'pre-calendar-flag database drops legacy status without converting values',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (rawDatabase) {
            rawDatabase.execute('''
            CREATE TABLE money_transactions (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              kind INTEGER NOT NULL DEFAULT 0,
              amount REAL NOT NULL,
              currency TEXT NOT NULL,
              method TEXT NOT NULL DEFAULT '',
              comment TEXT NOT NULL DEFAULT '',
              tags TEXT NOT NULL DEFAULT '',
              date INTEGER NOT NULL,
              days INTEGER NOT NULL DEFAULT 1,
              state INTEGER NOT NULL DEFAULT 2,
              link TEXT NOT NULL DEFAULT ''
            )
          ''');
            rawDatabase.execute('''
            INSERT INTO money_transactions (kind, amount, currency, state, date)
            VALUES (0, 10, 'EUR', 0, 0)
          ''');
            rawDatabase.execute('PRAGMA user_version = 9');
          },
        ),
      );
      addTearDown(database.close);

      final transaction =
          (await database.select(database.moneyTransactions).get()).single;
      expect(transaction.isPlanned, isFalse);
      expect(transaction.tagList, isEmpty);
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
