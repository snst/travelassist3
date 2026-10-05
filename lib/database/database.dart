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

@DriftDatabase(tables: [Currencies, TodoItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

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
      await addCurrency(
        name: 'British Pound',
        shortName: 'GBP',
        rate: 0.83,
        isHome: false,
      );
      await addCurrency(
        name: 'Japanese Yen',
        shortName: 'JPY',
        rate: 160.50,
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

  Future<void> seedInitialTodoItemsIfEmpty() async {
    final count = await select(todoItems).get();
    if (count.isEmpty) {
      await addTodoItem(name: 'Passport', category: 'Documents', quantity: 1);
      await addTodoItem(name: 'Boarding Pass / Tickets', category: 'Documents', quantity: 1);
      await addTodoItem(name: 'Phone Charger', category: 'Electronics', quantity: 1);
      await addTodoItem(name: 'Power Bank', category: 'Electronics', quantity: 1);
      await addTodoItem(name: 'Toothbrush & Paste', category: 'Toiletries', quantity: 1);
      await addTodoItem(name: 'Sunscreen', category: 'Toiletries', quantity: 1);
      await addTodoItem(name: 'T-Shirts', category: 'Clothing', quantity: 5);
      await addTodoItem(name: 'Jacket', category: 'Clothing', quantity: 1);
    }
  }
}
