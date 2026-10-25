import 'dart:ffi';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/screens/expenses_list_page.dart';
import 'package:travelassist3/screens/hotel_page.dart';
import 'package:travelassist3/widgets/comment_input.dart';
import 'package:travelassist3/widgets/link_editor.dart';
import 'package:travelassist3/widgets/payment_currency_amount_input.dart';

void main() {
  setUpAll(() {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0'),
    );
  });

  for (final isNew in [true, false]) {
    testWidgets('Saving a hotel opens the expenses list: new=$isNew', (
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
      MoneyTransaction? transaction;
      if (!isNew) {
        final id = await database.addTransaction(
          kind: TransactionKind.hotel,
          amount: 100,
          currency: 'EUR',
          comment: 'Original hotel',
        );
        transaction = await (database.select(
          database.moneyTransactions,
        )..where((row) => row.id.equals(id))).getSingle();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: HotelPage(
            database: database,
            transaction: transaction,
            openExpensesListOnSave: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
              .widget<PaymentCurrencyAmountInput>(
                find.byType(PaymentCurrencyAmountInput),
              )
              .amountController
              .text =
          '240';
      tester.widget<CommentInput>(find.byType(CommentInput)).controller.text =
          'Saved hotel';
      await tester.tap(find.byTooltip(isNew ? 'Save Hotel' : 'Update Hotel'));
      await tester.pumpAndSettle();

      expect(find.byType(ExpensesListPage), findsOneWidget);
      expect(find.byType(HotelPage), findsNothing);
      expect(find.text('Saved hotel'), findsOneWidget);
      final entries = await database.select(database.moneyTransactions).get();
      expect(entries, hasLength(1));
      expect(entries.single.amount, 240);
      expect(entries.single.type, TransactionKind.hotel);
      if (transaction != null) expect(entries.single.id, transaction.id);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Hotel header previews unsaved info: new=$isNew', (
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
      MoneyTransaction? transaction;
      if (!isNew) {
        final id = await database.addTransaction(
          kind: TransactionKind.hotel,
          amount: 100,
          currency: 'EUR',
          comment: 'Original hotel info',
          link: 'https://example.com/original',
        );
        transaction = await (database.select(
          database.moneyTransactions,
        )..where((row) => row.id.equals(id))).getSingle();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: HotelPage(
            database: database,
            transaction: transaction,
            openExpensesListOnSave: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester.widget<CommentInput>(find.byType(CommentInput)).controller.text =
          'Updated hotel info';
      final links = tester.widget<LinkEditor>(find.byType(LinkEditor));
      links.controller.fields.first.text = ' https://example.com/updated ';
      links.controller.add(' ');
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip('View Info'),
        ),
      );
      await tester.pumpAndSettle();

      final dialog = find.byType(Dialog);
      final info = find.descendant(
        of: dialog,
        matching: find.text('Updated hotel info'),
      );
      expect(dialog, findsOneWidget);
      expect(info, findsOneWidget);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('https://example.com/updated'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.byTooltip('Open Link')),
        findsOneWidget,
      );

      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(
        tester.widget<CommentInput>(find.byType(CommentInput)).controller.text,
        'Updated hotel info',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('Saving a hotel returns to the page that opened it', (
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

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HotelPage(database: database),
                ),
              ),
              child: const Text('Calendar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    tester
            .widget<PaymentCurrencyAmountInput>(
              find.byType(PaymentCurrencyAmountInput),
            )
            .amountController
            .text =
        '240';
    await tester.tap(find.byTooltip('Save Hotel'));
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.byType(HotelPage), findsNothing);
    expect(find.byType(ExpensesListPage), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
