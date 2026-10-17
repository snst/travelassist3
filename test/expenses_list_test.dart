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
      tags: ['food', 'lunch'],
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
    final tags = subtitle.children.first as Text;
    expect(tags.data, 'food lunch');
    expect(tags.style, title.style);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Shows tags on the first line when info is empty', (
    tester,
  ) async {
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

    expect(title.data, 'food lunch');
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(tile.subtitle, isNotNull);
    expect(
      (tile.subtitle! as Column).children.whereType<Text>().map(
        (text) => text.data,
      ),
      isNot(contains('food lunch')),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
