import 'dart:ffi';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:travelassist3/database/database.dart';
import 'package:travelassist3/screens/note_item_page.dart';
import 'package:travelassist3/screens/note_list_page.dart';
import 'package:travelassist3/widgets/link_editor.dart';

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

    testWidgets('Note list info button opens the large text dialog', (
      WidgetTester tester,
    ) async {
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
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.textContaining('https://example.com/trip'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Open Link'), findsOneWidget);
      expect(find.text('example.com/trip'), findsOneWidget);
      expect(find.text('https://example.com/trip'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Note list removes https from links below a smaller comment', (
      WidgetTester tester,
    ) async {
      const comment = 'Paris trip info';
      const links = [
        'https://example.com/trip',
        'https://example.com/hotel',
        'geo:48.8566,2.3522',
      ];
      await database.addNote(comment: comment, link: links.join('\t'));

      const secondaryColor = Colors.purple;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.light(secondary: secondaryColor),
          ),
          home: NoteListPage(database: database),
        ),
      );
      await tester.pumpAndSettle();

      final commentWidget = tester.widget<Text>(find.text(comment));
      expect(commentWidget.style?.fontSize, lessThan(16));
      for (final link in links) {
        final displayedLink = link.startsWith('https://')
            ? link.substring('https://'.length)
            : link;
        final linkWidget = tester.widget<Text>(find.text(displayedLink));
        expect(linkWidget.style?.color, secondaryColor);
        expect(linkWidget.maxLines, 1);
        expect(linkWidget.overflow, TextOverflow.ellipsis);
        expect(linkWidget.textDirection, TextDirection.rtl);
      }

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

    testWidgets(
      'NoteItemPage displays list of links and shows confirmation dialog when deleting link',
      (WidgetTester tester) async {
        final noteId = await database.addNote(
          comment: 'Test Note',
          link: 'https://link1.com\thttps://link2.com',
        );

        final notes = await database.select(database.notes).get();
        final note = notes.firstWhere((n) => n.id == noteId);

        await tester.pumpWidget(
          MaterialApp(
            home: NoteItemPage(database: database, note: note),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('https://link1.com'), findsOneWidget);
        expect(find.text('https://link2.com'), findsOneWidget);

        final firstLinkActions = find.byTooltip('Actions for Link 1');
        expect(firstLinkActions, findsOneWidget);
        expect(find.byTooltip('Open Link'), findsWidgets);
        expect(find.byTooltip('Actions for Link 2'), findsOneWidget);

        await tester.tap(firstLinkActions);
        await tester.pumpAndSettle();
        expect(find.text('Open Link'), findsNothing);
        expect(find.text('Copy Link'), findsOneWidget);
        expect(find.text('Remove Link'), findsOneWidget);
        await tester.tap(find.text('Remove Link'));
        await tester.pumpAndSettle();

        // Check confirmation dialog appears
        expect(find.text('Delete Link'), findsOneWidget);
        expect(
          find.textContaining('https://link1.com'),
          findsNWidgets(2),
        ); // in textfield and dialog content

        // Tap Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Link still exists
        expect(find.text('https://link1.com'), findsOneWidget);

        // Remove the first link again and confirm
        await tester.tap(firstLinkActions);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove Link'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // First link is removed
        expect(find.text('https://link1.com'), findsNothing);
        expect(find.text('https://link2.com'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets('paste, new and GPS buttons remain available', (
      WidgetTester tester,
    ) async {
      final controller = LinkListController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LinkEditor(controller: controller)),
        ),
      );

      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('GPS'), findsOneWidget);

      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      expect(controller.fields, hasLength(2));

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('tag suggestions reopen after selecting a tag', (
      WidgetTester tester,
    ) async {
      await database.addNote(comment: 'Known tags', tags: ['flight', 'hotel']);

      await tester.pumpWidget(
        MaterialApp(home: NoteItemPage(database: database)),
      );
      await tester.pumpAndSettle();

      final tagField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Add tag',
      );

      await tester.tap(tagField);
      await tester.pumpAndSettle();
      expect(find.text('hotel'), findsOneWidget);

      await tester.tap(find.text('hotel'));
      await tester.pumpAndSettle();
      expect(find.text('hotel'), findsOneWidget);
      expect(tester.widget<TextField>(tagField).controller!.text, isEmpty);

      await tester.tap(tagField);
      await tester.pumpAndSettle();
      expect(find.text('flight'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
