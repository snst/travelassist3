import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'database_file_deleter_stub.dart'
    if (dart.library.io) 'database_file_deleter_io.dart'
    as file_deleter;
part 'database.g.dart';

const defaultDatabaseName = 'travel_assist_db';

class DatabaseProfile {
  final String id;
  final String name;

  const DatabaseProfile({required this.id, required this.name});
}

class Currencies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get shortName => text()();
  RealColumn get rate => real()();
  BoolColumn get isHome => boolean().withDefault(const Constant(false))();
}

class TodoItems extends Table {
  IntColumn get id => integer().autoIncrement()();
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
  TextColumn get comment => text().withDefault(const Constant(''))();
  TextColumn get link => text().withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('MoneyTransaction')
class MoneyTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get kind =>
      integer().withDefault(const Constant(0))(); // TransactionKind.index
  RealColumn get amount => real()();
  TextColumn get currency => text()(); // Currency.shortName
  TextColumn get method =>
      text().withDefault(const Constant(''))(); // empty or 'cash' means cash
  TextColumn get comment => text().withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
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
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 13) {
          // Drop legacy status columns without converting their values to tags.
          // ignore: experimental_member_use
          await m.alterTable(TableMigration(moneyTransactions));
        }
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
        const CurrenciesCompanion(isHome: Value(false)),
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
    return update(currencies).replace(currency);
  }

  Future<int> deleteCurrency(int id) {
    return (delete(currencies)..where((t) => t.id.equals(id))).go();
  }

  Future<void> setHomeCurrency(int id) async {
    await transaction(() async {
      await update(currencies)
          .write(const CurrenciesCompanion(isHome: Value(false)));
      await (update(currencies)..where((t) => t.id.equals(id))).write(
        const CurrenciesCompanion(isHome: Value(true)),
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
    return update(todoItems).replace(item);
  }

  Future<int> deleteTodoItem(int id) {
    return (delete(todoItems)..where((t) => t.id.equals(id))).go();
  }

  Future<void> setTodoItemState(int id, int state) {
    return (update(todoItems)..where((t) => t.id.equals(id))).write(
      TodoItemsCompanion(state: Value(state)),
    );
  }

  // --- Note Operations ---
  Stream<List<Note>> watchAllNotes() {
    return (select(notes)..orderBy([
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<List<String>> getAllNoteTags() async {
    final allNotes = await select(notes).get();
    final tagSet = <String>{};
    for (final note in allNotes) {
      final tags = note.tags
          .split(',')
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
        .join(',');
    return into(notes).insert(
      NotesCompanion.insert(
        comment: Value(comment),
        link: Value(link),
        tags: Value(tagString),
      ),
    );
  }

  Future<bool> updateNoteEntry(Note note) {
    return update(notes).replace(note);
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
          tags.map((e) => e.trim()).where((e) => e.isNotEmpty).join(','),
        ),
        date: Value(date ?? DateTime.now()),
        days: Value(days),
        link: Value(link),
      ),
    );
  }

  Future<bool> updateTransactionEntry(MoneyTransaction transaction) {
    return update(moneyTransactions).replace(transaction);
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
      ).get()).map((row) => row.toJson()).toList(),
      DatabaseContent.transactions => (await select(
        moneyTransactions,
      ).get()).map((row) => row.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert({
      'formatVersion': 1,
      'content': content.name,
      'exportedAt': DateTime.now().toIso8601String(),
      'records': records,
      if (content == DatabaseContent.transactions)
        'currencies': (await select(
          currencies,
        ).get()).map((row) => row.toJson()).toList(),
    });
  }

  Future<void> importContentFromJson(
    DatabaseContent content,
    String json, {
    required bool deleteExisting,
  }) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic> ||
        decoded['formatVersion'] != 1 ||
        decoded['content'] != content.name ||
        decoded['records'] is! List ||
        (content == DatabaseContent.transactions &&
            decoded.containsKey('currencies') &&
            decoded['currencies'] is! List)) {
      throw FormatException('The file is not a valid ${content.label} export.');
    }

    switch (content) {
      case DatabaseContent.currencies:
        final rows = _parseRecords(
          decoded['records'],
          Currency.fromJson,
          content,
        );
        await transaction(() async {
          final preserveIds = await _prepareImport(content, deleteExisting);
          await _insertCurrencyRows(rows, preserveIds: preserveIds);
        });
      case DatabaseContent.checklist:
        final rows = _parseRecords(
          decoded['records'],
          TodoItem.fromJson,
          content,
        );
        await transaction(() async {
          final preserveIds = await _prepareImport(content, deleteExisting);
          final existingItems = (await select(todoItems).get())
              .map(
                (item) => (
                  item.name,
                  item.category,
                  item.comment,
                  item.quantity,
                  item.used,
                  item.state,
                ),
              )
              .toSet();
          for (final row in rows) {
            final key = (
              row.name,
              row.category,
              row.comment,
              row.quantity,
              row.used,
              row.state,
            );
            if (!existingItems.add(key)) continue;
            await into(todoItems).insert(
              preserveIds
                  ? row.toCompanion(false)
                  : TodoItemsCompanion.insert(
                      name: row.name,
                      category: Value(row.category),
                      comment: Value(row.comment),
                      quantity: Value(row.quantity),
                      used: Value(row.used),
                      state: Value(row.state),
                    ),
            );
          }
        });
      case DatabaseContent.notes:
        final rows = _parseRecords(decoded['records'], Note.fromJson, content);
        await transaction(() async {
          final preserveIds = await _prepareImport(content, deleteExisting);
          final existingNotes = (await select(
            notes,
          ).get()).map((note) => (note.comment, note.link, note.tags)).toSet();
          for (final row in rows) {
            if (!existingNotes.add((row.comment, row.link, row.tags))) continue;
            await into(notes).insert(
              preserveIds
                  ? row.toCompanion(false)
                  : NotesCompanion.insert(
                      comment: Value(row.comment),
                      link: Value(row.link),
                      tags: Value(row.tags),
                      createdAt: Value(row.createdAt),
                    ),
            );
          }
        });
      case DatabaseContent.transactions:
        final includesCurrencies = decoded.containsKey('currencies');
        final currencyRows = includesCurrencies
            ? _parseRecords(
                decoded['currencies'],
                Currency.fromJson,
                DatabaseContent.currencies,
              )
            : <Currency>[];
        final rows = _parseRecords(
          decoded['records'],
          MoneyTransaction.fromJson,
          content,
        );
        await transaction(() async {
          if (includesCurrencies) {
            final preserveCurrencyIds = await _prepareImport(
              DatabaseContent.currencies,
              deleteExisting,
            );
            final existingCodes = (await select(
              currencies,
            ).get()).map((currency) => currency.shortName).toSet();
            final currenciesToImport = deleteExisting
                ? currencyRows
                : currencyRows
                      .where(
                        (currency) =>
                            !existingCodes.contains(currency.shortName),
                      )
                      .toList();
            await _insertCurrencyRows(
              currenciesToImport,
              preserveIds: preserveCurrencyIds,
            );
          }
          final preserveIds = await _prepareImport(content, deleteExisting);
          final existingTransactions = (await select(moneyTransactions).get())
              .map(
                (transaction) => (
                  transaction.kind,
                  transaction.amount,
                  transaction.currency,
                  transaction.method,
                  transaction.comment,
                  transaction.tags,
                  transaction.date,
                  transaction.days,
                  transaction.link,
                ),
              )
              .toSet();
          for (final row in rows) {
            final key = (
              row.kind,
              row.amount,
              row.currency,
              row.method,
              row.comment,
              row.tags,
              row.date,
              row.days,
              row.link,
            );
            if (!existingTransactions.add(key)) continue;
            await into(moneyTransactions).insert(
              preserveIds
                  ? row.toCompanion(false)
                  : MoneyTransactionsCompanion.insert(
                      kind: Value(row.kind),
                      amount: row.amount,
                      currency: row.currency,
                      method: Value(row.method),
                      comment: Value(row.comment),
                      tags: Value(row.tags),
                      date: Value(row.date),
                      days: Value(row.days),
                      link: Value(row.link),
                    ),
            );
          }
        });
    }
  }

  Future<void> _insertCurrencyRows(
    List<Currency> rows, {
    required bool preserveIds,
  }) async {
    var hasHomeCurrency = (await select(
      currencies,
    ).get()).any((currency) => currency.isHome);
    for (final row in rows) {
      final isHome = row.isHome && !hasHomeCurrency;
      if (isHome) hasHomeCurrency = true;
      final currency = row.copyWith(isHome: isHome);
      await into(currencies).insert(
        preserveIds
            ? currency.toCompanion(false)
            : CurrenciesCompanion.insert(
                name: currency.name,
                shortName: currency.shortName,
                rate: currency.rate,
                isHome: Value(currency.isHome),
              ),
      );
    }
  }

  Future<bool> _prepareImport(
    DatabaseContent content,
    bool deleteExisting,
  ) async {
    final hadExisting = await countContent(content) > 0;
    if (deleteExisting) await _deleteContent(content);
    return deleteExisting || !hadExisting;
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
    return parse(rawRecord);
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

  List<String> get storedTagList =>
      tags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

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

  List<String> get linkList =>
      link.split('\t').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

extension NoteHelpers on Note {
  List<String> get tagList =>
      tags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  List<String> get linkList =>
      link.split('\t').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

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
