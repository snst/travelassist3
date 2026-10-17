import 'package:flutter/material.dart';
import '../balance/balance.dart';
import '../database/database.dart';
import 'balance_view.dart';
import 'expenses_list_page.dart';

class BalancePage extends StatelessWidget {
  final AppDatabase database;

  const BalancePage({super.key, required this.database});

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
                title: const Text('Balance'),
                backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.receipt_long),
                    tooltip: 'View Entries',
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => ExpensesListPage(database: database),
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
                      : BalanceView(
                          balance: Balance.from(
                            currencies: currencies,
                            transactions: transactions,
                          ),
                        ),
            );
          },
        );
      },
    );
  }
}
