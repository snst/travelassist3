import 'package:flutter/material.dart';
import '../database/database.dart';

/// Scaffold that loads currencies and transactions and handles the loading and
/// "no currencies" states, so [builder] only runs when there is data to show.
class TransactionDataScaffold extends StatelessWidget {
  final AppDatabase database;
  final String title;
  final List<Widget> actions;
  final Widget Function(
    BuildContext context,
    List<Currency> currencies,
    List<MoneyTransaction> transactions,
  ) builder;

  const TransactionDataScaffold({
    super.key,
    required this.database,
    required this.title,
    this.actions = const [],
    required this.builder,
  });

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

            return Scaffold(
              appBar: AppBar(
                title: Text(title),
                actions: actions,
                backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                      : builder(context, currencies, snapshot.data!),
            );
          },
        );
      },
    );
  }
}
