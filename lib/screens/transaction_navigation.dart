import 'package:flutter/material.dart';
import '../database/database.dart';
import '../utils/transaction_kind.dart';
import 'cash_count_page.dart';
import 'deposit_page.dart';
import 'expense_page.dart';
import 'hotel_page.dart';
import 'withdrawal_page.dart';

/// The entry page for [kind]; edits [transaction] when given, otherwise adds a new entry.
Widget transactionPage(
  AppDatabase database,
  TransactionKind kind, {
  MoneyTransaction? transaction,
}) {
  switch (kind) {
    case TransactionKind.expense:
      return ExpensePage(database: database, transaction: transaction);
    case TransactionKind.withdrawal:
      return WithdrawalPage(database: database, transaction: transaction);
    case TransactionKind.deposit:
      return DepositPage(database: database, transaction: transaction);
    case TransactionKind.cashCount:
      return CashCountPage(database: database, transaction: transaction);
    case TransactionKind.hotel:
      return HotelPage(database: database, transaction: transaction);
  }
}

void openTransaction(
  BuildContext context,
  AppDatabase database,
  MoneyTransaction transaction,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          transactionPage(database, transaction.type, transaction: transaction),
    ),
  );
}

/// Lets the user pick the kind of entry to add, then opens its page.
void showNewEntryPicker(BuildContext context, AppDatabase database) {
  final navigator = Navigator.of(context);
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final kind in TransactionKind.values)
            ListTile(
              leading: Icon(transactionIcon(kind)),
              title: Text(transactionLabel(kind)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => transactionPage(database, kind),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}
