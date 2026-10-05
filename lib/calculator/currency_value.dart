import '../database/database.dart';

class CurrencyValue {
  double value;
  Currency? currency;

  CurrencyValue(this.value, this.currency);

  String get valueString => value.toStringAsFixed(2);

  String get currencyString => currency != null ? currency!.shortName : "?";

  @override
  String toString() => "$valueString $currencyString";

  String toShortString() {
    String formatted = removeTrailingZeros(valueString);
    return "$formatted $currencyString";
  }

  bool isZero() => value == 0;

  void reset() {
    value = 0;
    currency = null;
  }

  CurrencyValue convertTo(Currency? toCurrency) {
    if (currency == null || toCurrency == null || currency!.id == toCurrency.id) {
      return this;
    }
    if (currency!.rate == 0) {
      return CurrencyValue(value, toCurrency);
    }
    double converted = (value / currency!.rate) * toCurrency.rate;
    return CurrencyValue(converted, toCurrency);
  }

  void add(CurrencyValue? other) {
    if (other != null) {
      currency ??= other.currency;
      value += other.convertTo(currency).value;
    }
  }

  void sub(CurrencyValue? other) {
    if (other != null) {
      currency ??= other.currency;
      value -= other.convertTo(currency).value;
    }
  }

  static String removeTrailingZeros(String inputString) {
    if (inputString.endsWith('.00')) {
      return inputString.substring(0, inputString.length - 3);
    }
    return inputString;
  }

  static double safeConvertToDouble(String input) {
    input = input.replaceAll(',', '.');
    List<String> parts = input.split('.');
    if (parts.length >= 3) {
      input = '${parts[0]}.${parts[1]}';
    }

    try {
      return double.parse(input);
    } catch (_) {
      return 0.0;
    }
  }
}
