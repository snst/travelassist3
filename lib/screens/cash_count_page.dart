import 'package:flutter/material.dart';
import '../balance/balance.dart';
import '../calculator/currency_value.dart';
import '../database/database.dart';
import '../widgets/cash_count_hint.dart';
import '../widgets/comment_input.dart';
import '../widgets/currency_amount_input.dart';
import '../widgets/date_time_picker_tile.dart';
import '../widgets/transaction_data_scaffold.dart';

class CashCountPage extends StatelessWidget {
  final AppDatabase database;

  const CashCountPage({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return TransactionDataScaffold(
      database: database,
      title: 'Count Cash',
      builder: (context, currencies, transactions) => _CashCountForm(
        database: database,
        currencies: currencies,
        transactions: transactions,
      ),
    );
  }
}

class _CashCountForm extends StatefulWidget {
  final AppDatabase database;
  final List<Currency> currencies;

  /// All stored transactions, newest first; used for the expected cash and default currency.
  final List<MoneyTransaction> transactions;

  const _CashCountForm({
    required this.database,
    required this.currencies,
    required this.transactions,
  });

  @override
  State<_CashCountForm> createState() => _CashCountFormState();
}

class _CashCountFormState extends State<_CashCountForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();
  late String _currencyCode;
  DateTime _date = DateTime.now();

  Balance get _balance => Balance.from(
        currencies: widget.currencies,
        transactions: widget.transactions,
      );

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

  // A count is stored as the difference to the expected cash.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final entered = CurrencyValue.safeConvertToDouble(_amountController.text);
    final counted = 'Counted: ${entered.toStringAsFixed(2)} $_currencyCode';
    final comment = _commentController.text.trim();
    await widget.database.addTransaction(
      kind: TransactionKind.cashCount,
      amount: entered - _balance.cashIn(_currencyCode),
      currency: _currencyCode,
      comment: comment.isEmpty ? counted : '$counted - $comment',
      date: _date,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final codes = widget.currencies.map((c) => c.shortName).toList();
    final hasInput = _amountController.text.trim().isNotEmpty;

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
            amountLabel: 'Counted cash',
            onAmountChanged: (_) => setState(() {}),
            amountValidator: (value) =>
                (value ?? '').trim().isEmpty ? 'Please enter an amount' : null,
          ),
          CashCountHint(
            expected: _balance.cashIn(_currencyCode),
            currencyCode: _currencyCode,
            counted: hasInput
                ? CurrencyValue.safeConvertToDouble(_amountController.text)
                : null,
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
            label: const Text('Save Count'),
          ),
        ],
      ),
    );
  }
}
