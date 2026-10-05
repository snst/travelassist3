import 'package:flutter/material.dart';
import '../balance/balance.dart';
import '../calculator/currency_value.dart';

String _nativeText(String code, CurrencyValue v) => '${v.valueString} $code';

String _homeText(CurrencyValue v) => v.toString();

class BalanceView extends StatelessWidget {
  final Balance balance;

  const BalanceView({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expenseColor = scheme.error;
    const cashColor = Colors.green;
    final neutral = scheme.primary;

    final expenses = balance.expenses;
    final average = balance.dailyAverage;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
      children: [
        _Section(
          title: 'Cash on hand',
          icon: Icons.account_balance_wallet_outlined,
          color: cashColor,
          total: balance.cashOnHand.total,
          children: _currencyLines(balance.cashOnHand, balance),
        ),
        _Section(
          title: 'Expenses',
          icon: Icons.shopping_bag_outlined,
          color: expenseColor,
          total: expenses.total.total,
          children: _expenseLines(expenses, balance),
        ),
        if (!balance.planned.total.isEmpty) ...[
          _Section(
            title: 'Planned expenses',
            icon: Icons.schedule,
            color: expenseColor,
            total: balance.planned.total.total,
            children: _expenseLines(balance.planned, balance),
          ),
          _Section(
            title: 'Cash after planned',
            icon: Icons.account_balance_wallet,
            color: cashColor,
            total: balance.cashAfterPlanned.total,
            children: _currencyLines(balance.cashAfterPlanned, balance),
          ),
        ],
        if (!average.total.isEmpty)
          _Section(
            title: 'Daily average (${balance.days} ${balance.days == 1 ? 'day' : 'days'})',
            icon: Icons.trending_up,
            color: expenseColor,
            total: average.total.total,
            children: _expenseLines(average, balance),
          ),
        if (!balance.withdrawals.isEmpty)
          _Section(
            title: 'Withdrawals',
            icon: Icons.atm,
            color: neutral,
            total: balance.withdrawals.total,
            children: [
              for (final entry in _sorted(balance.withdrawalsByMethod)) ...[
                _Line(label: entry.key, home: _homeText(entry.value.total), style: _LineStyle.subheader),
                ..._currencyLines(entry.value, balance),
              ],
            ],
          ),
        if (!balance.deposits.isEmpty)
          _Section(
            title: 'Cash deposits',
            icon: Icons.savings_outlined,
            color: neutral,
            total: balance.deposits.total,
            children: _currencyLines(balance.deposits, balance),
          ),
        if (!balance.cashCounts.isEmpty)
          _Section(
            title: 'Cash count corrections',
            icon: Icons.fact_check_outlined,
            color: neutral,
            total: balance.cashCounts.total,
            children: _currencyLines(balance.cashCounts, balance),
          ),
      ],
    );
  }

  static List<MapEntry<String, T>> _sorted<T>(Map<String, T> map) =>
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

  static List<Widget> _currencyLines(Totals totals, Balance balance) {
    final lines = <Widget>[];
    for (final entry in _sorted(totals.byCurrency)) {
      final value = entry.value;
      final isHome = balance.home != null && value.currency?.id == balance.home!.id;
      if (value.value == 0) continue;
      lines.add(
        _Line(
          native: isHome ? null : _nativeText(entry.key, value),
          home: _homeText(value.convertTo(balance.home)),
        ),
      );
    }
    return lines;
  }

  static List<Widget> _expenseLines(ExpenseBreakdown e, Balance balance) {
    return [
      if (!e.cash.isEmpty) ...[
        _Line(label: 'Cash', home: _homeText(e.cash.total), style: _LineStyle.subheader),
        ..._currencyLines(e.cash, balance),
      ],
      if (!e.card.isEmpty) ...[
        _Line(label: 'Card', home: _homeText(e.card.total), style: _LineStyle.subheader),
        for (final entry in _sorted(e.cardByMethod)) ...[
          _Line(
            label: entry.key.isEmpty ? 'Other' : entry.key,
            home: _homeText(entry.value.total),
            style: _LineStyle.method,
          ),
          ..._currencyLines(entry.value, balance),
        ],
      ],
    ];
  }
}

enum _LineStyle { normal, subheader, method }

class _Line extends StatelessWidget {
  final String? label;
  final String? native;
  final String home;
  final _LineStyle style;

  const _Line({this.label, this.native, required this.home, this.style = _LineStyle.normal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bold = style != _LineStyle.normal;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
      color: style == _LineStyle.normal ? theme.colorScheme.onSurfaceVariant : null,
    );
    return Padding(
      padding: EdgeInsets.only(
        left: style == _LineStyle.normal ? 24 : (style == _LineStyle.method ? 12 : 0),
        top: style == _LineStyle.subheader ? 8 : 2,
        bottom: 2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label ?? native ?? '', style: textStyle, overflow: TextOverflow.ellipsis),
          ),
          if (label != null && native != null) Text(native!, style: textStyle),
          const SizedBox(width: 12),
          Text(home, style: textStyle, textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final CurrencyValue total;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.total,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                  ),
                ),
                Text(
                  total.toString(),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
                ),
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
