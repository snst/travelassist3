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

@DriftDatabase(tables: [Currencies])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'travel_assist_db');
  }

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
}
