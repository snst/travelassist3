import 'dart:ffi';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/screens/todo_list_page.dart';

void main() {
  late AppDatabase database;

  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () {
      return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
    });
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('Seed todo items and retrieve categories', () async {
    await database.seedInitialTodoItemsIfEmpty();

    final categories = await database.getAllCategories();
    expect(categories, containsAll(['Documents', 'Electronics', 'Toiletries', 'Clothing']));

    final openItems = await database.watchTodoItemsByState(0).first;
    expect(openItems.length, 8);
    expect(openItems.any((i) => i.name == 'Passport'), isTrue);
  });

  test('Add, update state, and delete todo item', () async {
    final id = await database.addTodoItem(
      name: 'Sunglasses',
      category: 'Accessories',
      quantity: 1,
    );

    var items = await database.watchTodoItemsByState(0).first;
    expect(items.any((i) => i.id == id && i.name == 'Sunglasses'), isTrue);

    // Mark as done (state = 2)
    await database.setTodoItemState(id, 2);

    var openItems = await database.watchTodoItemsByState(0).first;
    var doneItems = await database.watchTodoItemsByState(2).first;

    expect(openItems.any((i) => i.id == id), isFalse);
    expect(doneItems.any((i) => i.id == id), isTrue);

    // Delete item
    await database.deleteTodoItem(id);
    var remainingDone = await database.watchTodoItemsByState(2).first;
    expect(remainingDone.any((i) => i.id == id), isFalse);
  });

  testWidgets('Renders TodoListPage and toggles filter', (WidgetTester tester) async {
    await database.seedInitialTodoItemsIfEmpty();

    await tester.pumpWidget(
      MaterialApp(
        home: TodoListPage(database: database),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Travel Checklist'), findsOneWidget);
    expect(find.text('Passport'), findsOneWidget);
    expect(find.textContaining('Packing Progress'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);

    // Switch to 'Done' tab
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('No completed items yet.'), findsOneWidget);

    // Unmount widget tree to close active streams cleanly before database tearDown
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
