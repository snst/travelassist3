import 'package:flutter/material.dart';
import '../balance/balance.dart';
import '../calculator/currency_value.dart';
import '../database/database.dart';
import '../utils/date_format.dart';
import '../utils/transaction_kind.dart';
import '../widgets/hotel_state_badge.dart';
import '../widgets/tag_filter_bar.dart';
import 'balance_page.dart';
import 'transaction_navigation.dart';

class TransactionListPage extends StatelessWidget {
  final AppDatabase database;

  const TransactionListPage({super.key, required this.database});

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
                title: const Text('Entries'),
                backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                actions: [
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
              floatingActionButton: loading || currencies.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: FloatingActionButton(
                        heroTag: 'expenses_fab',
                        tooltip: 'Add Entry',
                        onPressed: () => showNewEntryPicker(context, database),
                        child: const Icon(Icons.add),
                      ),
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

  Future<void> _delete(BuildContext context, MoneyTransaction t) async {
    final messenger = ScaffoldMessenger.of(context);
    await widget.database.deleteTransaction(t.id);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => widget.database.restoreTransaction(t),
        ),
      ),
    );
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
      return !t.isSpending || _selectedTags.every(t.tagList.contains);
    }).toList();

    final tagSet = <String>{..._selectedTags};
    for (final t in filteredTransactions.where((t) => t.isSpending)) {
      tagSet.addAll(t.tagList);
    }
    final sortedTags = tagSet.toList()..sort();

    // Entries are sorted newest first; flatten into day headers and entries.
    final dayExpenses = <DateTime, CurrencyValue>{};
    for (final t
        in filteredTransactions.where((t) => t.isSpending && !t.isPending)) {
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
              ? const Center(child: Text('No expenses match the selected tags.'))
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
                      final isToday = row.day.year == today.year &&
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
                      onTap: () =>
                          openTransaction(context, widget.database, t),
                      onDelete: () => _delete(context, t),
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
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EntryTile({
    required this.transaction,
    required this.home,
    required this.onTap,
    required this.onDelete,
  });

  String get _title {
    switch (transaction.type) {
      case TransactionKind.expense:
        return transaction.tagList.isNotEmpty
            ? transaction.tagList.map((t) => '#$t').join(' ')
            : 'Expense';
      case TransactionKind.withdrawal:
        return 'Withdrawal';
      case TransactionKind.deposit:
        return 'Deposit';
      case TransactionKind.cashCount:
        return 'Cash Count';
      case TransactionKind.hotel:
        return transaction.tagList.isNotEmpty
            ? 'Hotel ${transaction.tagList.map((t) => '#$t').join(' ')}'
            : 'Hotel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = transaction;
    final detailStyle = TextStyle(color: scheme.outline, fontSize: 13);
    final isOutgoing = t.isSpending;
    final sign = t.isCashCount && t.amount > 0 ? '+' : '';
    final isForeign = home.currency == null || home.currencyString != t.currency;
    final details = [
      if (!t.isHotel && t.isPlanned)
        'Planned'
      else if (!t.isHotel && t.isBooked)
        'Booked',
      if (t.isSpending || t.isWithdrawal) (t.method.isEmpty ? cashMethod : t.method),
      if (t.comment.isNotEmpty) t.comment,
    ].join(' · ');

    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        color: t.isHotel && t.isBooked
            ? scheme.primaryContainer
            : t.isPending
                ? scheme.tertiaryContainer
                : null,
        shape: t.isHotel
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: scheme.secondary, width: 1.5),
              )
            : null,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor:
                t.isHotel ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
            child: Icon(
              t.isHotel
                  ? Icons.hotel
                  : t.isPlanned
                      ? Icons.schedule
                      : transactionIcon(t.type),
            ),
          ),
          title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: t.isHotel
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        HotelStateBadge(state: t.transactionState),
                        if (t.days > 0)
                          Text(
                            t.days == 1 ? '1 day' : '${t.days} days',
                            style: detailStyle.copyWith(fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                    if (details.isNotEmpty)
                      Text(details, maxLines: 2, overflow: TextOverflow.ellipsis, style: detailStyle),
                  ],
                )
              : details.isEmpty
                  ? null
                  : Text(details, maxLines: 2, overflow: TextOverflow.ellipsis, style: detailStyle),
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
                Text('$sign${t.amount.toStringAsFixed(2)} ${t.currency}', style: detailStyle),
            ],
          ),
        ),
      ),
    );
  }
}
