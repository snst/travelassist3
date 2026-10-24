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
import '../widgets/reservation_state.dart';
import '../widgets/link_editor.dart';
import '../widgets/tag_editor.dart';
import '../widgets/transaction_data_scaffold.dart';
import '../widgets/days_input.dart';
import '../widgets/payment_currency_amount_input.dart';

class HotelPage extends StatefulWidget {
  final AppDatabase database;

  /// An existing hotel booking to edit; null to add a new one.
  final MoneyTransaction? transaction;

  const HotelPage({super.key, required this.database, this.transaction});

  @override
  State<HotelPage> createState() => _HotelPageState();
}

class _HotelPageState extends State<HotelPage> {
  final _formKey = GlobalKey<_HotelFormState>();

  @override
  Widget build(BuildContext context) {
    final existing = widget.transaction;
    return TransactionDataScaffold(
      database: widget.database,
      title: existing == null
          ? 'Add Hotel'
          : 'Edit ${transactionLabel(TransactionKind.hotel)}',
      actions: [
        if (existing != null)
          DeleteEntryButton(database: widget.database, transaction: existing),
        IconButton(
          tooltip: existing == null ? 'Save Hotel' : 'Update Hotel',
          onPressed: () => _formKey.currentState?._save(),
          icon: const Icon(Icons.save),
        ),
      ],
      builder: (context, currencies, transactions) => _HotelForm(
        key: _formKey,
        database: widget.database,
        currencies: currencies,
        transactions: transactions,
        existing: existing,
      ),
    );
  }
}

class _HotelForm extends StatefulWidget {
  final AppDatabase database;
  final List<Currency> currencies;

  /// All stored transactions, newest first; used for default currency, methods and tags.
  final List<MoneyTransaction> transactions;
  final MoneyTransaction? existing;

  const _HotelForm({
    super.key,
    required this.database,
    required this.currencies,
    required this.transactions,
    required this.existing,
  });

  @override
  State<_HotelForm> createState() => _HotelFormState();
}

class _HotelFormState extends State<_HotelForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _commentController;
  late final TextEditingController _methodController;
  late final LinkListController _links;
  late String _currencyCode;
  late List<String> _tags;
  String _tagDraft = '';
  late DateTime _date;
  late int _days;
  late bool _isPlanned;

  List<String> get _methods => paymentMethodSuggestions(
    transactions: widget.transactions,
    kind: TransactionKind.hotel,
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
    _tags = t?.tagList ?? [];
    _date = t?.date ?? DateTime.now();
    _days = t?.days ?? 1;
    _isPlanned = t?.planned ?? true;
    if (t == null) _methodController.text = _methods.first;
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
    if (cleaned.isNotEmpty && !_tags.contains(cleaned)) {
      setState(() => _tags.add(cleaned));
    }
    _tagDraft = '';
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
      await widget.database.addTransaction(
        kind: TransactionKind.hotel,
        amount: amount,
        currency: _currencyCode,
        method: method,
        comment: comment,
        tags: _tags,
        date: _date,
        days: _days,
        planned: _isPlanned,
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
          days: _days,
          planned: _isPlanned,
          link: _links.joined,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop(true);
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
                  days: _days,
                  onChanged: (v) => setState(() => _days = v),
                ),
              ),
            ],
          ),
          ReservationState(
            isPlanned: _isPlanned,
            onPlannedChanged: (value) => setState(() => _isPlanned = value),
          ),
          LinkEditor(controller: _links),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(
              widget.existing == null ? 'Save Hotel' : 'Update Hotel',
            ),
          ),
        ],
      ),
    );
  }
}
