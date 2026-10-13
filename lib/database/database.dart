import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

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
  IntColumn get state => integer().withDefault(const Constant(0))(); // 0: open, 1: skipped, 2: done
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
  IntColumn get kind => integer().withDefault(const Constant(0))(); // TransactionKind.index
  RealColumn get amount => real()();
  TextColumn get currency => text()(); // Currency.shortName
  TextColumn get method => text().withDefault(const Constant(''))(); // empty or 'Cash' means cash
  TextColumn get comment => text().withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  // Number of days the entry covers: for expenses the days it counts in the daily average
  // (0 = not included, 1 = default), for e.g. a hotel booking its length.
  IntColumn get days => integer().withDefault(const Constant(1))();
  IntColumn get state => integer().withDefault(const Constant(2))(); // TransactionState.index, default paid
  TextColumn get link => text().withDefault(const Constant(''))(); // tab separated, like Notes.link
}

@DriftDatabase(tables: [Currencies, TodoItems, Notes, MoneyTransactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(todoItems);
        }
        if (from < 3) {
          await m.createTable(notes);
        }
        if (from < 4) {
          await m.createTable(moneyTransactions);
        }
        // Tables created above (from < 4) already have the current layout. Older ones are
        // rebuilt once: link is new before v6, is_planned (v5-v7) became the state column and
        // include_in_average became days. include_in_average used to be a bool; the old 0/1
        // values carry over unchanged, but the rebuild drops the bool CHECK.
        if (from >= 4 && from < 8) {
          await m.alterTable(
            TableMigration(
              moneyTransactions,
              columnTransformer: {
                moneyTransactions.days: const CustomExpression<int>('include_in_average'),
                if (from >= 5)
                  moneyTransactions.state: const CustomExpression<int>(
                    'CASE WHEN is_planned = 1 THEN 0 ELSE 2 END',
                  ),
              },
              newColumns: [
                if (from < 6) moneyTransactions.link,
                moneyTransactions.state,
                moneyTransactions.days,
              ],
            ),
          );
        }
        if (from == 8) {
          await m.renameColumn(
            moneyTransactions,
            'include_in_average',
            moneyTransactions.days,
          );
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'travel_assist_db');
  }

  // --- Currency Operations ---
  Stream<List<Currency>> watchAllCurrencies() {
    return (select(currencies)
          ..orderBy([
            (t) => OrderingTerm(expression: t.isHome, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.shortName, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<List<Currency>> getAllCurrencies() {
    return (select(currencies)
          ..orderBy([
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
      await (update(currencies)..where((t) => t.isHome.equals(true)))
          .write(const CurrenciesCompanion(isHome: Value(false)));
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
      await update(currencies).write(
        const CurrenciesCompanion(isHome: Value(false)),
      );
      await (update(currencies)..where((t) => t.id.equals(id))).write(
        const CurrenciesCompanion(isHome: Value(true)),
      );
    });
  }

  Future<void> seedInitialCurrenciesIfEmpty() async {
    final count = await select(currencies).get();
    if (count.isEmpty) {
      await addCurrency(
        name: 'Euro',
        shortName: 'EUR',
        rate: 1.0,
        isHome: true,
      );
      await addCurrency(
        name: 'US Dollar',
        shortName: 'USD',
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
    return (select(todoItems)
          ..orderBy([
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
    return (update(todoItems)..where((t) => t.id.equals(id)))
        .write(TodoItemsCompanion(state: Value(state)));
  }

  // --- Note Operations ---
  Stream<List<Note>> watchAllNotes() {
    return (select(notes)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<String>> getAllNoteTags() async {
    final allNotes = await select(notes).get();
    final tagSet = <String>{};
    for (final note in allNotes) {
      final tags = note.tags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
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
    final tagString = tags.map((e) => e.trim()).where((e) => e.isNotEmpty).join(',');
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
    return (select(moneyTransactions)
          ..orderBy([
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
    TransactionState state = TransactionState.paid,
    String link = '',
  }) {
    return into(moneyTransactions).insert(
      MoneyTransactionsCompanion.insert(
        kind: Value(kind.index),
        amount: amount,
        currency: currency,
        method: Value(method.trim()),
        comment: Value(comment),
        tags: Value(tags.map((e) => e.trim()).where((e) => e.isNotEmpty).join(',')),
        date: Value(date ?? DateTime.now()),
        days: Value(days),
        state: Value(state.index),
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
    });
  }

  Future<int> restoreTransaction(MoneyTransaction transaction) {
    return into(moneyTransactions).insert(transaction);
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

/// Lifecycle of a transaction; the index is stored in [MoneyTransactions.state].
enum TransactionState { planned, booked, paid }

const cashMethod = 'Cash';

extension MoneyTransactionHelpers on MoneyTransaction {
  TransactionKind get type => kind >= 0 && kind < TransactionKind.values.length
      ? TransactionKind.values[kind]
      : TransactionKind.expense;

  TransactionState get transactionState =>
      state >= 0 && state < TransactionState.values.length
          ? TransactionState.values[state]
          : TransactionState.paid;

  bool get isPlanned => transactionState == TransactionState.planned;
  bool get isBooked => transactionState == TransactionState.booked;
  bool get isPaid => transactionState == TransactionState.paid;

  bool get isExpense => type == TransactionKind.expense;
  bool get isWithdrawal => type == TransactionKind.withdrawal;
  bool get isCashCount => type == TransactionKind.cashCount;
  bool get isDeposit => type == TransactionKind.deposit;
  bool get isHotel => type == TransactionKind.hotel;

  /// Money spent on something: an expense or a hotel booking.
  bool get isSpending => isExpense || isHotel;

  /// Still a future cost: planned, or for a hotel also booked but not yet paid.
  bool get isPending => isPlanned || (isHotel && isBooked);

  bool get isCash => method.trim().isEmpty || method == cashMethod;

  List<String> get tagList => tags
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<String> get linkList => link
      .split('\t')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

extension NoteHelpers on Note {
  List<String> get tagList => tags
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<String> get linkList => link
      .split('\t')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  bool get isLink => linkList.any((l) =>
      l.toLowerCase().startsWith('http://') ||
      l.toLowerCase().startsWith('https://'));

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
