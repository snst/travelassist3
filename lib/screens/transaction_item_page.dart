import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../balance/balance.dart';
import '../calculator/currency_value.dart';
import '../database/database.dart';
import '../utils/date_format.dart';
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
      return 'Withdrawal';
    case TransactionKind.cashCount:
      return 'Cash Count';
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

  void _showAddPaymentMethodDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Payment Method'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Credit Card, PayPal, Revolut',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) {
              setState(() {
                _methodController.text = trimmed;
              });
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                setState(() {
                  _methodController.text = trimmed;
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  /// Payment methods used before for [kind], most frequent first.
  List<String> _methodSuggestions(TransactionKind kind) {
    final counts = <String, int>{};
    for (final t in widget.transactions) {
      final method = t.method.trim();
      if (t.type == kind && method.isNotEmpty) {
        counts[method] = (counts[method] ?? 0) + 1;
      }
    }
    if (kind == TransactionKind.expense) counts.putIfAbsent(cashMethod, () => 0);

    final current = _methodController.text.trim();
    if (current.isNotEmpty && !counts.containsKey(current)) {
      counts[current] = 999;
    }

    return counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  }

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

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (!mounted) return;
    setState(() {
      _date = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _date.hour,
        time?.minute ?? _date.minute,
      );
    });
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
          avatar: Icon(transactionIcon(_kind), size: 18),
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
            avatar: Icon(
              transactionIcon(kind),
              size: 18,
              color: _kind == kind
                  ? Theme.of(context).colorScheme.onPrimary
                  : null,
            ),
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
    final expected = _balance.cashIn(_currencyCode);
    final counted = CurrencyValue.safeConvertToDouble(_amountController.text);
    final hasInput = _amountController.text.trim().isNotEmpty;
    final difference = counted - expected;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Expected cash: ${expected.toStringAsFixed(2)} $_currencyCode'
        '${hasInput ? '   Difference: ${difference >= 0 ? '+' : ''}${difference.toStringAsFixed(2)}' : ''}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: hasInput && difference < 0 ? theme.colorScheme.error : null,
        ),
      ),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    children: [
                      for (final code in codes)
                        ChoiceChip(
                          label: Text(code),
                          selected: _currencyCode == code,
                          showCheckmark: false,
                          selectedColor: Theme.of(context).colorScheme.primary,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _currencyCode == code
                                ? Theme.of(context).colorScheme.onPrimary
                                : null,
                          ),
                          onSelected: _lockAmount
                              ? null
                              : (_) => setState(() => _currencyCode = code),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 240,
                  child: TextFormField(
                    controller: _amountController,
                    readOnly: _lockAmount,
                    autofocus: _isNew,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 24),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(_lockAmount ? r'[0-9.,-]' : r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: _kind == TransactionKind.cashCount
                          ? (_isNew ? 'Counted cash' : 'Correction')
                          : 'Amount',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (_lockAmount) return null;
                      if ((value ?? '').trim().isEmpty) return 'Please enter an amount';
                      final v = CurrencyValue.safeConvertToDouble(value!);
                      if (_kind != TransactionKind.cashCount && v <= 0) {
                        return 'Amount must be greater than 0';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            //const SizedBox(height: 12),

            if (_isNew && _kind == TransactionKind.cashCount) _buildCashCountHint(),
            if (_usesMethod) ...[
              //const SizedBox(height: 20),
              const Text(
                'Payment method',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final method in _methodSuggestions(_kind))
                    ActionChip(
                      backgroundColor: _methodController.text == method
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      label: Text(
                        method,
                        style: TextStyle(
                          fontWeight: _methodController.text == method
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _methodController.text == method
                              ? Theme.of(context).colorScheme.onPrimary
                              : null,
                        ),
                      ),
                      onPressed: () => setState(() => _methodController.text = method),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.more_horiz, size: 18),
                    label: const Text(''),
                    onPressed: _showAddPaymentMethodDialog,
                  ),
                ],
              ),
            ],
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
            TextFormField(
              controller: _commentController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Comment',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(formatDateTime(_date)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDate,
            ),
            if (_kind == TransactionKind.expense)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Planned'),
                subtitle: const Text('Not paid yet; excluded from current balance'),
                value: _isPlanned,
                onChanged: (v) => setState(() => _isPlanned = v),
              ),
            if (_kind == TransactionKind.expense)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include in daily average'),
                subtitle: const Text('Turn off for one-off costs such as flights'),
                value: _includeInAverage,
                onChanged: (v) => setState(() => _includeInAverage = v),
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
