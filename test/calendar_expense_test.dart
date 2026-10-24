import 'dart:ffi';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:travelassist3/database/database.dart';

void main() {
  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () {
      return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
    });
  });

  test('Calendar tag defaults off and persists when enabled', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      final hiddenId = await database.addTransaction(
        kind: TransactionKind.expense,
        amount: 5,
        currency: 'EUR',
      );
      final visibleId = await database.addTransaction(
        kind: TransactionKind.expense,
        amount: 12,
        currency: 'EUR',
        tags: const ['calendar'],
      );

      final transactions = await database
          .select(database.moneyTransactions)
          .get();
      expect(
        transactions
            .singleWhere((transaction) => transaction.id == hiddenId)
            .tagList
            .contains('calendar'),
        isFalse,
      );
      expect(
        transactions
            .singleWhere((transaction) => transaction.id == visibleId)
            .tagList
            .contains('calendar'),
        isTrue,
      );
    } finally {
      await database.close();
    }
  });

}
