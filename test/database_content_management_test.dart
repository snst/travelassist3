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
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage database content'));
    await tester.pumpAndSettle();
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
      expect(find.byTooltip('Import $label (coming soon)'), findsOneWidget);
      expect(find.byTooltip('Export $label (coming soon)'), findsOneWidget);
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
}
