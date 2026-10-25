import 'dart:ffi';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/screens/expense_page.dart';
import 'package:travelassist3/screens/expenses_list_page.dart';
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
    testWidgets('Saving an expense opens the expenses list: new=$isNew', (
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
          kind: TransactionKind.expense,
          amount: 12,
          currency: 'EUR',
          comment: 'Original expense',
        );
        transaction = await (database.select(
          database.moneyTransactions,
        )..where((row) => row.id.equals(id))).getSingle();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensePage(
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
          '24';
      tester.widget<CommentInput>(find.byType(CommentInput)).controller.text =
          'Saved expense';
      await tester.tap(
        find.byTooltip(isNew ? 'Save Expense' : 'Update Expense'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ExpensesListPage), findsOneWidget);
      expect(find.byType(ExpensePage), findsNothing);
      expect(find.text('Saved expense'), findsOneWidget);
      final entries = await database.select(database.moneyTransactions).get();
      expect(entries, hasLength(1));
      expect(entries.single.amount, 24);
      if (transaction != null) expect(entries.single.id, transaction.id);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Expense header previews unsaved info: new=$isNew', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
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
            kind: TransactionKind.expense,
            amount: 12,
            currency: 'EUR',
            comment: 'Original expense info',
            link: 'https://example.com/original',
          );
          transaction = await (database.select(
            database.moneyTransactions,
          )..where((row) => row.id.equals(id))).getSingle();
        }

        await tester.pumpWidget(
          MaterialApp(
            home: ExpensePage(
              database: database,
              transaction: transaction,
              openExpensesListOnSave: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        tester.widget<CommentInput>(find.byType(CommentInput)).controller.text =
            'Updated expense info';
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
          matching: find.text('Updated expense info'),
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
          tester
              .widget<CommentInput>(find.byType(CommentInput))
              .controller
              .text,
          'Updated expense info',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('Saving an expense returns to the page that opened it', (
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
                  builder: (_) => ExpensePage(database: database),
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
        '24';
    await tester.tap(find.byTooltip('Save Expense'));
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.byType(ExpensePage), findsNothing);
    expect(find.byType(ExpensesListPage), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
