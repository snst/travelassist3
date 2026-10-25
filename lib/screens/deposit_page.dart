import 'package:flutter/material.dart';
import '../calculator/currency_value.dart';
import '../database/database.dart';
import '../utils/currency_codes.dart';
import '../utils/transaction_kind.dart';
import '../widgets/comment_input.dart';
import '../widgets/currency_amount_input.dart';
import '../widgets/date_time_picker_tile.dart';
import '../widgets/delete_entry_button.dart';
import '../widgets/transaction_data_scaffold.dart';

class DepositPage extends StatefulWidget {
  final AppDatabase database;

  /// An existing deposit to edit; null to add a new one.
  final MoneyTransaction? transaction;

  const DepositPage({super.key, required this.database, this.transaction});

  @override
  State<DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends State<DepositPage> {
  final _formKey = GlobalKey<_DepositFormState>();

  @override
  Widget build(BuildContext context) {
    final existing = widget.transaction;
    return TransactionDataScaffold(
      database: widget.database,
      title: existing == null
          ? 'Add Deposit'
          : 'Edit ${transactionLabel(TransactionKind.deposit)}',
      actions: [
        if (existing != null)
          DeleteEntryButton(database: widget.database, transaction: existing),
        SizedBox(width:16),
        IconButton(
          tooltip: existing == null ? 'Save Deposit' : 'Update Deposit',
          onPressed: () => _formKey.currentState?._save(),
          icon: const Icon(Icons.save),
        ),
      ],
      builder: (context, currencies, transactions) => _DepositForm(
        key: _formKey,
        database: widget.database,
        currencies: currencies,
        transactions: transactions,
        existing: existing,
      ),
    );
  }
}

class _DepositForm extends StatefulWidget {
  final AppDatabase database;
  final List<Currency> currencies;

  /// All stored transactions, newest first; used to pick the default currency.
  final List<MoneyTransaction> transactions;
  final MoneyTransaction? existing;

  const _DepositForm({
    super.key,
    required this.database,
    required this.currencies,
    required this.transactions,
    required this.existing,
  });

  @override
  State<_DepositForm> createState() => _DepositFormState();
}

class _DepositFormState extends State<_DepositForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _commentController;
  late String _currencyCode;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _amountController = TextEditingController(
      text: t == null ? '' : t.amount.toStringAsFixed(2),
    );
    _commentController = TextEditingController(text: t?.comment ?? '');
    _currencyCode = t?.currency ??
        defaultCurrencyCode(widget.currencies, widget.transactions);
    _date = t?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = CurrencyValue.safeConvertToDouble(_amountController.text);
    final comment = _commentController.text.trim();
    final existing = widget.existing;
    if (existing == null) {
      await widget.database.addTransaction(
        kind: TransactionKind.deposit,
        amount: amount,
        currency: _currencyCode,
        comment: comment,
        date: _date,
      );
    } else {
      await widget.database.updateTransactionEntry(
        existing.copyWith(
          amount: amount,
          currency: _currencyCode,
          comment: comment,
          date: _date,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final codes = currencyCodesWithSelected(widget.currencies, _currencyCode);

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
            autofocus: widget.existing == null,
            onAmountChanged: null,
          ),
          CommentInput(controller: _commentController),
          DateTimePickerTile(
            value: _date,
            onChanged: (date) => setState(() => _date = date),
          ),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(widget.existing == null ? 'Save Deposit' : 'Update Deposit'),
          ),
        ],
      ),
    );
  }
}
