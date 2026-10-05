import 'dart:ffi';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:travelassist3/database/database.dart';

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

  test('Initial seed adds default currencies', () async {
    await database.seedInitialCurrenciesIfEmpty();
    final currencies = await database.getAllCurrencies();

    expect(currencies.length, 4);
    expect(currencies.any((c) => c.shortName == 'EUR' && c.isHome), isTrue);
  });

  test('Add new currency', () async {
    await database.addCurrency(
      name: 'Canadian Dollar',
      shortName: 'CAD',
      rate: 1.48,
      isHome: false,
    );

    final currencies = await database.getAllCurrencies();
    expect(currencies.any((c) => c.shortName == 'CAD'), isTrue);
  });

  test('Set home currency updates isHome flags', () async {
    await database.seedInitialCurrenciesIfEmpty();

    final currencies = await database.getAllCurrencies();
    final usd = currencies.firstWhere((c) => c.shortName == 'USD');

    await database.setHomeCurrency(usd.id);

    final updatedCurrencies = await database.getAllCurrencies();
    final updatedUsd = updatedCurrencies.firstWhere((c) => c.shortName == 'USD');
    final updatedEur = updatedCurrencies.firstWhere((c) => c.shortName == 'EUR');

    expect(updatedUsd.isHome, isTrue);
    expect(updatedEur.isHome, isFalse);
  });

  test('Delete currency', () async {
    await database.seedInitialCurrenciesIfEmpty();

    final currencies = await database.getAllCurrencies();
    final jpy = currencies.firstWhere((c) => c.shortName == 'JPY');

    await database.deleteCurrency(jpy.id);

    final remaining = await database.getAllCurrencies();
    expect(remaining.any((c) => c.shortName == 'JPY'), isFalse);
  });
}
