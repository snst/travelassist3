import 'package:flutter/material.dart';

import '../balance/balance.dart';
import '../calculator/currency_value.dart';
import '../database/database.dart';
import '../utils/date_format.dart';
import '../utils/transaction_kind.dart';
import '../widgets/tag_filter_bar.dart';
import 'balance_page.dart';
import 'calendar_page.dart';
import 'transaction_navigation.dart';

class ExpensesListPage extends StatelessWidget {
  final AppDatabase database;

  const ExpensesListPage({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Currency>>(
      stream: database.watchAllCurrencies(),
      builder: (context, currencySnapshot) {
        return StreamBuilder<List<MoneyTransaction>>(
          stream: database.watchAllTransactions(),
          builder: (context, snapshot) {
            final loading = !currencySnapshot.hasData || !snapshot.hasData;
            final currencies = currencySnapshot.data ?? [];
            final transactions = snapshot.data ?? [];

            return Scaffold(
              appBar: AppBar(
                title: const Text('Expenses'),
                backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.calendar_month),
                    tooltip: 'View Calendar',
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) =>
                              CalendarPage(database: database),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.pie_chart),
                    tooltip: 'View Balance',
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => BalancePage(database: database),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 16),
                  if (!loading && currencies.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Add Entry',
                      onPressed: () => showNewEntryPicker(context, database),
                    ),
                ],
              ),
              body: loading
                  ? const Center(child: CircularProgressIndicator())
                  : currencies.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No currencies available.\nPlease add currencies in Currencies first.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _EntriesView(
                      database: database,
                      currencies: currencies,
                      transactions: transactions,
                    ),
            );
          },
        );
      },
    );
  }
}

class _EntriesView extends StatefulWidget {
  final AppDatabase database;
  final List<Currency> currencies;
  final List<MoneyTransaction> transactions;

  const _EntriesView({
    required this.database,
    required this.currencies,
    required this.transactions,
  });

  @override
  State<_EntriesView> createState() => _EntriesViewState();
}

class _EntriesViewState extends State<_EntriesView> {
  final List<String> _selectedTags = [];

  void _toggleTagFilter(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _clearFilters() {
    setState(_selectedTags.clear);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No entries yet.', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    final home = Balance.homeCurrencyOf(widget.currencies);
    final byCode = {for (final c in widget.currencies) c.shortName: c};
    CurrencyValue toHome(MoneyTransaction t) =>
        CurrencyValue(t.amount, byCode[t.currency]).convertTo(home);

    final filteredTransactions = widget.transactions.where((t) {
      return _selectedTags.isEmpty || _selectedTags.every(t.tagList.contains);
    }).toList();

    final tagSet = <String>{..._selectedTags};
    for (final t in filteredTransactions) {
      tagSet.addAll(t.tagList);
    }
    final sortedTags = tagSet.toList()..sort();

    // Entries are sorted newest first; flatten into day headers and entries.
    final dayExpenses = <DateTime, CurrencyValue>{};
    for (final t in filteredTransactions.where(
      (t) => t.isSpending && !t.isPlanned,
    )) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      dayExpenses.putIfAbsent(day, () => CurrencyValue(0, home)).add(toHome(t));
    }

    final rows = <Object>[];
    DateTime? currentDay;
    for (final t in filteredTransactions) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (day != currentDay) {
        currentDay = day;
        rows.add(_DayHeader(day, dayExpenses[day] ?? CurrencyValue(0, home)));
      }
      rows.add(t);
    }

    return Column(
      children: [
        Expanded(
          child: rows.isEmpty
              ? const Center(
                  child: Text('No expenses match the selected tags.'),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    88 + MediaQuery.of(context).padding.bottom,
                  ),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    if (row is _DayHeader) {
                      final theme = Theme.of(context);
                      final today = DateTime.now();
                      final isToday =
                          row.day.year == today.year &&
                          row.day.month == today.month &&
                          row.day.day == today.day;
                      final dayStyle = isToday
                          ? theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            )
                          : theme.textTheme.labelLarge;

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 2),
                        child: Container(
                          padding: isToday
                              ? const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                )
                              : EdgeInsets.zero,
                          decoration: isToday
                              ? BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                )
                              : null,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formatDay(row.day), style: dayStyle),
                              if (row.expenses.value != 0)
                                Text(row.expenses.toString(), style: dayStyle),
                            ],
                          ),
                        ),
                      );
                    }
                    final t = row as MoneyTransaction;
                    return _EntryTile(
                      transaction: t,
                      home: toHome(t),
                      selectedTags: _selectedTags,
                      onTagSelected: _toggleTagFilter,
                      onTap: () => openTransaction(context, widget.database, t),
                    );
                  },
                ),
        ),
        TagFilterBar(
          tags: sortedTags,
          selectedTags: _selectedTags,
          onTagSelected: _toggleTagFilter,
          onClear: _clearFilters,
        ),
      ],
    );
  }
}

class _DayHeader {
  final DateTime day;
  final CurrencyValue expenses;

  _DayHeader(this.day, this.expenses);
}

class _EntryTile extends StatelessWidget {
  final MoneyTransaction transaction;
  final CurrencyValue home;
  final List<String> selectedTags;
  final ValueChanged<String> onTagSelected;
  final VoidCallback onTap;

  const _EntryTile({
    required this.transaction,
    required this.home,
    required this.selectedTags,
    required this.onTagSelected,
    required this.onTap,
  });

  String get _title {
    switch (transaction.type) {
      case TransactionKind.expense:
        return 'Expense';
      case TransactionKind.withdrawal:
        return 'ATM';
      case TransactionKind.deposit:
        return 'Deposit';
      case TransactionKind.cashCount:
        return 'Cash Count';
      case TransactionKind.hotel:
        return 'Hotel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleStyle =
        ListTileTheme.of(context).titleTextStyle ??
        Theme.of(context).textTheme.titleMedium;
    final t = transaction;
    final detailStyle = TextStyle(color: scheme.primary, fontSize: 15);
    final isBookedHotel = t.isHotel && t.tagList.contains('booked');
    final isOutgoing = t.isSpending;
    final sign = t.isCashCount && t.amount > 0 ? '+' : '';
    final isForeign =
        home.currency == null || home.currencyString != t.currency;
    final hasInfo = t.comment.isNotEmpty;
    final paymentMethod = t.isSpending || t.isWithdrawal
        ? (t.method.isEmpty ? cashMethod : t.method)
        : null;
    const hiddenTags = {hotelTag, expenseTag, atmTag, countTag, calendarTag};
    final visibleTags = t.tagList
        .where((tag) => !hiddenTags.contains(tag.toLowerCase()))
        .toList();
    final subtitle = <Widget>[
      if (t.isHotel) const SizedBox(height: 2),
      if (visibleTags.isNotEmpty || paymentMethod != null)
        Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            ...visibleTags.map((tag) {
              final isSelected = selectedTags.contains(tag);
              return InkWell(
                onTap: () => onTagSelected(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }),
            if (paymentMethod != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  paymentMethod,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
    ];

    final leading = t.isHotel
        ? Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                backgroundColor: t.isPlanned
                    ? scheme.errorContainer
                    : scheme.secondaryContainer,
                child: Icon(
                  Icons.hotel,
                  color: t.isPlanned ? scheme.onErrorContainer : null,
                ),
              ),
              if (t.days > 0)
                Positioned(
                  bottom: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isBookedHotel
                          ? Colors.green.shade700
                          : scheme.secondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${t.days}',
                      style: TextStyle(
                        color: isBookedHotel
                            ? Colors.white
                            : scheme.onSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          )
        : CircleAvatar(
            backgroundColor: t.isPlanned
                ? scheme.errorContainer
                : scheme.surfaceContainerHigh,
            child: Icon(
              transactionIcon(t.type),
              color: t.isPlanned ? scheme.onErrorContainer : null,
            ),
          );

    return Card(
      key: ValueKey(t.id),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: leading,
        title: Text(
          hasInfo ? t.comment : _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        subtitle: subtitle.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: subtitle,
              ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$sign${home.toString()}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isOutgoing ? scheme.error : null,
              ),
            ),
            if (isForeign)
              Text(
                '$sign${t.amount.toStringAsFixed(2)} ${t.currency}',
                style: detailStyle,
              ),
          ],
        ),
      ),
    );
  }
}
