import 'dart:ffi';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/screens/expense_page.dart';
import 'package:travelassist3/widgets/link_editor.dart';

void main() {
  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () {
      return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
    });
  });

  testWidgets('Uses a simulated GPS location on Linux desktop', (tester) async {
    final controller = LinkListController();
    addTearDown(controller.dispose);

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LinkEditor(controller: controller)),
        ),
      );

      await tester.tap(find.text('GPS'));
      await tester.pumpAndSettle();

      expect(controller.joined, 'geo:0,0');
      expect(
        find.text('Added simulated GPS location for Linux desktop (0, 0).'),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Captures the Linux GPS stub after opening Add Expense', (
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

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        MaterialApp(home: ExpensePage(database: database)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('geo:0,0'), findsOneWidget);
      expect(
        find.text('Added simulated GPS location for Linux desktop (0, 0).'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
