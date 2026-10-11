import 'package:flutter/material.dart';
import '../balance/balance.dart';
import '../calculator/currency_value.dart';
import '../database/database.dart';
import '../widgets/currency_amount_input.dart';
import '../utils/payment_methods.dart';
import '../widgets/add_payment_method_dialog.dart';
import '../widgets/cash_count_hint.dart';
import '../widgets/comment_input.dart';
import '../widgets/date_time_picker_tile.dart';
import '../widgets/payment_method_selector.dart';
import '../widgets/tag_editor.dart';

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
  }
}

class TransactionItemPage extends StatefulWidget {
  final AppDatabase database;
  final MoneyTransaction? transaction;

  /// All stored transactions, newest first; used for suggestions and the expected cash.
  final List<MoneyTransaction> transactions;
  final List<Currency> currencies;

  const TransactionItemPage({
    super.key,
    required this.database,
    required this.transactions,
    required this.currencies,
    this.transaction,
  });

  @override
  State<TransactionItemPage> createState() => _TransactionItemPageState();
}

class _TransactionItemPageState extends State<TransactionItemPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _methodController;
  late final TextEditingController _commentController;

  late TransactionKind _kind;
  late String _currencyCode;
  late List<String> _tags;
  String _tagDraft = '';
  late DateTime _date;
  late bool _includeInAverage;
  late bool _isPlanned;
  late final Balance _balance;
  bool get _isNew => widget.transaction == null;
  // An existing cash count stores a computed difference, so its amount is not editable.
  bool get _lockAmount => !_isNew && _kind == TransactionKind.cashCount;
  bool get _usesMethod =>
      _kind == TransactionKind.expense || _kind == TransactionKind.withdrawal;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _kind = t?.type ?? TransactionKind.expense;
    _amountController = TextEditingController(
      text: t == null ? '' : t.amount.toStringAsFixed(2),
    );
    _commentController = TextEditingController(text: t?.comment ?? '');
    _tags = t?.tagList ?? [];
    _date = t?.date ?? DateTime.now();
    _includeInAverage = t?.includeInAverage ?? true;
    _isPlanned = t?.isPlanned ?? false;
    _balance = Balance.from(
      currencies: widget.currencies,
      transactions: widget.transactions,
    );

    final codes = widget.currencies.map((c) => c.shortName).toList();
    final lastUsed =
        widget.transactions.isNotEmpty ? widget.transactions.first.currency : null;
    _currencyCode = t?.currency ??
        (lastUsed != null && codes.contains(lastUsed)
            ? lastUsed
            : _balance.home?.shortName ?? '');

    _methodController = TextEditingController(
      text: t != null ? t.method : '',
    );
    if (t == null) {
      _methodController.text = _defaultMethod(_kind);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _methodController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _showAddPaymentMethodDialog() async {
    final method = await showAddPaymentMethodDialog(context);
    if (method != null && mounted) {
      setState(() => _methodController.text = method);
    }
  }

  /// Payment methods used before for [kind], most frequent first.
  List<String> _methodSuggestions(TransactionKind kind) =>
      paymentMethodSuggestions(
        transactions: widget.transactions,
        kind: kind,
        current: _methodController.text,
      );

  String _defaultMethod(TransactionKind kind) {
    if (!(kind == TransactionKind.expense || kind == TransactionKind.withdrawal)) {
      return '';
    }
    final suggestions = _methodSuggestions(kind);
    return suggestions.isEmpty ? (kind == TransactionKind.expense ? cashMethod : '') : suggestions.first;
  }

  void _setKind(TransactionKind kind) {
    setState(() {
      _kind = kind;
      _methodController.text = _defaultMethod(kind);
    });
  }

  void _addTag(String tag) {
    final cleaned = tag.trim().replaceAll('#', '').toLowerCase();
    if (cleaned.isNotEmpty && !_tags.contains(cleaned)) {
      setState(() => _tags.add(cleaned));
    }
    _tagDraft = '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currencyCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a currency first')),
      );
      return;
    }

    final entered = CurrencyValue.safeConvertToDouble(_amountController.text);
    var comment = _commentController.text.trim();
    var method = _usesMethod ? _methodController.text.trim() : '';
    if (_kind == TransactionKind.expense && method.isEmpty) method = cashMethod;

    if (_kind == TransactionKind.expense && _tagDraft.trim().isNotEmpty) {
      _addTag(_tagDraft);
    }
    final tags = _kind == TransactionKind.expense ? _tags : <String>[];
    final isPlanned = _kind == TransactionKind.expense && _isPlanned;

    var amount = entered;
    if (_isNew && _kind == TransactionKind.cashCount) {
      amount = entered - _balance.cashIn(_currencyCode);
      final counted = 'Counted: ${entered.toStringAsFixed(2)} $_currencyCode';
      comment = comment.isEmpty ? counted : '$counted - $comment';
    }

    final existing = widget.transaction;
    if (existing == null) {
      await widget.database.addTransaction(
        kind: _kind,
        amount: amount,
        currency: _currencyCode,
        method: method,
        comment: comment,
        tags: tags,
        date: _date,
        includeInAverage: _includeInAverage,
        isPlanned: isPlanned,
      );
    } else {
      await widget.database.updateTransactionEntry(
        existing.copyWith(
          amount: _lockAmount ? existing.amount : amount,
          currency: _currencyCode,
          method: method,
          comment: comment,
          tags: tags.join(','),
          date: _date,
          includeInAverage: _includeInAverage,
          isPlanned: isPlanned,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final dialogNavigator = Navigator.of(dialogContext);
              await widget.database.deleteTransaction(widget.transaction!.id);
              dialogNavigator.pop();
              navigator.pop(true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildKindSelector() {
    if (!_isNew) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          //avatar: Icon(transactionIcon(_kind), size: 18),
          label: Text(transactionLabel(_kind)),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final kind in TransactionKind.values)
          ChoiceChip(
            /*avatar: Icon(
              transactionIcon(kind),
              size: 18,
              color: _kind == kind
                  ? Theme.of(context).colorScheme.onPrimary
                  : null,
            ),*/
            label: Text(transactionLabel(kind)),
            selected: _kind == kind,
            showCheckmark: false,
            selectedColor: Theme.of(context).colorScheme.primary,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: _kind == kind
                  ? Theme.of(context).colorScheme.onPrimary
                  : null,
            ),
            onSelected: (_) => _setKind(kind),
          ),
      ],
    );
  }

  Widget _buildCashCountHint() {
    final hasInput = _amountController.text.trim().isNotEmpty;
    return CashCountHint(
      expected: _balance.cashIn(_currencyCode),
      currencyCode: _currencyCode,
      counted:
          hasInput ? CurrencyValue.safeConvertToDouble(_amountController.text) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final codes = widget.currencies.map((c) => c.shortName).toList();
    if (_currencyCode.isNotEmpty && !codes.contains(_currencyCode)) {
      codes.add(_currencyCode);
    }
    final knownTags = <String>{
      for (final t in widget.transactions) ...t.tagList,
    }.where((t) => !_tags.contains(t)).toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add Entry' : 'Edit ${transactionLabel(_kind)}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete Entry',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            if (_isNew) ...[
              _buildKindSelector(),
              const SizedBox(height: 16),
            ],
            CurrencyAmountInput(
              currencyCodes: codes,
              selectedCurrencyCode: _currencyCode,
              onCurrencySelected: _lockAmount
                  ? null
                  : (code) => setState(() => _currencyCode = code),
              amountController: _amountController,
              readOnly: _lockAmount,
              autofocus: _isNew,
              allowNegative: _lockAmount,
              amountLabel: _kind == TransactionKind.cashCount
                  ? (_isNew ? 'Counted cash' : 'Correction')
                  : 'Amount',
              onAmountChanged: (_) => setState(() {}),
              amountValidator: (value) {
                if (_lockAmount) return null;
                if ((value ?? '').trim().isEmpty) {
                  return 'Please enter an amount';
                }
                final v = CurrencyValue.safeConvertToDouble(value!);
                if (_kind != TransactionKind.cashCount && v <= 0) {
                  return 'Amount must be greater than 0';
                }
                return null;
              },
            ),
            //const SizedBox(height: 12),

            if (_isNew && _kind == TransactionKind.cashCount) _buildCashCountHint(),
            if (_usesMethod)
              PaymentMethodSelector(
                methods: _methodSuggestions(_kind),
                selectedMethod: _methodController.text,
                onSelected: (method) =>
                    setState(() => _methodController.text = method),
                onAddMethod: _showAddPaymentMethodDialog,
              ),
            if (_kind == TransactionKind.expense) ...[
              const SizedBox(height: 20),
              TagEditor(
                tags: _tags,
                availableTags: knownTags,
                initialInput: _tagDraft,
                labelText: 'Add tag',
                hintText: 'e.g. food, taxi, hotel',
                onInputChanged: (value) => _tagDraft = value,
                onTagAdded: _addTag,
                onTagRemoved: (tag) {
                  setState(() => _tags.remove(tag));
                },
              ),
            ],
            const SizedBox(height: 20),
            CommentInput(
              controller: _commentController,
            ),
            const SizedBox(height: 8),
            DateTimePickerTile(
              value: _date,
              onChanged: (date) => setState(() => _date = date),
            ),
            if (_kind == TransactionKind.expense)
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Planned'),
                      value: _isPlanned,
                      onChanged: (v) => setState(() => _isPlanned = v),
                    ),
                  ),
                  SizedBox(width: 20,),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('In average'),
                      value: _includeInAverage,
                      onChanged: (v) =>
                          setState(() => _includeInAverage = v),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isNew ? 'Save Entry' : 'Update Entry'),
            ),
          ],
        ),
      ),
    );
  }
}
