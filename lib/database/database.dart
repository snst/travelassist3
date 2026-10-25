import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'database_file_deleter_stub.dart'
    if (dart.library.io) 'database_file_deleter_io.dart'
    as file_deleter;
import '../utils/date_format.dart';
part 'database.g.dart';

const defaultDatabaseName = 'travel_assist_db';
const databaseListSeparator = '\t';
const _jsonExportFormatVersion = 2;
final _secureRandom = Random.secure();

String _newUuid() {
  final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

bool _sameStoredTimestamp(DateTime first, DateTime second) =>
    first.millisecondsSinceEpoch == second.millisecondsSinceEpoch;

int _nowAsMilliseconds() => DateTime.now().millisecondsSinceEpoch;

int _nowAsTimezoneIndependentSeconds() {
  final now = DateTime.now();
  return DateTime.utc(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
      ).millisecondsSinceEpoch ~/
      1000;
}

class _DateTimeMillisecondsConverter extends TypeConverter<DateTime, int> {
  const _DateTimeMillisecondsConverter();

  @override
  DateTime fromSql(int fromDb) => DateTime.fromMillisecondsSinceEpoch(fromDb);

  @override
  int toSql(DateTime value) => value.millisecondsSinceEpoch;
}

class _TimezoneIndependentDateTimeConverter
    extends TypeConverter<DateTime, int> {
  const _TimezoneIndependentDateTimeConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb * 1000, isUtc: true);

  @override
  int toSql(DateTime value) =>
      DateTime.utc(
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
        value.second,
      ).millisecondsSinceEpoch ~/
      1000;
}

class DatabaseProfile {
  final String id;
  final String name;

  const DatabaseProfile({required this.id, required this.name});
}

enum ImportConflictResolution {
  skip,
  overwrite,
  skipAll,
  overwriteAll,
  cancelImport,
}

class ImportConflict {
  final DatabaseContent content;
  final String uuid;
  final String? comment;
  final String? existingComment;
  final DateTime existingLastModified;
  final DateTime incomingLastModified;

  const ImportConflict({
    required this.content,
    required this.uuid,
    this.comment,
    this.existingComment,
    required this.existingLastModified,
    required this.incomingLastModified,
  });
}

class ImportSummary {
  final int added;
  final int skipped;
  final int updated;

  const ImportSummary({
    required this.added,
    required this.skipped,
    required this.updated,
  });
}

typedef ImportConflictResolver = Future<ImportConflictResolution> Function(
  ImportConflict conflict,
);

class _ImportConflictState {
  ImportConflictResolution? applyToAll;
  int added = 0;
  int skipped = 0;
  int updated = 0;
}

class Currencies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(_newUuid)();
  IntColumn get lastModified => integer()
      .map(const _DateTimeMillisecondsConverter())
      .clientDefault(_nowAsMilliseconds)();
  TextColumn get name => text()();
  TextColumn get shortName => text()();
  RealColumn get rate => real()();
  BoolColumn get isHome => boolean().withDefault(const Constant(false))();
}

class TodoItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(_newUuid)();
  IntColumn get lastModified => integer()
      .map(const _DateTimeMillisecondsConverter())
      .clientDefault(_nowAsMilliseconds)();
  TextColumn get name => text()();
  TextColumn get category => text().withDefault(const Constant('General'))();
  TextColumn get comment => text().withDefault(const Constant(''))();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get used => integer().withDefault(const Constant(0))();
  IntColumn get state => integer().withDefault(
    const Constant(0),
  )(); // 0: open, 1: skipped, 2: done
}

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(_newUuid)();
  IntColumn get lastModified => integer()
      .map(const _DateTimeMillisecondsConverter())
      .clientDefault(_nowAsMilliseconds)();
  TextColumn get comment => text().withDefault(const Constant(''))();
  TextColumn get link => text().withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant(''))();
}

@DataClassName('MoneyTransaction')
class MoneyTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(_newUuid)();
  IntColumn get lastModified => integer()
      .map(const _DateTimeMillisecondsConverter())
      .clientDefault(_nowAsMilliseconds)();
  IntColumn get kind =>
      integer().withDefault(const Constant(0))(); // TransactionKind.index
  RealColumn get amount => real()();
  TextColumn get currency => text()(); // Currency.shortName
  TextColumn get method =>
      text().withDefault(const Constant(''))(); // empty or 'cash' means cash
  TextColumn get comment => text().withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant(''))();
  IntColumn get date => integer()
      .map(const _TimezoneIndependentDateTimeConverter())
      .clientDefault(_nowAsTimezoneIndependentSeconds)();
  // Number of days the entry covers: for expenses the days it counts in the daily average
  // (0 = not included, 1 = default), for e.g. a hotel booking its length.
  IntColumn get days => integer().withDefault(const Constant(1))();
  TextColumn get link => text().withDefault(
    const Constant(''),
  )(); // tab separated, like Notes.link
}

@DriftDatabase(tables: [Currencies, TodoItems, Notes, MoneyTransactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase({String name = defaultDatabaseName})
    : super(_openConnection(name));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 18;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
    );
  }

  static QueryExecutor _openConnection(String name) {
    _validateDatabaseName(name);
    return driftDatabase(name: name);
  }

  static Future<void> deleteDatabaseFile(String name) async {
    _validateDatabaseName(name);
    await file_deleter.deleteDatabaseFile(name);
  }

  static void _validateDatabaseName(String name) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'Invalid database name');
    }
  }

  // --- Currency Operations ---
  Stream<List<Currency>> watchAllCurrencies() {
    return (select(currencies)..orderBy([
          (t) => OrderingTerm(expression: t.isHome, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.shortName, mode: OrderingMode.asc),
        ]))
        .watch();
  }

  Future<List<Currency>> getAllCurrencies() {
    return (select(currencies)..orderBy([
          (t) => OrderingTerm(expression: t.isHome, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.shortName, mode: OrderingMode.asc),
        ]))
        .get();
  }

  Future<int> addCurrency({
    required String name,
    required String shortName,
    required double rate,
    bool isHome = false,
  }) async {
    if (isHome) {
      await (update(currencies)..where((t) => t.isHome.equals(true))).write(
        CurrenciesCompanion(
          isHome: const Value(false),
          lastModified: Value(DateTime.now()),
        ),
      );
    }
    return into(currencies).insert(
      CurrenciesCompanion.insert(
        name: name,
        shortName: shortName,
        rate: rate,
        isHome: Value(isHome),
      ),
    );
  }

  Future<bool> updateCurrencyEntry(Currency currency) {
    return update(currencies)
        .replace(currency.copyWith(lastModified: DateTime.now()));
  }

  Future<int> deleteCurrency(int id) {
    return (delete(currencies)..where((t) => t.id.equals(id))).go();
  }

  Future<void> setHomeCurrency(int id) async {
    await transaction(() async {
      await update(currencies).write(
        CurrenciesCompanion(
          isHome: const Value(false),
          lastModified: Value(DateTime.now()),
        ),
      );
      await (update(currencies)..where((t) => t.id.equals(id))).write(
        CurrenciesCompanion(
          isHome: const Value(true),
          lastModified: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> seedInitialCurrenciesIfEmpty() async {
    final count = await select(currencies).get();
    if (count.isEmpty) {
      await addCurrency(name: 'Euro', shortName: '€', rate: 1.0, isHome: true);
      await addCurrency(
        name: 'US Dollar',
        shortName: r'$',
        rate: 1.08,
        isHome: false,
      );
    }
  }

  // --- Todo / Checklist Operations ---
  Stream<List<TodoItem>> watchTodoItemsByState(int state) {
    return (select(todoItems)
          ..where((t) => t.state.equals(state))
          ..orderBy([
            (t) => OrderingTerm(expression: t.category, mode: OrderingMode.asc),
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Stream<List<TodoItem>> watchAllTodoItems() {
    return (select(todoItems)..orderBy([
          (t) => OrderingTerm(expression: t.category, mode: OrderingMode.asc),
          (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
        ]))
        .watch();
  }

  Future<List<String>> getAllCategories() async {
    final items = await select(todoItems).get();
    final categories = <String>{};
    for (final item in items) {
      if (item.category.trim().isNotEmpty) {
        categories.add(item.category.trim());
      }
    }
    final result = categories.toList()..sort();
    if (!result.contains('General')) {
      result.insert(0, 'General');
    }
    return result;
  }

  Future<int> addTodoItem({
    required String name,
    String category = 'General',
    String comment = '',
    int quantity = 1,
    int used = 0,
    int state = 0,
  }) {
    return into(todoItems).insert(
      TodoItemsCompanion.insert(
        name: name,
        category: Value(category.trim().isEmpty ? 'General' : category.trim()),
        comment: Value(comment),
        quantity: Value(quantity),
        used: Value(used),
        state: Value(state),
      ),
    );
  }

  Future<bool> updateTodoItemEntry(TodoItem item) {
    return update(todoItems)
        .replace(item.copyWith(lastModified: DateTime.now()));
  }

  Future<int> deleteTodoItem(int id) {
    return (delete(todoItems)..where((t) => t.id.equals(id))).go();
  }

  Future<void> setTodoItemState(int id, int state) {
    return (update(todoItems)..where((t) => t.id.equals(id))).write(
      TodoItemsCompanion(
        state: Value(state),
        lastModified: Value(DateTime.now()),
      ),
    );
  }

  // --- Note Operations ---
  Stream<List<Note>> watchAllNotes() {
    return (select(notes)..orderBy([
          (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<List<String>> getAllNoteTags() async {
    final allNotes = await select(notes).get();
    final tagSet = <String>{};
    for (final note in allNotes) {
      final tags = note.tags
          .split(databaseListSeparator)
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      tagSet.addAll(tags);
    }
    final sorted = tagSet.toList()..sort();
    return sorted;
  }

  Future<int> addNote({
    required String comment,
    String link = '',
    List<String> tags = const [],
  }) {
    final tagString = tags
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(databaseListSeparator);
    return into(notes).insert(
      NotesCompanion.insert(
        comment: Value(comment),
        link: Value(link),
        tags: Value(tagString),
      ),
    );
  }

  Future<bool> updateNoteEntry(Note note) {
    return update(notes).replace(note.copyWith(lastModified: DateTime.now()));
  }

  Future<int> deleteNote(int id) {
    return (delete(notes)..where((t) => t.id.equals(id))).go();
  }

  Future<int> restoreNote(Note note) {
    return into(notes).insert(note);
  }

  // --- Money Transaction Operations ---
  Stream<List<MoneyTransaction>> watchAllTransactions() {
    return (select(moneyTransactions)..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<int> addTransaction({
    required TransactionKind kind,
    required double amount,
    required String currency,
    String method = '',
    String comment = '',
    List<String> tags = const [],
    DateTime? date,
    int days = 1,
    String link = '',
  }) {
    return into(moneyTransactions).insert(
      MoneyTransactionsCompanion.insert(
        kind: Value(kind.index),
        amount: amount,
        currency: currency,
        method: Value(method.trim()),
        comment: Value(comment),
        tags: Value(
          tags
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .join(databaseListSeparator),
        ),
        date: Value(date ?? DateTime.now()),
        days: Value(days),
        link: Value(link),
      ),
    );
  }

  Future<bool> updateTransactionEntry(MoneyTransaction transaction) {
    return update(moneyTransactions)
        .replace(transaction.copyWith(lastModified: DateTime.now()));
  }

  Future<int> deleteTransaction(int id) {
    return (delete(moneyTransactions)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearContent(DatabaseContent content) async {
    await transaction(() async {
      await _deleteContent(content);
    });
  }

  Future<int> countContent(DatabaseContent content) async {
    return switch (content) {
      DatabaseContent.currencies => (await select(currencies).get()).length,
      DatabaseContent.checklist => (await select(todoItems).get()).length,
      DatabaseContent.notes => (await select(notes).get()).length,
      DatabaseContent.transactions => (await select(
        moneyTransactions,
      ).get()).length,
    };
  }

  Future<String> exportContentAsJson(DatabaseContent content) async {
    final records = switch (content) {
      DatabaseContent.currencies => (await select(
        currencies,
      ).get()).map((row) => row.toJson()).toList(),
      DatabaseContent.checklist => (await select(
        todoItems,
      ).get()).map((row) => row.toJson()).toList(),
      DatabaseContent.notes => (await select(
        notes,
      ).get()).map(_noteToJson).toList(),
      DatabaseContent.transactions => (await select(
        moneyTransactions,
      ).get()).map(_transactionToJson).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert({
      'formatVersion': _jsonExportFormatVersion,
      'content': content.name,
      'exportedAt': DateTime.now().toIso8601String(),
      'records': records,
      if (content == DatabaseContent.transactions)
        'currencies': (await select(
          currencies,
        ).get()).map((row) => row.toJson()).toList(),
    });
  }

  Future<ImportSummary?> importContentFromJson(
    DatabaseContent content,
    String json, {
    required ImportConflictResolver onConflict,
  }) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic> ||
        decoded['formatVersion'] != _jsonExportFormatVersion ||
        decoded['content'] != content.name ||
        decoded['records'] is! List ||
        (content == DatabaseContent.transactions &&
            decoded.containsKey('currencies') &&
            decoded['currencies'] is! List)) {
      throw FormatException('The file is not a valid ${content.label} export.');
    }

    final actions = <Future<void> Function()>[];
    final conflictState = _ImportConflictState();
    switch (content) {
      case DatabaseContent.currencies:
        if (!await _stageImportRows(
          content: content,
          rows: _parseRecords(decoded['records'], Currency.fromJson, content),
          existing: await select(currencies).get(),
          uuidOf: (row) => row.uuid,
          lastModifiedOf: (row) => row.lastModified,
          commentOf: (_) => null,
          onConflict: onConflict,
          conflictState: conflictState,
          actions: actions,
          write: _writeImportedCurrency,
        )) {
          return null;
        }
      case DatabaseContent.checklist:
        if (!await _stageImportRows(
          content: content,
          rows: _parseRecords(decoded['records'], TodoItem.fromJson, content),
          existing: await select(todoItems).get(),
          uuidOf: (row) => row.uuid,
          lastModifiedOf: (row) => row.lastModified,
          commentOf: (row) => row.comment,
          onConflict: onConflict,
          conflictState: conflictState,
          actions: actions,
          write: _writeImportedTodoItem,
        )) {
          return null;
        }
      case DatabaseContent.notes:
        if (!await _stageImportRows(
          content: content,
          rows: _parseRecords(decoded['records'], Note.fromJson, content),
          existing: await select(notes).get(),
          uuidOf: (row) => row.uuid,
          lastModifiedOf: (row) => row.lastModified,
          commentOf: (row) => row.comment,
          onConflict: onConflict,
          conflictState: conflictState,
          actions: actions,
          write: _writeImportedNote,
        )) {
          return null;
        }
      case DatabaseContent.transactions:
        if (decoded.containsKey('currencies') &&
            !await _stageImportRows(
              content: DatabaseContent.currencies,
              rows: _parseRecords(
                decoded['currencies'],
                Currency.fromJson,
                DatabaseContent.currencies,
              ),
              existing: await select(currencies).get(),
              uuidOf: (row) => row.uuid,
              lastModifiedOf: (row) => row.lastModified,
              commentOf: (_) => null,
              onConflict: onConflict,
              conflictState: conflictState,
              actions: actions,
              write: _writeImportedCurrency,
            )) {
          return null;
        }
        if (!await _stageImportRows(
          content: content,
          rows: _parseRecords(
            decoded['records'],
            _parseTimezoneIndependentTransaction,
            content,
          ),
          existing: await select(moneyTransactions).get(),
          uuidOf: (row) => row.uuid,
          lastModifiedOf: (row) => row.lastModified,
          commentOf: (row) => row.comment,
          onConflict: onConflict,
          conflictState: conflictState,
          actions: actions,
          write: _writeImportedTransaction,
        )) {
          return null;
        }
    }

    await transaction(() async {
      for (final action in actions) {
        await action();
      }
    });
    return ImportSummary(
      added: conflictState.added,
      skipped: conflictState.skipped,
      updated: conflictState.updated,
    );
  }

  Future<bool> _stageImportRows<T>({
    required DatabaseContent content,
    required List<T> rows,
    required List<T> existing,
    required String Function(T) uuidOf,
    required DateTime Function(T) lastModifiedOf,
    required String? Function(T) commentOf,
    required ImportConflictResolver onConflict,
    required _ImportConflictState conflictState,
    required List<Future<void> Function()> actions,
    required Future<void> Function(T row, bool insert) write,
  }) async {
    final rowsByUuid = {for (final row in existing) uuidOf(row): row};
    for (final row in rows) {
      final uuid = uuidOf(row);
      final current = rowsByUuid[uuid];
      if (current == null) {
        rowsByUuid[uuid] = row;
        actions.add(() => write(row, true));
        conflictState.added++;
        continue;
      }
      final currentModified = lastModifiedOf(current);
      final incomingModified = lastModifiedOf(row);
      if (_sameStoredTimestamp(currentModified, incomingModified)) {
        conflictState.skipped++;
        continue;
      }

      var resolution =
          conflictState.applyToAll ??
          await onConflict(
            ImportConflict(
              content: content,
              uuid: uuid,
              comment: commentOf(row),
              existingComment: commentOf(current),
              existingLastModified: currentModified,
              incomingLastModified: incomingModified,
            ),
          );
      if (resolution == ImportConflictResolution.skipAll) {
        conflictState.applyToAll = ImportConflictResolution.skip;
        resolution = ImportConflictResolution.skip;
      } else if (resolution == ImportConflictResolution.overwriteAll) {
        conflictState.applyToAll = ImportConflictResolution.overwrite;
        resolution = ImportConflictResolution.overwrite;
      }
      if (resolution == ImportConflictResolution.cancelImport) return false;
      if (resolution == ImportConflictResolution.overwrite) {
        rowsByUuid[uuid] = row;
        actions.add(() => write(row, false));
        conflictState.updated++;
      } else {
        conflictState.skipped++;
      }
    }
    return true;
  }

  Future<void> _writeImportedCurrency(Currency row, bool insert) async {
    if (row.isHome) {
      await (update(currencies)..where((t) => t.isHome.equals(true))).write(
        CurrenciesCompanion(
          isHome: const Value(false),
          lastModified: Value(DateTime.now()),
        ),
      );
    }
    final companion = CurrenciesCompanion(
      uuid: Value(row.uuid),
      lastModified: Value(row.lastModified),
      name: Value(row.name),
      shortName: Value(row.shortName),
      rate: Value(row.rate),
      isHome: Value(row.isHome),
    );
    if (insert) {
      await into(currencies).insert(companion);
    } else {
      await (update(
        currencies,
      )..where((t) => t.uuid.equals(row.uuid))).write(companion);
    }
  }

  Future<void> _writeImportedTodoItem(TodoItem row, bool insert) async {
    final companion = TodoItemsCompanion(
      uuid: Value(row.uuid),
      lastModified: Value(row.lastModified),
      name: Value(row.name),
      category: Value(row.category),
      comment: Value(row.comment),
      quantity: Value(row.quantity),
      used: Value(row.used),
      state: Value(row.state),
    );
    if (insert) {
      await into(todoItems).insert(companion);
    } else {
      await (update(
        todoItems,
      )..where((t) => t.uuid.equals(row.uuid))).write(companion);
    }
  }

  Future<void> _writeImportedNote(Note row, bool insert) async {
    final companion = NotesCompanion(
      uuid: Value(row.uuid),
      lastModified: Value(row.lastModified),
      comment: Value(row.comment),
      link: Value(row.link),
      tags: Value(row.tags),
    );
    if (insert) {
      await into(notes).insert(companion);
    } else {
      await (update(
        notes,
      )..where((t) => t.uuid.equals(row.uuid))).write(companion);
    }
  }

  Future<void> _writeImportedTransaction(
    MoneyTransaction row,
    bool insert,
  ) async {
    final companion = MoneyTransactionsCompanion(
      uuid: Value(row.uuid),
      lastModified: Value(row.lastModified),
      kind: Value(row.kind),
      amount: Value(row.amount),
      currency: Value(row.currency),
      method: Value(row.method),
      comment: Value(row.comment),
      tags: Value(row.tags),
      date: Value(row.date),
      days: Value(row.days),
      link: Value(row.link),
    );
    if (insert) {
      await into(moneyTransactions).insert(companion);
    } else {
      await (update(
        moneyTransactions,
      )..where((t) => t.uuid.equals(row.uuid))).write(companion);
    }
  }

  Future<void> _deleteContent(DatabaseContent content) async {
    switch (content) {
      case DatabaseContent.currencies:
        await delete(currencies).go();
      case DatabaseContent.checklist:
        await delete(todoItems).go();
      case DatabaseContent.notes:
        await delete(notes).go();
      case DatabaseContent.transactions:
        await delete(moneyTransactions).go();
    }
  }

  Future<int> restoreTransaction(MoneyTransaction transaction) {
    return into(moneyTransactions).insert(transaction);
  }
}

List<T> _parseRecords<T>(
  Object? rawRecords,
  T Function(Map<String, dynamic>) parse,
  DatabaseContent content,
) {
  final records = rawRecords as List<dynamic>;
  return [
    for (var index = 0; index < records.length; index++)
      _parseRecord(records[index], parse, content, index),
  ];
}

Map<String, dynamic> _noteToJson(Note note) {
  final json = note.toJson();
  json['link'] = note.linkList;
  json['tags'] = note.tagList;
  return json;
}

Map<String, dynamic> _transactionToJson(MoneyTransaction transaction) {
  final json = transaction.toJson();
  json['date'] = formatDateTime(transaction.date);
  json['link'] = transaction.linkList;
  json['tags'] = transaction.storedTagList;
  return json;
}

MoneyTransaction _parseTimezoneIndependentTransaction(
  Map<String, dynamic> json,
) {
  final record = Map<String, dynamic>.from(json);
  final date = record['date'];
  if (date is String) {
    final humanDate = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4}) (\d{2}):(\d{2})$')
        .firstMatch(date);
    if (humanDate != null) {
      final day = int.parse(humanDate[1]!);
      final month = int.parse(humanDate[2]!);
      final year = int.parse(humanDate[3]!);
      final hour = int.parse(humanDate[4]!);
      final minute = int.parse(humanDate[5]!);
      final parsed = DateTime(year, month, day, hour, minute);
      if (parsed.year != year ||
          parsed.month != month ||
          parsed.day != day ||
          parsed.hour != hour ||
          parsed.minute != minute) {
        throw FormatException('Invalid transaction date "$date".');
      }
      record['date'] = parsed.toIso8601String();
    } else {
      record['date'] = date.replaceFirst(
        RegExp(r'(?:Z|[+-]\d{2}(?::?\d{2})?)$', caseSensitive: false),
        '',
      );
    }
  }
  return MoneyTransaction.fromJson(record);
}

T _parseRecord<T>(
  Object? rawRecord,
  T Function(Map<String, dynamic>) parse,
  DatabaseContent content,
  int index,
) {
  if (rawRecord is! Map<String, dynamic>) {
    throw FormatException(
      'Record ${index + 1} in the ${content.label} file is invalid.',
    );
  }
  try {
    final record = Map<String, dynamic>.from(rawRecord);
    final separators = switch (content) {
      DatabaseContent.notes => {
        'link': databaseListSeparator,
        'tags': databaseListSeparator,
      },
      DatabaseContent.transactions => {
        'link': databaseListSeparator,
        'tags': databaseListSeparator,
      },
      _ => const <String, String>{},
    };
    for (final entry in separators.entries) {
      final value = record[entry.key];
      if (value is! List || value.any((item) => item is! String)) {
        throw FormatException(
          'Record ${index + 1} in the ${content.label} file is invalid.',
        );
      }
      record[entry.key] = value.join(entry.value);
    }
    final uuid = record['uuid'];
    if (uuid == null || (uuid is String && uuid.trim().isEmpty)) {
      record['uuid'] = _newUuid();
    }
    final lastModified = record['lastModified'];
    if (lastModified == null ||
        (lastModified is String && lastModified.trim().isEmpty)) {
      record['lastModified'] = DateTime.now().toIso8601String();
    }
    return parse(record);
  } on FormatException {
    rethrow;
  } on TypeError {
    throw FormatException(
      'Record ${index + 1} in the ${content.label} file is invalid.',
    );
  }
}

enum DatabaseContent {
  currencies('Currencies'),
  checklist('Checklist'),
  notes('Notes'),
  transactions('Transactions');

  const DatabaseContent(this.label);

  final String label;
}

// The index is stored in the database: only append new kinds.
enum TransactionKind { expense, withdrawal, cashCount, deposit, hotel }

const cashMethod = 'cash';
const plannedTag = 'planned';
const bookedTag = 'booked';
const calendarTag = 'calendar';
const starTag = '⭐';
const positionTag = '📍';
const expenseTag = 'expense';
const atmTag = 'atm';
const countTag = 'count';
const depositTag = 'deposit';
const hotelTag = 'hotel';
const reservedTransactionTags = {
  plannedTag,
  bookedTag,
  calendarTag,
  expenseTag,
  atmTag,
  countTag,
  depositTag,
  hotelTag,
};

String transactionKindTag(TransactionKind kind) => switch (kind) {
  TransactionKind.expense => expenseTag,
  TransactionKind.withdrawal => atmTag,
  TransactionKind.cashCount => countTag,
  TransactionKind.deposit => depositTag,
  TransactionKind.hotel => hotelTag,
};

bool isReservedTransactionTag(String tag) =>
    reservedTransactionTags.contains(tag.trim().toLowerCase());

bool isTagEditorHiddenTag(String tag) =>
    isReservedTransactionTag(tag) || tag.trim() == starTag;

extension MoneyTransactionHelpers on MoneyTransaction {
  TransactionKind get type => kind >= 0 && kind < TransactionKind.values.length
      ? TransactionKind.values[kind]
      : TransactionKind.expense;

  bool get isPlanned => tagList.any((tag) => tag.toLowerCase() == plannedTag);

  bool get isExpense => type == TransactionKind.expense;
  bool get isWithdrawal => type == TransactionKind.withdrawal;
  bool get isCashCount => type == TransactionKind.cashCount;
  bool get isDeposit => type == TransactionKind.deposit;
  bool get isHotel => type == TransactionKind.hotel;

  /// Money spent on something: an expense or a hotel booking.
  bool get isSpending => isExpense || isHotel;

  bool get isCash => method.trim().isEmpty || method == cashMethod;

  List<String> get storedTagList => tags
      .split(databaseListSeparator)
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<String> get editableTagList => storedTagList
      .where((tag) => tag.toLowerCase() != transactionKindTag(type))
      .toList();

  List<String> get tagList {
    final result = storedTagList;
    final implicitTag = transactionKindTag(type);
    if (!result.any((tag) => tag.toLowerCase() == implicitTag)) {
      result.add(implicitTag);
    }
    return result;
  }

  List<String> get linkList => link
      .split(databaseListSeparator)
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

extension NoteHelpers on Note {
  List<String> get tagList => tags
      .split(databaseListSeparator)
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<String> get linkList => link
      .split(databaseListSeparator)
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  bool get isLink => linkList.any(
    (l) =>
        l.toLowerCase().startsWith('http://') ||
        l.toLowerCase().startsWith('https://'),
  );

  bool get isGeo => linkList.any((l) => l.toLowerCase().startsWith('geo:'));

  bool get isFile => linkList.any((l) => l.startsWith('/'));

  String shortLink([int index = 0]) {
    final links = linkList;
    if (links.isEmpty) return '';
    final l = (index >= 0 && index < links.length) ? links[index] : links.first;
    if (l.startsWith('https://')) {
      return l.substring(8);
    } else if (l.startsWith('http://')) {
      return l.substring(7);
    } else if (l.length > 30) {
      return '...${l.substring(l.length - 25)}';
    }
    return l;
  }

  String linksSummary() {
    final links = linkList;
    if (links.isEmpty) return '';
    if (links.length == 1) return shortLink(0);
    return '${links.length} links: ${links.map((l) => _formatShortLink(l)).join(', ')}';
  }

  static String _formatShortLink(String l) {
    if (l.startsWith('https://')) return l.substring(8);
    if (l.startsWith('http://')) return l.substring(7);
    if (l.length > 25) return '...${l.substring(l.length - 20)}';
    return l;
  }
}
