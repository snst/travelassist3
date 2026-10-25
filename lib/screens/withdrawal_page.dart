import 'package:flutter/material.dart';

import '../calculator/currency_value.dart';
import '../database/database.dart';
import '../utils/currency_codes.dart';
import '../utils/payment_methods.dart';
import '../utils/transaction_kind.dart';
import '../widgets/add_payment_method_dialog.dart';
import '../widgets/comment_input.dart';
import '../widgets/date_time_picker_tile.dart';
import '../widgets/delete_entry_button.dart';
import '../widgets/link_editor.dart';
import '../widgets/payment_currency_amount_input.dart';
import '../widgets/transaction_data_scaffold.dart';

class WithdrawalPage extends StatefulWidget {
  final AppDatabase database;

  /// An existing withdrawal to edit; null to add a new one.
  final MoneyTransaction? transaction;

  const WithdrawalPage({super.key, required this.database, this.transaction});

  @override
  State<WithdrawalPage> createState() => _WithdrawalPageState();
}

class _WithdrawalPageState extends State<WithdrawalPage> {
  final _formKey = GlobalKey<_WithdrawalFormState>();

  @override
  Widget build(BuildContext context) {
    final existing = widget.transaction;
    return TransactionDataScaffold(
      database: widget.database,
      title: existing == null
          ? 'Add ATM'
          : 'Edit ${transactionLabel(TransactionKind.withdrawal)}',
      actions: [
        if (existing != null)
          DeleteEntryButton(database: widget.database, transaction: existing),
        SizedBox(width:16),
        IconButton(
          tooltip: existing == null ? 'Save ATM' : 'Update ATM',
          onPressed: () => _formKey.currentState?._save(),
          icon: const Icon(Icons.save),
        ),
      ],
      builder: (context, currencies, transactions) => _WithdrawalForm(
        key: _formKey,
        database: widget.database,
        currencies: currencies,
        transactions: transactions,
        existing: existing,
      ),
    );
  }
}

class _WithdrawalForm extends StatefulWidget {
  final AppDatabase database;
  final List<Currency> currencies;

  /// All stored transactions, newest first; used for default currency and method.
  final List<MoneyTransaction> transactions;
  final MoneyTransaction? existing;

  const _WithdrawalForm({
    super.key,
    required this.database,
    required this.currencies,
    required this.transactions,
    required this.existing,
  });

  @override
  State<_WithdrawalForm> createState() => _WithdrawalFormState();
}

class _WithdrawalFormState extends State<_WithdrawalForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _commentController;
  late final TextEditingController _methodController;
  late final LinkListController _links;
  late String _currencyCode;
  late DateTime _date;

  List<String> get _methods => paymentMethodSuggestions(
    transactions: widget.transactions,
    kind: TransactionKind.withdrawal,
    current: _methodController.text,
  );

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _amountController = TextEditingController(
      text: t == null ? '' : t.amount.toStringAsFixed(2),
    );
    _commentController = TextEditingController(text: t?.comment ?? '');
    _methodController = TextEditingController(text: t?.method ?? '');
    _links = LinkListController(t?.linkList ?? []);
    _currencyCode =
        t?.currency ??
        defaultCurrencyCode(widget.currencies, widget.transactions);
    _date = t?.date ?? DateTime.now();
    if (t == null) {
      final methods = _methods;
      if (methods.isNotEmpty) _methodController.text = methods.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    _methodController.dispose();
    _links.dispose();
    super.dispose();
  }

  Future<void> _addMethod() async {
    final method = await showAddPaymentMethodDialog(context);
    if (method != null && mounted) {
      setState(() => _methodController.text = method);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = CurrencyValue.safeConvertToDouble(_amountController.text);
    final method = _methodController.text.trim();
    final comment = _commentController.text.trim();
    final existing = widget.existing;
    if (existing == null) {
      await widget.database.addTransaction(
        kind: TransactionKind.withdrawal,
        amount: amount,
        currency: _currencyCode,
        method: method,
        comment: comment,
        date: _date,
        link: _links.joined,
      );
    } else {
      await widget.database.updateTransactionEntry(
        existing.copyWith(
          amount: amount,
          currency: _currencyCode,
          method: method,
          comment: comment,
          date: _date,
          link: _links.joined,
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
          PaymentCurrencyAmountInput(
            methods: _methods,
            selectedMethod: _methodController.text,
            onMethodSelected: (method) =>
                setState(() => _methodController.text = method),
            onAddMethod: _addMethod,
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
          LinkEditor(controller: _links),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(
              widget.existing == null ? 'Save ATM' : 'Update ATM',
            ),
          ),
        ],
      ),
    );
  }
}
