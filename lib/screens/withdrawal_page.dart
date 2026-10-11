import 'package:flutter/material.dart';
import '../balance/balance.dart';
import '../calculator/currency_value.dart';
import '../database/database.dart';
import '../utils/payment_methods.dart';
import '../widgets/add_payment_method_dialog.dart';
import '../widgets/comment_input.dart';
import '../widgets/currency_amount_input.dart';
import '../widgets/date_time_picker_tile.dart';
import '../widgets/payment_method_selector.dart';
import '../widgets/transaction_data_scaffold.dart';

class WithdrawalPage extends StatelessWidget {
  final AppDatabase database;

  const WithdrawalPage({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return TransactionDataScaffold(
      database: database,
      title: 'Add ATM Withdrawal',
      builder: (context, currencies, transactions) => _WithdrawalForm(
        database: database,
        currencies: currencies,
        transactions: transactions,
      ),
    );
  }
}

class _WithdrawalForm extends StatefulWidget {
  final AppDatabase database;
  final List<Currency> currencies;

  /// All stored transactions, newest first; used for default currency and method.
  final List<MoneyTransaction> transactions;

  const _WithdrawalForm({
    required this.database,
    required this.currencies,
    required this.transactions,
  });

  @override
  State<_WithdrawalForm> createState() => _WithdrawalFormState();
}

class _WithdrawalFormState extends State<_WithdrawalForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();
  final _methodController = TextEditingController();
  late String _currencyCode;
  DateTime _date = DateTime.now();

  List<String> get _methods => paymentMethodSuggestions(
        transactions: widget.transactions,
        kind: TransactionKind.withdrawal,
        current: _methodController.text,
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
    final methods = _methods;
    if (methods.isNotEmpty) _methodController.text = methods.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    _methodController.dispose();
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
    await widget.database.addTransaction(
      kind: TransactionKind.withdrawal,
      amount: CurrencyValue.safeConvertToDouble(_amountController.text),
      currency: _currencyCode,
      method: _methodController.text.trim(),
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
          PaymentMethodSelector(
            methods: _methods,
            selectedMethod: _methodController.text,
            onSelected: (method) =>
                setState(() => _methodController.text = method),
            onAddMethod: _addMethod,
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
            label: const Text('Save Withdrawal'),
          ),
        ],
      ),
    );
  }
}
