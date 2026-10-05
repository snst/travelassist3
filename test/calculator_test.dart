import 'package:flutter_test/flutter_test.dart';
import 'package:travelassist3/calculator/calculator.dart';
import 'package:travelassist3/calculator/currency_value.dart';
import 'package:travelassist3/database/database.dart';

void main() {
  final eur = const Currency(id: 1, name: 'Euro', shortName: 'EUR', rate: 1.0, isHome: true);
  final usd = const Currency(id: 2, name: 'US Dollar', shortName: 'USD', rate: 1.08, isHome: false);
  final gbp = const Currency(id: 3, name: 'Pound', shortName: 'GBP', rate: 0.83, isHome: false);

  test('CurrencyValue conversion', () {
    final eurVal = CurrencyValue(100, eur);
    final usdVal = eurVal.convertTo(usd);

    expect(usdVal.value, closeTo(108.0, 0.01));
    expect(usdVal.currency?.shortName, 'USD');

    final gbpVal = eurVal.convertTo(gbp);
    expect(gbpVal.value, closeTo(83.0, 0.01));

    final backToEur = usdVal.convertTo(eur);
    expect(backToEur.value, closeTo(100.0, 0.01));
  });

  test('Calculator operations across currencies', () {
    final calculator = Calculator();

    // 100 EUR + 108 USD = 200 EUR
    calculator.pushValue(CurrencyValue(100, eur));
    calculator.add();
    calculator.pushValue(CurrencyValue(108, usd));
    calculator.calculate();

    expect(calculator.sum.value, closeTo(200.0, 0.01));
    expect(calculator.sum.currency?.shortName, 'EUR');
    expect(calculator.showResult(), isTrue);
  });

  test('Calculator subtract and clear', () {
    final calculator = Calculator();

    calculator.pushValue(CurrencyValue(100, eur));
    calculator.subtract();
    calculator.pushValue(CurrencyValue(50, eur));
    calculator.calculate();

    expect(calculator.sum.value, closeTo(50.0, 0.01));

    calculator.clear();
    expect(calculator.inputString, isEmpty);
    expect(calculator.sum.value, 0);
  });
}
