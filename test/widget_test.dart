import 'dart:ffi';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/screens/cash_count_page.dart';
import 'package:travelassist3/screens/currency_settings_screen.dart';
import 'package:travelassist3/screens/deposit_page.dart';
import 'package:travelassist3/screens/home_page.dart';
import 'package:travelassist3/screens/withdrawal_page.dart';

void main() {
  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () {
      return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
    });
  });

  for (final size in [const Size(393, 820), const Size(412, 915)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Home fits $size at text scale $scale without scrolling',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 24, bottom: 24),
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: HomePage(title: 'Travel Assist', database: database),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final scrollable =
            tester.state<ScrollableState>(find.byType(Scrollable));
        expect(scrollable.position.maxScrollExtent, 0);
        final addHeading = tester.getRect(find.text('Add'));
        final viewHeading = tester.getRect(find.text('View'));
        expect(
          tester.getRect(find.text('Calculator')).bottom,
          lessThan(addHeading.top),
        );
        for (final label in ['Expense', 'Hotel', 'Add Note']) {
          final bounds = tester.getRect(find.text(label));
          expect(bounds.top, greaterThan(addHeading.bottom));
          expect(bounds.bottom, lessThan(viewHeading.top));
        }
        for (final label in ['Entries', 'Balance', 'Hotels', 'Checklist', 'Notes']) {
          expect(
            tester.getRect(find.text(label)).top,
            greaterThan(viewHeading.bottom),
          );
        }
        for (final label in [
          'Calculator', 'Expense', 'Entries', 'Balance',
          'Hotel', 'Hotels', 'Checklist', 'Notes', 'Add Note',
        ]) {
          final shortcut = find.ancestor(
            of: find.text(label),
            matching: find.byType(InkWell),
          );
          expect(shortcut, findsOneWidget);
          final bounds = tester.getRect(shortcut);
          expect(bounds.bottom, lessThanOrEqualTo(size.height - 24));
          expect(bounds.height, greaterThanOrEqualTo(48));
          expect(shortcut.hitTestable(), findsOneWidget);
        }
        expect(find.text('Cash'), findsNothing);
        expect(find.byTooltip('Cash tools').hitTestable(), findsOneWidget);
        for (final label in ['ATM', 'Deposit', 'Count Cash', 'Currencies']) {
          expect(find.text(label), findsNothing);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('Home dashboard opens features and navigates back',
      (WidgetTester tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.seedInitialCurrenciesIfEmpty();

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(title: 'Travel Assist', database: database),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calculator'), findsOneWidget);

    for (final entry in <String, Type>{
      'ATM': WithdrawalPage,
      'Deposit': DepositPage,
      'Count Cash': CashCountPage,
      'Currencies': CurrencySettingsScreen,
    }.entries) {
      await tester.tap(find.byTooltip('Cash tools'));
      await tester.pumpAndSettle();

      for (final label in ['ATM', 'Deposit', 'Count Cash', 'Currencies']) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }

      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();

      expect(find.byType(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Calculator'));
    await tester.pumpAndSettle();

    expect(find.text('Currency Calculator'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });
}
