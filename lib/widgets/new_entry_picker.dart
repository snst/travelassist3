import 'package:flutter/material.dart';

import '../database/database.dart';
import '../utils/transaction_kind.dart';

class NewEntryPicker extends StatelessWidget {
  final ValueChanged<TransactionKind> onSelected;

  const NewEntryPicker({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final kind in TransactionKind.values)
            ListTile(
              leading: Icon(transactionIcon(kind)),
              title: Text(transactionLabel(kind)),
              onTap: () => onSelected(kind),
            ),
        ],
      ),
    );
  }
}
