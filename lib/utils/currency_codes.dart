import '../balance/balance.dart';
import '../database/database.dart';

/// The last used currency, falling back to the home currency.
String defaultCurrencyCode(
  List<Currency> currencies,
  List<MoneyTransaction> transactions,
) {
  final codes = currencies.map((c) => c.shortName).toList();
  final lastUsed = transactions.isNotEmpty ? transactions.first.currency : null;
  if (lastUsed != null && codes.contains(lastUsed)) return lastUsed;
  return Balance.homeCurrencyOf(currencies)?.shortName ??
      (codes.isEmpty ? '' : codes.first);
}

/// Currency codes to offer; keeps [selected] even if its currency was removed.
List<String> currencyCodesWithSelected(
  List<Currency> currencies,
  String selected,
) {
  final codes = currencies.map((c) => c.shortName).toList();
  if (selected.isNotEmpty && !codes.contains(selected)) codes.add(selected);
  return codes;
}
