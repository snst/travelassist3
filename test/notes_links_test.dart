import 'dart:ffi';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/screens/note_item_page.dart';
import 'package:travelassist3/screens/note_list_page.dart';

void main() {
  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () {
      return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
    });
  });

  group('Multiple Links in Notes', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    testWidgets('Note list info button opens the large text dialog',
        (WidgetTester tester) async {
      await database.addNote(
        comment: 'Paris trip info',
        link: 'https://example.com/trip',
      );

      await tester.pumpWidget(
        MaterialApp(home: NoteListPage(database: database)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('View Info'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Paris trip info'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('https://example.com/trip'), findsNothing);
      expect(find.byType(Dialog), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    test('Note.link stores multiple tab-separated links and NoteHelpers parses them correctly', () async {
      const link1 = 'https://maps.google.com/?q=Hotel';
      const link2 = 'https://airline.com/booking/123';
      const link3 = 'geo:48.8566,2.3522';

      final joinedLinks = '$link1\t$link2\t$link3';

      final id = await database.addNote(
        comment: 'Paris trip links',
        link: joinedLinks,
        tags: ['paris', 'hotel'],
      );

      final notes = await database.select(database.notes).get();
      final note = notes.firstWhere((n) => n.id == id);

      expect(note.link, equals(joinedLinks));
      expect(note.linkList, equals([link1, link2, link3]));
      expect(note.isLink, isTrue);
      expect(note.isGeo, isTrue);
      expect(note.linksSummary(), contains('3 links:'));
    });

    testWidgets('NoteItemPage displays list of links and shows confirmation dialog when deleting link', (WidgetTester tester) async {
      final noteId = await database.addNote(
        comment: 'Test Note',
        link: 'https://link1.com\thttps://link2.com',
      );

      final notes = await database.select(database.notes).get();
      final note = notes.firstWhere((n) => n.id == noteId);

      await tester.pumpWidget(
        MaterialApp(
          home: NoteItemPage(
            database: database,
            note: note,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('https://link1.com'), findsOneWidget);
      expect(find.text('https://link2.com'), findsOneWidget);

      // Tap delete on the first link
      final deleteButtons = find.byIcon(Icons.delete_outline);
      expect(deleteButtons, findsNWidgets(2));

      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      // Check confirmation dialog appears
      expect(find.text('Delete Link'), findsOneWidget);
      expect(find.textContaining('https://link1.com'), findsNWidgets(2)); // in textfield and dialog content

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Link still exists
      expect(find.text('https://link1.com'), findsOneWidget);

      // Tap delete on first link again and confirm
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // First link is removed
      expect(find.text('https://link1.com'), findsNothing);
      expect(find.text('https://link2.com'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('tag suggestions reopen after selecting a tag', (WidgetTester tester) async {
      await database.addNote(
        comment: 'Known tags',
        tags: ['flight', 'hotel'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NoteItemPage(database: database),
        ),
      );
      await tester.pumpAndSettle();

      final tagField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Add tag',
      );

      await tester.tap(tagField);
      await tester.pumpAndSettle();
      expect(find.text('hotel'), findsOneWidget);

      await tester.tap(find.text('hotel'));
      await tester.pumpAndSettle();
      expect(find.text('#hotel'), findsOneWidget);
      expect(tester.widget<TextField>(tagField).controller!.text, isEmpty);

      await tester.tap(tagField);
      await tester.pumpAndSettle();
      expect(find.text('flight'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
