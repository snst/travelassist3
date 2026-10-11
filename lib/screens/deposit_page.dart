import 'package:flutter/material.dart';
import '../balance/balance.dart';
import '../calculator/currency_value.dart';
import '../database/database.dart';
import '../widgets/comment_input.dart';
import '../widgets/currency_amount_input.dart';
import '../widgets/date_time_picker_tile.dart';
import '../widgets/transaction_data_scaffold.dart';

class DepositPage extends StatelessWidget {
  final AppDatabase database;

  const DepositPage({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return TransactionDataScaffold(
      database: database,
      title: 'Add Deposit',
      builder: (context, currencies, transactions) => _DepositForm(
        database: database,
        currencies: currencies,
        transactions: transactions,
      ),
    );
  }
}

class _DepositForm extends StatefulWidget {
  final AppDatabase database;
  final List<Currency> currencies;

  /// All stored transactions, newest first; used to pick the default currency.
  final List<MoneyTransaction> transactions;

  const _DepositForm({
    required this.database,
    required this.currencies,
    required this.transactions,
  });

  @override
  State<_DepositForm> createState() => _DepositFormState();
}

class _DepositFormState extends State<_DepositForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();
  late String _currencyCode;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final codes = widget.currencies.map((c) => c.shortName).toList();
    final lastUsed =
        widget.transactions.isNotEmpty ? widget.transactions.first.currency : null;
    _currencyCode = lastUsed != null && codes.contains(lastUsed)
        ? lastUsed
        : Balance.homeCurrencyOf(widget.currencies)?.shortName ?? codes.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.database.addTransaction(
      kind: TransactionKind.deposit,
      amount: CurrencyValue.safeConvertToDouble(_amountController.text),
      currency: _currencyCode,
      comment: _commentController.text.trim(),
      date: _date,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final codes = widget.currencies.map((c) => c.shortName).toList();

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          CurrencyAmountInput(
            currencyCodes: codes,
            selectedCurrencyCode: _currencyCode,
            onCurrencySelected: (code) => setState(() => _currencyCode = code),
            amountController: _amountController,
            onAmountChanged: null,
          ),
          const SizedBox(height: 20),
          CommentInput(controller: _commentController),
          const SizedBox(height: 8),
          DateTimePickerTile(
            value: _date,
            onChanged: (date) => setState(() => _date = date),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Deposit'),
          ),
        ],
      ),
    );
  }
}
