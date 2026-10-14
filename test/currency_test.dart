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

    expect(currencies, hasLength(2));
    expect(
      currencies.map((currency) => currency.shortName).toSet(),
      {'€', r'$'},
    );
    expect(
      currencies.any(
        (currency) =>
            currency.name == 'Euro' &&
            currency.shortName == '€' &&
            currency.isHome,
      ),
      isTrue,
    );
    expect(
      currencies.any(
        (currency) =>
            currency.name == 'US Dollar' &&
            currency.shortName == r'$' &&
            !currency.isHome,
      ),
      isTrue,
    );

    await database.seedInitialCurrenciesIfEmpty();
    expect(await database.getAllCurrencies(), hasLength(2));
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
    final usd = currencies.firstWhere((c) => c.shortName == r'$');

    await database.setHomeCurrency(usd.id);

    final updatedCurrencies = await database.getAllCurrencies();
    final updatedUsd = updatedCurrencies.firstWhere((c) => c.shortName == r'$');
    final updatedEur = updatedCurrencies.firstWhere((c) => c.shortName == '€');

    expect(updatedUsd.isHome, isTrue);
    expect(updatedEur.isHome, isFalse);
  });

  test('Delete currency', () async {
    await database.seedInitialCurrenciesIfEmpty();

    final currencies = await database.getAllCurrencies();
    final usd = currencies.firstWhere((c) => c.shortName == r'$');

    await database.deleteCurrency(usd.id);

    final remaining = await database.getAllCurrencies();
    expect(remaining.map((currency) => currency.shortName), ['€']);
  });
}
