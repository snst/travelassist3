import 'package:flutter/material.dart';

import '../calculator/currency_value.dart';
import '../database/database.dart';
import '../utils/currency_codes.dart';
import '../utils/payment_methods.dart';
import '../utils/transaction_kind.dart';
import '../widgets/add_payment_method_dialog.dart';
import '../widgets/comment_input.dart';
import '../widgets/date_time_picker_tile.dart';
import '../widgets/days_input.dart';
import '../widgets/delete_entry_button.dart';
import '../widgets/expense_options.dart';
import '../widgets/large_text_dialog.dart';
import '../widgets/link_editor.dart';
import '../widgets/payment_currency_amount_input.dart';
import '../widgets/tag_editor.dart';
import '../widgets/transaction_data_scaffold.dart';
import 'expenses_list_page.dart';
import 'note_actions.dart';

class ExpensePage extends StatefulWidget {
  final AppDatabase database;

  /// An existing expense to edit; null to add a new one.
  final MoneyTransaction? transaction;
  final bool openExpensesListOnSave;

  const ExpensePage({
    super.key,
    required this.database,
    this.transaction,
    this.openExpensesListOnSave = false,
  });

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final _formKey = GlobalKey<_ExpenseFormState>();

  @override
  Widget build(BuildContext context) {
    final existing = widget.transaction;
    return TransactionDataScaffold(
      database: widget.database,
      title: existing == null
          ? 'Add Expense'
          : 'Edit ${transactionLabel(TransactionKind.expense)}',
      actions: [
        if (existing != null)
          DeleteEntryButton(database: widget.database, transaction: existing),
        SizedBox(width: 16),
        IconButton(
          tooltip: existing == null ? 'Save Expense' : 'Update Expense',
          onPressed: () => _formKey.currentState?._save(),
          icon: const Icon(Icons.save),
        ),
        SizedBox(width: 16),
        IconButton(
          tooltip: 'View Info',
          onPressed: () => _formKey.currentState?._showInfo(),
          icon: const Icon(Icons.visibility_outlined),
        ),
      ],
      builder: (context, currencies, transactions) => _ExpenseForm(
        key: _formKey,
        database: widget.database,
        currencies: currencies,
        transactions: transactions,
        existing: existing,
        openExpensesListOnSave: widget.openExpensesListOnSave,
      ),
    );
  }
}

class _ExpenseForm extends StatefulWidget {
  final AppDatabase database;
  final List<Currency> currencies;

  /// All stored transactions, newest first; used for default currency, methods and tags.
  final List<MoneyTransaction> transactions;
  final MoneyTransaction? existing;
  final bool openExpensesListOnSave;

  const _ExpenseForm({
    super.key,
    required this.database,
    required this.currencies,
    required this.transactions,
    required this.existing,
    required this.openExpensesListOnSave,
  });

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _commentController;
  late final TextEditingController _methodController;
  late final LinkListController _links;
  late String _currencyCode;
  late List<String> _tags;
  String _tagDraft = '';
  late DateTime _date;
  late int _averageDays;
  Future<void>? _gpsLocationCapture;
  bool _gpsLocationCaptureStarted = false;

  List<String> get _methods => paymentMethodSuggestions(
    transactions: widget.transactions,
    kind: TransactionKind.expense,
    current: _methodController.text,
  );

  bool get _isInCalendar =>
      _tags.any((tag) => tag.toLowerCase() == calendarTag);
  bool get _isPlanned => _tags.any((tag) => tag.toLowerCase() == plannedTag);

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
    _tags = t?.editableTagList ?? [];
    _date = t?.date ?? DateTime.now();
    _averageDays = t?.days ?? 1;
    if (t == null) _methodController.text = _methods.first;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.existing == null && !_gpsLocationCaptureStarted) {
      _gpsLocationCaptureStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _gpsLocationCapture = LinkEditor.attachCurrentGpsLocation(
            context,
            _links,
          );
        }
      });
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

  void _addTag(String tag) {
    final cleaned = tag.trim().replaceAll('#', '').toLowerCase();
    if (cleaned.isNotEmpty &&
        !isReservedTransactionTag(cleaned) &&
        !_tags.contains(cleaned)) {
      setState(() => _tags.add(cleaned));
    }
    _tagDraft = '';
  }

  void _setCalendarTag(bool inCalendar) {
    setState(() {
      _tags.removeWhere((tag) => tag.toLowerCase() == calendarTag);
      if (inCalendar) _tags.add(calendarTag);
    });
  }

  void _setPlannedTag(bool isPlanned) {
    setState(() {
      _tags.removeWhere((tag) => tag.toLowerCase() == plannedTag);
      if (isPlanned) _tags.add(plannedTag);
    });
  }

  void _showInfo() {
    FocusScope.of(context).unfocus();
    showLargeTextDialog(
      context,
      _commentController.text,
      emptyMessage: 'No info entered.',
      links: _links.fields
          .map((field) => field.text.trim())
          .where((link) => link.isNotEmpty)
          .toList(),
      onOpenLink: openNoteLink,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tagDraft.trim().isNotEmpty) _addTag(_tagDraft);

    final amount = CurrencyValue.safeConvertToDouble(_amountController.text);
    final method = _methodController.text.trim().isEmpty
        ? cashMethod
        : _methodController.text.trim();
    final comment = _commentController.text.trim();
    final existing = widget.existing;
    if (existing == null) {
      await _gpsLocationCapture;
      if (!mounted) return;
      await widget.database.addTransaction(
        kind: TransactionKind.expense,
        amount: amount,
        currency: _currencyCode,
        method: method,
        comment: comment,
        tags: _tags,
        date: _date,
        days: _averageDays,
        link: _links.joined,
      );
    } else {
      await widget.database.updateTransactionEntry(
        existing.copyWith(
          amount: amount,
          currency: _currencyCode,
          method: method,
          comment: comment,
          tags: _tags.join(','),
          date: _date,
          days: _averageDays,
          link: _links.joined,
        ),
      );
    }
    if (mounted) {
      if (widget.openExpensesListOnSave) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ExpensesListPage(database: widget.database),
          ),
          result: true,
        );
      } else {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final codes = currencyCodesWithSelected(widget.currencies, _currencyCode);
    final knownTags = <String>{
      for (final t in widget.transactions) ...t.tagList,
    }.where((t) => !_tags.contains(t)).toList()..sort();

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
          TagEditor(
            tags: _tags,
            availableTags: knownTags,
            initialInput: _tagDraft,
            onInputChanged: (value) => _tagDraft = value,
            onTagAdded: _addTag,
            onTagRemoved: (tag) => setState(() => _tags.remove(tag)),
          ),
          CommentInput(controller: _commentController),
          Row(
            children: [
              Expanded(
                child: DateTimePickerTile(
                  value: _date,
                  onChanged: (date) => setState(() => _date = date),
                ),
              ),
              const SizedBox(
                height: 32,
                child: VerticalDivider(width: 16, thickness: 1),
              ),
              Expanded(
                child: DaysInput(
                  days: _averageDays,
                  unit: 'day',
                  onChanged: (value) => setState(() => _averageDays = value),
                ),
              ),
            ],
          ),
          ExpenseOptions(
            isPlanned: _isPlanned,
            averageDays: _averageDays,
            inCalendar: _isInCalendar,
            onPlannedChanged: _setPlannedTag,
            onAverageDaysChanged: (v) => setState(() => _averageDays = v),
            onCalendarChanged: _setCalendarTag,
          ),
          LinkEditor(controller: _links),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(
              widget.existing == null ? 'Save Expense' : 'Update Expense',
            ),
          ),
        ],
      ),
    );
  }
}
