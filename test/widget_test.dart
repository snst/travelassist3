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
    expect(find.text('Currencies'), findsOneWidget);

    await tester.tap(find.text('Currencies'));
    await tester.pumpAndSettle();

    expect(find.text('Add Currency'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calculator'));
    await tester.pumpAndSettle();

    expect(find.text('Currency Calculator'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });
}
