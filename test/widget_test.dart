import 'dart:ffi';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/main.dart';

void main() {
  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () {
      return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
    });
  });

  testWidgets('App renders home page and opens Currency Settings from popup menu',
      (WidgetTester tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.seedInitialCurrenciesIfEmpty();

    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(title: 'Travel Assist', database: database),
      ),
    );
    await tester.pumpAndSettle();

    // Verify main app bar title and home currency card
    expect(find.text('Travel Assist'), findsOneWidget);
    expect(find.text('Home Currency'), findsOneWidget);

    // Open popup menu
    final menuButton = find.byIcon(Icons.more_vert);
    expect(menuButton, findsOneWidget);
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // Tap 'Currency Settings' menu item
    final currencySettingsOption = find.text('Currency Settings');
    expect(currencySettingsOption, findsOneWidget);
    await tester.tap(currencySettingsOption);
    await tester.pumpAndSettle();

    // Verify Currency Settings screen loaded
    expect(find.text('Currency Settings'), findsWidgets);
    expect(find.text('Add Currency'), findsOneWidget);

    await database.close();
  });
}
