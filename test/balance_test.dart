import 'package:flutter_test/flutter_test.dart';
import 'package:travelassist3/balance/balance.dart';
import 'package:travelassist3/database/database.dart';

void main() {
  const eur = Currency(
    id: 1,
    name: 'Euro',
    shortName: 'EUR',
    rate: 1,
    isHome: true,
  );
  const usd = Currency(
    id: 2,
    name: 'US Dollar',
    shortName: 'USD',
    rate: 2,
    isHome: false,
  );

  var nextId = 0;
  MoneyTransaction tx(
    TransactionKind kind,
    double amount,
    String currency, {
    String method = '',
    DateTime? date,
    int days = 1,
    bool planned = false,
  }) {
    return MoneyTransaction(
      id: ++nextId,
      kind: kind.index,
      amount: amount,
      currency: currency,
      method: method,
      comment: '',
      tags: '',
      date: date ?? DateTime(2026, 5, 1, 12),
      days: days,
      planned: planned,
      link: '',
      showInCalendar: false,
    );
  }

  test('Empty balance is zero with a single day', () {
    final balance = Balance.from(currencies: [eur, usd], transactions: []);

    expect(balance.home, eur);
    expect(balance.cashOnHand.total.value, 0);
    expect(balance.expenses.total.total.value, 0);
    expect(balance.days, 1);
  });

  test('Cash flow, card expenses and cash count', () {
    final day1 = DateTime(2026, 5, 1, 9);
    final day2 = DateTime(2026, 5, 2, 18);
    final balance = Balance.from(
      currencies: [eur, usd],
      transactions: [
        tx(TransactionKind.withdrawal, 200, 'USD', method: 'Visa', date: day1),
        tx(TransactionKind.expense, 50, 'USD', method: cashMethod, date: day1),
        tx(
          TransactionKind.expense,
          10,
          'EUR',
          method: 'Visa',
          date: day2,
          days: 0,
        ),
        // Counted 140 USD while 150 USD were expected.
        tx(TransactionKind.cashCount, -10, 'USD', date: day2),
      ],
    );

    expect(balance.cashIn('USD'), 140);
    expect(balance.cashOnHand.total.value, 70); // 140 USD in EUR
    expect(balance.withdrawals.total.value, 100);
    expect(balance.withdrawalsByMethod['Visa']!.total.value, 100);

    // 25 EUR cash + 10 EUR card + 5 EUR missing cash
    expect(balance.expenses.total.total.value, 40);
    expect(balance.expenses.card.total.value, 10);
    expect(balance.expenses.cardByMethod['Visa']!.total.value, 10);
    expect(balance.expenses.cash.byCurrency['USD']!.value, 60);

    // Only the first expense counts towards the daily average, spread over 2 days.
    expect(balance.days, 2);
    expect(balance.dailyAverage.total.total.value, 12.5);
  });

  test('Planned expenses stay out of current figures', () {
    final balance = Balance.from(
      currencies: [eur, usd],
      transactions: [
        tx(TransactionKind.withdrawal, 100, 'EUR', method: 'Visa'),
        tx(TransactionKind.expense, 20, 'EUR', method: cashMethod),
        tx(
          TransactionKind.expense,
          30,
          'EUR',
          method: cashMethod,
          planned: true,
          date: DateTime(2026, 5, 10),
        ),
        tx(
          TransactionKind.expense,
          40,
          'EUR',
          method: 'Visa',
          planned: true,
          date: DateTime(2026, 5, 10),
        ),
      ],
    );

    expect(balance.cashOnHand.total.value, 80);
    expect(balance.expenses.total.total.value, 20);
    expect(balance.planned.total.total.value, 70);
    expect(balance.planned.card.total.value, 40);
    expect(balance.cashAfterPlanned.total.value, 50);
    expect(balance.days, 1);
  });

  test('Planned hotels stay out of actual expenses', () {
    final balance = Balance.from(
      currencies: [eur, usd],
      transactions: [
        tx(
          TransactionKind.hotel,
          100,
          'EUR',
          method: 'Visa',
          planned: true,
          date: DateTime(2026, 5, 10),
        ),
        tx(
          TransactionKind.hotel,
          200,
          'EUR',
          method: 'Visa',
          date: DateTime(2026, 5, 10),
        ),
        tx(TransactionKind.hotel, 50, 'EUR', method: 'Visa'),
      ],
    );

    expect(balance.planned.total.total.value, 100);
    expect(balance.expenses.total.total.value, 250);
    expect(balance.days, 10);
  });

  test('Expense counted for several days extends the average range', () {
    final balance = Balance.from(
      currencies: [eur, usd],
      transactions: [
        tx(TransactionKind.expense, 30, 'EUR', method: cashMethod, days: 3),
      ],
    );

    expect(balance.days, 3);
    expect(balance.dailyAverage.total.total.value, 10);
  });

  test('Unknown currency is kept without conversion', () {
    final balance = Balance.from(
      currencies: [eur],
      transactions: [
        tx(TransactionKind.expense, 12, 'XYZ', method: cashMethod),
      ],
    );

    expect(balance.expenses.total.total.value, 12);
    expect(balance.cashIn('XYZ'), -12);
  });
}
