import 'dart:ffi' hide Size;

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
      testWidgets('Home fits $size at text scale $scale without scrolling', (
        tester,
      ) async {
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
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable),
        );
        expect(scrollable.position.maxScrollExtent, 0);
        final addHeading = tester.getRect(find.text('Add'));
        final viewHeading = tester.getRect(find.text('View'));
        expect(
          tester.getRect(find.text('Calculator')).bottom,
          lessThan(addHeading.top),
        );
        for (final label in [
          'Add Expense',
          'Add Hotel',
          'Add Note',
          'Add pos',
        ]) {
          final bounds = tester.getRect(find.text(label));
          expect(bounds.top, greaterThan(addHeading.bottom));
          expect(bounds.bottom, lessThan(viewHeading.top));
        }
        for (final label in [
          'Expenses',
          'Balance',
          'Hotels',
          'Checklist',
          'Notes',
        ]) {
          expect(
            tester.getRect(find.text(label)).top,
            greaterThan(viewHeading.bottom),
          );
        }
        for (final label in [
          'Calculator',
          'Expenses',
          'Balance',
          'Add Hotel',
          'Hotels',
          'Checklist',
          'Notes',
          'Add Note',
          'Add pos',
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

  testWidgets('Home dashboard opens features and navigates back', (
    WidgetTester tester,
  ) async {
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
    await tester.pump(const Duration(seconds: 1));
    await database.close();
  });

  testWidgets('Add pos opens a focused note pre-tagged as pos', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(title: 'Travel Assist', database: database),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add pos'));
    await tester.pumpAndSettle();

    expect(find.text('Add Note'), findsOneWidget);
    expect(find.text('#pos'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home settings closes before changing the app theme', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    var darkModeEnabled = false;
    final changes = <bool>[];

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setAppState) => MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
          home: HomePage(
            title: 'Travel Assist',
            database: database,
            darkModeEnabled: darkModeEnabled,
            onDarkModeChanged: (enabled) async {
              expect(find.byType(AlertDialog), findsNothing);
              changes.add(enabled);
              setAppState(() => darkModeEnabled = enabled);
            },
          ),
        ),
      ),
    );

    for (final enabled in [true, false]) {
      await tester.tap(find.byTooltip('Cash tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Dark mode'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        !enabled,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(darkModeEnabled, enabled);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        Theme.of(tester.element(find.byType(HomePage))).brightness,
        enabled ? Brightness.dark : Brightness.light,
      );
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.byTooltip('Cash tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(changes, [true, false]);
    expect(darkModeEnabled, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
