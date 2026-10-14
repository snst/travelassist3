import 'package:flutter/material.dart';
import '../balance/balance.dart';
import '../calculator/currency_value.dart';
import '../database/database.dart';
import '../utils/currency_codes.dart';
import '../utils/transaction_kind.dart';
import '../widgets/cash_count_hint.dart';
import '../widgets/comment_input.dart';
import '../widgets/currency_amount_input.dart';
import '../widgets/date_time_picker_tile.dart';
import '../widgets/delete_entry_button.dart';
import '../widgets/transaction_data_scaffold.dart';

class CashCountPage extends StatefulWidget {
  final AppDatabase database;

  /// An existing count to edit; null to add a new one.
  final MoneyTransaction? transaction;

  const CashCountPage({super.key, required this.database, this.transaction});

  @override
  State<CashCountPage> createState() => _CashCountPageState();
}

class _CashCountPageState extends State<CashCountPage> {
  final _formKey = GlobalKey<_CashCountFormState>();

  @override
  Widget build(BuildContext context) {
    final existing = widget.transaction;
    return TransactionDataScaffold(
      database: widget.database,
      title: existing == null
          ? 'Count Cash'
          : 'Edit ${transactionLabel(TransactionKind.cashCount)}',
      actions: [
        if (existing != null)
          DeleteEntryButton(database: widget.database, transaction: existing),
        IconButton(
          tooltip: existing == null ? 'Save Count' : 'Update Count',
          onPressed: () => _formKey.currentState?._save(),
          icon: const Icon(Icons.save),
        ),
      ],
      builder: (context, currencies, transactions) => _CashCountForm(
        key: _formKey,
        database: widget.database,
        currencies: currencies,
        transactions: transactions,
        existing: existing,
      ),
    );
  }
}

class _CashCountForm extends StatefulWidget {
  final AppDatabase database;
  final List<Currency> currencies;

  /// All stored transactions, newest first; used for the expected cash and default currency.
  final List<MoneyTransaction> transactions;
  final MoneyTransaction? existing;

  const _CashCountForm({
    super.key,
    required this.database,
    required this.currencies,
    required this.transactions,
    required this.existing,
  });

  @override
  State<_CashCountForm> createState() => _CashCountFormState();
}

class _CashCountFormState extends State<_CashCountForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _commentController;
  late String _currencyCode;
  late DateTime _date;

  // An existing count stores a computed difference, so only comment and date are editable.
  bool get _isEdit => widget.existing != null;

  Balance get _balance => Balance.from(
        currencies: widget.currencies,
        transactions: widget.transactions,
      );

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
    final existing = widget.existing;
    if (existing != null) {
      await widget.database.updateTransactionEntry(
        existing.copyWith(
          comment: _commentController.text.trim(),
          date: _date,
        ),
      );
    } else {
      // A new count is stored as the difference to the expected cash.
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
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final codes = currencyCodesWithSelected(widget.currencies, _currencyCode);
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
            onCurrencySelected:
                _isEdit ? null : (code) => setState(() => _currencyCode = code),
            amountController: _amountController,
            readOnly: _isEdit,
            autofocus: !_isEdit,
            allowNegative: _isEdit,
            amountLabel: _isEdit ? 'Correction' : 'Counted cash',
            onAmountChanged: (_) => setState(() {}),
            amountValidator: _isEdit
                ? null
                : (value) => (value ?? '').trim().isEmpty
                    ? 'Please enter an amount'
                    : null,
          ),
          if (!_isEdit)
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
            label: Text(_isEdit ? 'Update Count' : 'Save Count'),
          ),
        ],
      ),
    );
  }
}
