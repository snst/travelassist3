import 'dart:ffi';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/screens/database_content_page.dart';
import 'package:travelassist3/screens/home_page.dart';

Future<ImportConflictResolution> _skipConflicts(
  ImportConflict conflict,
) async => ImportConflictResolution.skipAll;

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
    expect(find.byType(DatabaseContentPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  test(
    'records get UUIDs and refresh last-modified timestamps on save',
    () async {
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

      final currency =
          (await database.select(database.currencies).get()).single;
      final todo = (await database.select(database.todoItems).get()).single;
      final note = (await database.select(database.notes).get()).single;
      final transaction =
          (await database.select(database.moneyTransactions).get()).single;
      final uuids = [currency.uuid, todo.uuid, note.uuid, transaction.uuid];

      expect(uuids.toSet(), hasLength(4));
      for (final uuid in uuids) {
        expect(
          uuid,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
      }

      final oldTimestamp = DateTime(2000);
      await database.updateCurrencyEntry(
        currency.copyWith(name: 'Euro updated', lastModified: oldTimestamp),
      );
      await database.updateTodoItemEntry(
        todo.copyWith(name: 'Passport updated', lastModified: oldTimestamp),
      );
      await database.updateNoteEntry(
        note.copyWith(
          comment: 'Travel note updated',
          lastModified: oldTimestamp,
        ),
      );
      await database.updateTransactionEntry(
        transaction.copyWith(comment: 'Lunch', lastModified: oldTimestamp),
      );

      expect(
        (await database.select(database.currencies).get()).single.lastModified
            .isAfter(oldTimestamp),
        isTrue,
      );
      expect(
        (await database.select(database.todoItems).get()).single.lastModified
            .isAfter(oldTimestamp),
        isTrue,
      );
      expect(
        (await database.select(database.notes).get()).single.lastModified
            .isAfter(oldTimestamp),
        isTrue,
      );
      expect(
        (await database.select(database.moneyTransactions).get())
            .single
            .lastModified
            .isAfter(oldTimestamp),
        isTrue,
      );
    },
  );

  test('imports older exports without UUID or last-modified fields', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addNote(comment: 'Legacy note');
    final exported = jsonDecode(
      await database.exportContentAsJson(DatabaseContent.notes),
    ) as Map<String, dynamic>;
    final record = Map<String, dynamic>.from(
      (exported['records'] as List<dynamic>).single as Map,
    )..removeWhere((key, _) => key == 'uuid' || key == 'lastModified');
    final nullMetadataRecord = Map<String, dynamic>.from(record)
      ..['uuid'] = null
      ..['lastModified'] = null
      ..['comment'] = 'Legacy note with null metadata';
    exported['records'] = [record, nullMetadataRecord];

    await database.clearContent(DatabaseContent.notes);
    final importStarted = DateTime.now().subtract(const Duration(seconds: 1));
    await database.importContentFromJson(
      DatabaseContent.notes,
      jsonEncode(exported),
      onConflict: _skipConflicts,
    );
    final importFinished = DateTime.now().add(const Duration(seconds: 1));

    final restored = await database.select(database.notes).get();
    expect(restored.map((note) => note.comment).toSet(), {
      'Legacy note',
      'Legacy note with null metadata',
    });
    expect(restored.map((note) => note.uuid).toSet(), hasLength(2));
    for (final note in restored) {
      expect(note.uuid, isNotEmpty);
      expect(note.lastModified.isAfter(importStarted), isTrue);
      expect(note.lastModified.isBefore(importFinished), isTrue);
    }
  });

  test('conflicting UUIDs support skip, overwrite, and apply-to-all', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addNote(comment: 'First');
    await database.addNote(comment: 'Second');

    Future<Map<String, dynamic>> changedExport(DateTime modifiedAt) async {
      final decoded = jsonDecode(
        await database.exportContentAsJson(DatabaseContent.notes),
      ) as Map<String, dynamic>;
      decoded['records'] = (decoded['records'] as List<dynamic>).map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        row
          ..['comment'] = '${row['comment']} updated'
          ..['lastModified'] = modifiedAt.toIso8601String();
        return row;
      }).toList();
      return decoded;
    }

    final overwriteExport = jsonEncode(await changedExport(DateTime(2030)));
    var conflictCount = 0;
    final imported = await database.importContentFromJson(
      DatabaseContent.notes,
      overwriteExport,
      onConflict: (_) async {
        conflictCount++;
        return ImportConflictResolution.overwriteAll;
      },
    );
    expect(imported, isNotNull);
    expect(imported!.added, 0);
    expect(imported.skipped, 0);
    expect(imported.updated, 2);
    expect(conflictCount, 1);
    expect(
      (await database.select(database.notes).get())
          .map((note) => note.comment)
          .toSet(),
      {'First updated', 'Second updated'},
    );

    final skipExport = jsonEncode(await changedExport(DateTime(2040)));
    conflictCount = 0;
    final skipped = await database.importContentFromJson(
      DatabaseContent.notes,
      skipExport,
      onConflict: (_) async {
        conflictCount++;
        return ImportConflictResolution.skipAll;
      },
    );
    expect(skipped, isNotNull);
    expect(skipped!.added, 0);
    expect(skipped.skipped, 2);
    expect(skipped.updated, 0);
    expect(conflictCount, 1);
    expect(
      (await database.select(database.notes).get())
          .map((note) => note.comment)
          .toSet(),
      {'First updated', 'Second updated'},
    );
  });

  test('conflict callback can skip or overwrite a single item', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addNote(comment: 'Original');
    final decoded = jsonDecode(
      await database.exportContentAsJson(DatabaseContent.notes),
    ) as Map<String, dynamic>;
    final record =
        Map<String, dynamic>.from(
            (decoded['records'] as List<dynamic>).single as Map,
          )
          ..['comment'] = 'Replacement'
          ..['lastModified'] = DateTime(2030).toIso8601String();
    decoded['records'] = [record];

    String? conflictComment;
    final skipped = await database.importContentFromJson(
      DatabaseContent.notes,
      jsonEncode(decoded),
      onConflict: (conflict) async {
        conflictComment = conflict.comment;
        return ImportConflictResolution.skip;
      },
    );
    expect(conflictComment, 'Replacement');
    expect(skipped?.added, 0);
    expect(skipped?.skipped, 1);
    expect(skipped?.updated, 0);
    expect(
      (await database.select(database.notes).get()).single.comment,
      'Original',
    );

    final overwritten = await database.importContentFromJson(
      DatabaseContent.notes,
      jsonEncode(decoded),
      onConflict: (_) async => ImportConflictResolution.overwrite,
    );
    expect(overwritten?.added, 0);
    expect(overwritten?.skipped, 0);
    expect(overwritten?.updated, 1);
    expect(
      (await database.select(database.notes).get()).single.comment,
      'Replacement',
    );
  });

  test('expense conflicts include existing and imported comments', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addTransaction(
      kind: TransactionKind.expense,
      amount: 12,
      currency: 'EUR',
      comment: 'Current expense note',
    );
    final decoded = jsonDecode(
      await database.exportContentAsJson(DatabaseContent.transactions),
    ) as Map<String, dynamic>;
    final record = Map<String, dynamic>.from(
      (decoded['records'] as List<dynamic>).single as Map,
    );
    final importedDate = DateTime(2030, 1, 2);
    final importedModified = DateTime(2030, 1, 2, 3, 4, 5, 678);
    record
      ..['kind'] = TransactionKind.hotel.index
      ..['amount'] = 88.5
      ..['currency'] = 'USD'
      ..['method'] = 'Card'
      ..['comment'] = 'Imported expense note'
      ..['tags'] = ['trip', 'booked']
      ..['date'] = importedDate.toIso8601String()
      ..['days'] = 7
      ..['link'] = ['https://example.com/receipt']
      ..['lastModified'] = importedModified.toIso8601String();
    decoded['records'] = [record];

    ImportConflict? receivedConflict;
    await database.importContentFromJson(
      DatabaseContent.transactions,
      jsonEncode(decoded),
      onConflict: (conflict) async {
        receivedConflict = conflict;
        return ImportConflictResolution.skip;
      },
    );

    expect(receivedConflict?.existingComment, 'Current expense note');
    expect(receivedConflict?.comment, 'Imported expense note');

    final summary = await database.importContentFromJson(
      DatabaseContent.transactions,
      jsonEncode(decoded),
      onConflict: (_) async => ImportConflictResolution.overwrite,
    );
    expect(summary?.updated, 1);
    final overwritten =
        (await database.select(database.moneyTransactions).get()).single;
    expect(overwritten.kind, TransactionKind.hotel.index);
    expect(overwritten.amount, 88.5);
    expect(overwritten.currency, 'USD');
    expect(overwritten.method, 'Card');
    expect(overwritten.comment, 'Imported expense note');
    expect(overwritten.tags, 'trip\tbooked');
    expect(overwritten.date, importedDate);
    expect(overwritten.days, 7);
    expect(overwritten.link, 'https://example.com/receipt');
    expect(overwritten.lastModified, importedModified);

    var repeatedConflicts = 0;
    final repeatedImport = await database.importContentFromJson(
      DatabaseContent.transactions,
      jsonEncode(decoded),
      onConflict: (_) async {
        repeatedConflicts++;
        return ImportConflictResolution.skip;
      },
    );
    expect(repeatedConflicts, 0);
    expect(repeatedImport?.added, 0);
    expect(repeatedImport?.skipped, 1);
    expect(repeatedImport?.updated, 0);

    final changedInSameSecond = DateTime(2030, 1, 2, 3, 4, 5, 679);
    record['lastModified'] = changedInSameSecond.toIso8601String();
    var sameSecondConflicts = 0;
    final changedImport = await database.importContentFromJson(
      DatabaseContent.transactions,
      jsonEncode(decoded),
      onConflict: (_) async {
        sameSecondConflicts++;
        return ImportConflictResolution.overwrite;
      },
    );
    expect(sameSecondConflicts, 1);
    expect(changedImport?.updated, 1);
    expect(
      (await database.select(database.moneyTransactions).get())
          .single
          .lastModified,
      changedInSameSecond,
    );
  });

  test('cancelling a conflict leaves the import unapplied', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addNote(comment: 'Original');
    final decoded = jsonDecode(
      await database.exportContentAsJson(DatabaseContent.notes),
    ) as Map<String, dynamic>;
    final original = Map<String, dynamic>.from(
      (decoded['records'] as List<dynamic>).single as Map,
    )..['lastModified'] = DateTime(2030).toIso8601String();
    final newNote = Map<String, dynamic>.from(original)
      ..['uuid'] = '00000000-0000-4000-8000-000000000004'
      ..['comment'] = 'Would be new';
    decoded['records'] = [newNote, original];

    final imported = await database.importContentFromJson(
      DatabaseContent.notes,
      jsonEncode(decoded),
      onConflict: (_) async => ImportConflictResolution.cancelImport,
    );

    expect(imported, isNull);
    expect(
      (await database.select(database.notes).get()).map((note) => note.comment),
      ['Original'],
    );
  });

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
          of: find.byType(DatabaseContentPage),
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
      link: 'https://example.com\tgeo:48.8584,2.2945',
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
    final noteExport =
        jsonDecode(exports[DatabaseContent.notes]!) as Map<String, dynamic>;
    final exportedNote = (noteExport['records'] as List<dynamic>).single as Map;
    final exportedTransaction =
        (transactionExport['records'] as List<dynamic>).single as Map;
    expect(noteExport['formatVersion'], 2);
    expect(exportedNote['link'], ['https://example.com', 'geo:48.8584,2.2945']);
    expect(exportedNote['tags'], ['trip', 'important']);
    expect(transactionExport['currencies'], hasLength(1));
    expect(exportedTransaction['link'], ['https://example.com/receipt']);
    expect(exportedTransaction['tags'], ['food', 'calendar', 'planned']);
    for (final content in DatabaseContent.values) {
      await database.clearContent(content);
    }
    for (final content in exportContents) {
      await database.importContentFromJson(
        content,
        exports[content]!,
        onConflict: _skipConflicts,
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
    expect(notes.single.tags, 'trip\timportant');
    expect(notes.single.linkList, [
      'https://example.com',
      'geo:48.8584,2.2945',
    ]);

    final transactions = await database
        .select(database.moneyTransactions)
        .get();
    expect(transactions.single.amount, 12.5);
    expect(
      [
        transactions.single.date.year,
        transactions.single.date.month,
        transactions.single.date.day,
        transactions.single.date.hour,
        transactions.single.date.minute,
      ],
      [
        transactionDate.year,
        transactionDate.month,
        transactionDate.day,
        transactionDate.hour,
        transactionDate.minute,
      ],
    );
    expect(transactions.single.tagList, contains('calendar'));
    expect(transactions.single.isPlanned, isTrue);
  });

  test('transaction date preserves local calendar and time fields', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final date = DateTime(2025, 3, 14, 15, 30);
    await database.addTransaction(
      kind: TransactionKind.expense,
      amount: 12.5,
      currency: 'EUR',
      date: date,
    );

    var stored =
        (await database.select(database.moneyTransactions).get()).single;
    expect(stored.date.isUtc, isTrue);
    expect(
      [
        stored.date.year,
        stored.date.month,
        stored.date.day,
        stored.date.hour,
        stored.date.minute,
      ],
      [2025, 3, 14, 15, 30],
    );

    final exported = await database.exportContentAsJson(
      DatabaseContent.transactions,
    );
    final exportJson = jsonDecode(exported) as Map<String, dynamic>;
    final exportedRecords = exportJson['records'] as List<dynamic>;
    final exportedRecord = Map<String, dynamic>.from(
      exportedRecords.single as Map,
    );
    expect(exportedRecord['date'], '14.03.2025 15:30');
    await database.clearContent(DatabaseContent.transactions);
    await database.importContentFromJson(
      DatabaseContent.transactions,
      exported,
      onConflict: _skipConflicts,
    );
    stored = (await database.select(database.moneyTransactions).get()).single;
    expect(
      [
        stored.date.year,
        stored.date.month,
        stored.date.day,
        stored.date.hour,
        stored.date.minute,
      ],
      [2025, 3, 14, 15, 30],
    );

    exportedRecord['date'] = '2025-03-14T15:30:00.000+01:00';
    exportJson['records'] = [exportedRecord];
    await database.clearContent(DatabaseContent.transactions);
    await database.importContentFromJson(
      DatabaseContent.transactions,
      jsonEncode(exportJson),
      onConflict: _skipConflicts,
    );
    stored = (await database.select(database.moneyTransactions).get()).single;
    expect(
      [
        stored.date.year,
        stored.date.month,
        stored.date.day,
        stored.date.hour,
        stored.date.minute,
      ],
      [2025, 3, 14, 15, 30],
    );
  });

  test('importing an identical UUID and timestamp skips the item', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addNote(comment: 'Existing note');
    final exportedNote = await database.exportContentAsJson(
      DatabaseContent.notes,
    );

    final summary = await database.importContentFromJson(
      DatabaseContent.notes,
      exportedNote,
      onConflict: _skipConflicts,
    );

    final notes = await database.select(database.notes).get();
    expect(notes.map((note) => note.comment), everyElement('Existing note'));
    expect(notes, hasLength(1));
    expect(summary?.added, 0);
    expect(summary?.skipped, 1);
    expect(summary?.updated, 0);
  });

  test('import summary counts new and unchanged rows', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addNote(comment: 'Existing');
    final exported = jsonDecode(
      await database.exportContentAsJson(DatabaseContent.notes),
    ) as Map<String, dynamic>;
    final existing = Map<String, dynamic>.from(
      (exported['records'] as List<dynamic>).single as Map,
    );
    final added = Map<String, dynamic>.from(existing)
      ..['uuid'] = '00000000-0000-4000-8000-000000000005'
      ..['comment'] = 'New';
    exported['records'] = [existing, added];

    final summary = await database.importContentFromJson(
      DatabaseContent.notes,
      jsonEncode(exported),
      onConflict: _skipConflicts,
    );

    expect(summary?.added, 1);
    expect(summary?.skipped, 1);
    expect(summary?.updated, 0);
  });

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
      ..['uuid'] = '00000000-0000-4000-8000-000000000001'
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
      ..['uuid'] = '00000000-0000-4000-8000-000000000002'
      ..['comment'] = 'Another note';
    notesExport['records'] = [duplicateNote, duplicateNote, newNote];

    await database.importContentFromJson(
      DatabaseContent.checklist,
      jsonEncode(checklistExport),
      onConflict: _skipConflicts,
    );
    await database.importContentFromJson(
      DatabaseContent.notes,
      jsonEncode(notesExport),
      onConflict: _skipConflicts,
    );

    final todoItems = await database.select(database.todoItems).get();
    expect(todoItems.map((item) => item.name), ['Passport', 'Boarding pass']);
    final notes = await database.select(database.notes).get();
    expect(notes.map((note) => note.comment), ['Travel note', 'Another note']);
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
      ..['uuid'] = '00000000-0000-4000-8000-000000000003'
      ..['comment'] = 'Dinner';
    exported['records'] = [duplicate, duplicate, newTransaction];

    await database.importContentFromJson(
      DatabaseContent.transactions,
      jsonEncode(exported),
      onConflict: _skipConflicts,
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
    'identical transaction import skips the item and keeps its currencies',
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
        onConflict: _skipConflicts,
      );

      expect(await database.select(database.currencies).get(), hasLength(1));
      expect(
        await database.select(database.moneyTransactions).get(),
        hasLength(1),
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
      onConflict: _skipConflicts,
    );

    final transactions = await database
        .select(database.moneyTransactions)
        .get();
    expect(transactions.map((transaction) => transaction.isPlanned), [
      false,
      false,
      false,
    ]);
    expect(transactions.map((transaction) => transaction.storedTagList), [
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
      onConflict: _skipConflicts,
    );

    final transaction =
        (await database.select(database.moneyTransactions).get()).single;
    expect(transaction.isPlanned, isFalse);
    expect(transaction.storedTagList, ['food']);
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
      onConflict: _skipConflicts,
    );

    final transaction =
        (await database.select(database.moneyTransactions).get()).single;
    expect(transaction.isPlanned, isFalse);
    expect(transaction.storedTagList, ['food']);
  });

  test('rejects version 1 JSON without deleting existing records', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.addNote(comment: 'Keep this note');

    await expectLater(
      database.importContentFromJson(
        DatabaseContent.notes,
        '{"formatVersion":1,"content":"notes","records":[]}',
        onConflict: _skipConflicts,
      ),
      throwsFormatException,
    );

    final notes = await database.select(database.notes).get();
    expect(notes.single.comment, 'Keep this note');
  });
}
