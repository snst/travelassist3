import 'package:flutter/material.dart';
import '../database/database.dart';

IconData transactionIcon(TransactionKind kind) {
  switch (kind) {
    case TransactionKind.expense:
      return Icons.shopping_bag_outlined;
    case TransactionKind.withdrawal:
      return Icons.atm;
    case TransactionKind.cashCount:
      return Icons.fact_check_outlined;
    case TransactionKind.deposit:
      return Icons.savings_outlined;
    case TransactionKind.hotel:
      return Icons.hotel;
  }
}

String transactionLabel(TransactionKind kind) {
  switch (kind) {
    case TransactionKind.expense:
      return 'Expense';
    case TransactionKind.withdrawal:
      return 'ATM';
    case TransactionKind.cashCount:
      return 'Count';
    case TransactionKind.deposit:
      return 'Deposit';
    case TransactionKind.hotel:
      return 'Hotel';
  }
}
