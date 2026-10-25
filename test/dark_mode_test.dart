import 'dart:ffi' hide Size;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/main.dart';

void main() {
  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () {
      return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
    });
  });

  testWidgets('app starts with dark mode saved', (tester) async {
    SharedPreferences.setMockInitialValues({'darkModeEnabled': true});
    await tester.pumpWidget(
      MyApp(
        databaseFactory: (_) => AppDatabase.forTesting(NativeDatabase.memory()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Travel Assist'), findsWidgets);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'Reise');
  });

  testWidgets('switching dark mode in settings does not crash', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MyApp(
        databaseFactory: (_) => AppDatabase.forTesting(NativeDatabase.memory()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      Theme.of(tester.element(find.text('Travel Assist').first)).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      Theme.of(tester.element(find.text('Travel Assist').first)).brightness,
      Brightness.light,
    );
  });

  testWidgets('can create and switch databases from database content', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final openedDatabaseNames = <String>[];
    final deletedDatabaseNames = <String>[];
    await tester.pumpWidget(
      MyApp(
        databaseFactory: (name) {
          openedDatabaseNames.add(name);
          return AppDatabase.forTesting(NativeDatabase.memory());
        },
        databaseDeleter: (name) async {
          deletedDatabaseNames.add(name);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Database'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cannot delete the last database'), findsOneWidget);
    await tester.tap(find.text('Add database'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Japan trip');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not update database'),
      findsNothing,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .join(' | '),
    );
    expect(find.text('Japan trip'), findsOneWidget);

    var preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('activeDatabaseId'), 'japan_trip');
    expect(preferences.getString('databaseProfiles'), contains('Japan trip'));
    expect(openedDatabaseNames, ['travel_assist_db', 'japan_trip']);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Database'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete Japan trip'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('permanently delete "Japan trip"'),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('activeDatabaseId'), 'travel_assist_db');
    expect(
      preferences.getString('databaseProfiles'),
      isNot(contains('Japan trip')),
    );
    expect(deletedDatabaseNames, ['japan_trip']);
    expect(openedDatabaseNames, [
      'travel_assist_db',
      'japan_trip',
      'travel_assist_db',
    ]);
    expect(find.text('Travel Assist'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home page lays out with a zero-size first frame', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'darkModeEnabled': true});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size.zero;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MyApp(
        databaseFactory: (_) => AppDatabase.forTesting(NativeDatabase.memory()),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
