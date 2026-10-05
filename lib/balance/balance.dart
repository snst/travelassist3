import '../calculator/currency_value.dart';
import '../database/database.dart';

/// A sum in the home currency plus the same sum split by original currency.
class Totals {
  Totals(this.home) : total = CurrencyValue(0, home);

  final Currency? home;
  final CurrencyValue total;
  final Map<String, CurrencyValue> byCurrency = {};

  bool get isEmpty => total.value == 0 && byCurrency.values.every((v) => v.value == 0);

  void add(String code, CurrencyValue amount, {double sign = 1}) {
    final signed = CurrencyValue(amount.value * sign, amount.currency);
    total.add(signed);
    byCurrency.putIfAbsent(code, () => CurrencyValue(0, amount.currency)).add(signed);
  }

  Totals scaled(double factor) {
    final result = Totals(home);
    result.total.value = total.value * factor;
    byCurrency.forEach((code, v) {
      result.byCurrency[code] = CurrencyValue(v.value * factor, v.currency);
    });
    return result;
  }
}

class ExpenseBreakdown {
  ExpenseBreakdown(this.home)
      : total = Totals(home),
        cash = Totals(home),
        card = Totals(home);

  final Currency? home;
  Totals total;
  Totals cash;
  Totals card;
  final Map<String, Totals> cardByMethod = {};

  void add(
    String code,
    CurrencyValue amount, {
    required bool isCash,
    String method = '',
    double sign = 1,
  }) {
    total.add(code, amount, sign: sign);
    if (isCash) {
      cash.add(code, amount, sign: sign);
    } else {
      card.add(code, amount, sign: sign);
      cardByMethod.putIfAbsent(method, () => Totals(home)).add(code, amount, sign: sign);
    }
  }

  ExpenseBreakdown scaled(double factor) {
    final result = ExpenseBreakdown(home)
      ..total = total.scaled(factor)
      ..cash = cash.scaled(factor)
      ..card = card.scaled(factor);
    cardByMethod.forEach((method, t) => result.cardByMethod[method] = t.scaled(factor));
    return result;
  }
}

class Balance {
  Balance._(this.home)
      : expenses = ExpenseBreakdown(home),
        dailyAverage = ExpenseBreakdown(home),
        planned = ExpenseBreakdown(home),
        cashOnHand = Totals(home),
        cashAfterPlanned = Totals(home),
        withdrawals = Totals(home),
        deposits = Totals(home),
        cashCounts = Totals(home);

  factory Balance.from({
    required List<Currency> currencies,
    required Iterable<MoneyTransaction> transactions,
  }) {
    final home = homeCurrencyOf(currencies);
    final balance = Balance._(home);
    final byCode = {for (final c in currencies) c.shortName: c};
    final averaged = ExpenseBreakdown(home);

    DateTime? first;
    DateTime? last;

    for (final t in transactions) {
      final amount = CurrencyValue(t.amount, byCode[t.currency]);
      final code = t.currency;

      // Planned expenses are future costs: they must not affect actual figures or the day range.
      if (t.isPlanned && t.isExpense) {
        balance.planned.add(code, amount, isCash: t.isCash, method: t.method.trim());
        if (t.isCash) balance.cashAfterPlanned.add(code, amount, sign: -1);
        continue;
      }

      first = first == null || t.date.isBefore(first) ? t.date : first;
      last = last == null || t.date.isAfter(last) ? t.date : last;

      switch (t.type) {
        case TransactionKind.expense:
          final method = t.method.trim();
          balance.expenses.add(code, amount, isCash: t.isCash, method: method);
          if (t.isCash) balance.cashOnHand.add(code, amount, sign: -1);
          if (t.includeInAverage) {
            averaged.add(code, amount, isCash: t.isCash, method: method);
          }
        case TransactionKind.withdrawal:
          balance.cashOnHand.add(code, amount);
          balance.withdrawals.add(code, amount);
          final withdrawalMethod = t.method.trim().isEmpty ? 'Other' : t.method.trim();
          balance.withdrawalsByMethod
              .putIfAbsent(withdrawalMethod, () => Totals(home))
              .add(code, amount);
        case TransactionKind.deposit:
          balance.cashOnHand.add(code, amount);
          balance.deposits.add(code, amount);
        case TransactionKind.cashCount:
          // The stored amount is the difference to the expected cash; a shortfall is an expense.
          balance.cashOnHand.add(code, amount);
          balance.cashCounts.add(code, amount);
          balance.expenses.add(code, amount, isCash: true, sign: -1);
      }
    }

    balance.cashOnHand.byCurrency.forEach((code, v) => balance.cashAfterPlanned.add(code, v));

    if (first != null && last != null) {
      final start = DateTime.utc(first.year, first.month, first.day);
      final end = DateTime.utc(last.year, last.month, last.day);
      balance.days = end.difference(start).inDays + 1;
    }
    balance.dailyAverage = averaged.scaled(1 / balance.days);
    return balance;
  }

  static Currency? homeCurrencyOf(List<Currency> currencies) {
    for (final c in currencies) {
      if (c.isHome) return c;
    }
    return currencies.firstOrNull;
  }

  final Currency? home;
  final ExpenseBreakdown expenses;
  ExpenseBreakdown dailyAverage;
  final ExpenseBreakdown planned;
  final Totals cashOnHand;
  final Totals cashAfterPlanned;
  final Totals withdrawals;
  final Map<String, Totals> withdrawalsByMethod = {};
  final Totals deposits;
  final Totals cashCounts;
  int days = 1;

  double cashIn(String currencyCode) => cashOnHand.byCurrency[currencyCode]?.value ?? 0;
}
