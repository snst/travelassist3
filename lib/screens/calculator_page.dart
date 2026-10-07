import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calculator/calculator.dart';
import '../calculator/currency_value.dart';
import '../database/database.dart';

class CalculatorPage extends StatefulWidget {
  final AppDatabase database;

  const CalculatorPage({super.key, required this.database});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final Calculator _calculator = Calculator();
  final ScrollController _scrollController = ScrollController();

  List<TextEditingController>? _controllers;
  List<FocusNode>? _focusNodes;
  double _currentValue = 0;
  Currency? _currentCurrency;

  @override
  void initState() {
    super.initState();
    _calculator.addListener(_onCalculatorChanged);
  }

  @override
  void dispose() {
    _calculator.removeListener(_onCalculatorChanged);
    _calculator.dispose();
    _scrollController.dispose();
    if (_controllers != null) {
      for (final c in _controllers!) {
        c.dispose();
      }
    }
    if (_focusNodes != null) {
      for (final f in _focusNodes!) {
        f.dispose();
      }
    }
    super.dispose();
  }

  void _onCalculatorChanged() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onChanged(int index, String text, List<Currency> currencies) {
    double val = CurrencyValue.safeConvertToDouble(text);
    _currentValue = val;
    _currentCurrency = currencies[index];

    if (_controllers != null) {
      for (int j = 0; j < _controllers!.length; j++) {
        if (j != index) {
          if (text.isEmpty || val == 0) {
            _controllers![j].text = '';
          } else {
            double converted = (val / currencies[index].rate) * currencies[j].rate;
            _controllers![j].text = converted.toStringAsFixed(2);
          }
        }
      }
    }
  }

  void _clearAllInputs() {
    if (_controllers != null) {
      for (final controller in _controllers!) {
        controller.clear();
      }
    }
  }

  void _pushValue() {
    if (_currentCurrency != null && _currentValue != 0) {
      _calculator.pushValue(CurrencyValue(_currentValue, _currentCurrency));
    }
    _clearAllInputs();
    _currentCurrency = null;
    _currentValue = 0;
  }

  @override
  Widget build(BuildContext context) {
    const buttonStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Calculator'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<List<Currency>>(
        stream: widget.database.watchAllCurrencies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final currencies = snapshot.data ?? [];

          if (currencies.isEmpty) {
            return const Center(
              child: Text(
                'No currencies available.\nPlease add currencies in Currency Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          if (_controllers == null || _controllers!.length != currencies.length) {
            _controllers = List.generate(
              currencies.length,
              (_) => TextEditingController(),
            );
            _focusNodes = List.generate(
              currencies.length,
              (_) => FocusNode(),
            );
          }

          if (_calculator.showResult()) {
            for (int j = 0; j < currencies.length; j++) {
              final convertedVal = _calculator.sum.convertTo(currencies[j]);
              _controllers![j].text = convertedVal.value == 0
                  ? '0.00'
                  : convertedVal.value.toStringAsFixed(2);
            }
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: currencies.length,
                  itemBuilder: (context, index) {
                    final currency = currencies[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: TextFormField(
                        controller: _controllers![index],
                        focusNode: _focusNodes![index],
                        onChanged: (text) => _onChanged(index, text, currencies),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        autocorrect: false,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          labelText: '${currency.name} (${currency.shortName})',
                          labelStyle: const TextStyle(fontSize: 16),
                          suffixIcon: IconButton(
                            onPressed: () {
                              _controllers![index].clear();
                              _focusNodes![index].requestFocus();
                              _onChanged(index, '', currencies);
                            },
                            icon: const Icon(Icons.clear),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              ListenableBuilder(
                listenable: _calculator,
                builder: (context, child) {
                  return Container(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    padding: EdgeInsets.fromLTRB(
                      16.0,
                      16.0,
                      16.0,
                      16.0 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _scrollController,
                          child: Text(
                            _calculator.inputString.isEmpty
                                ? ' '
                                : _calculator.inputString,
                            style: const TextStyle(
                              fontSize: 18,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _calculator.sum.toString(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onLongPress: () {
                                  _calculator.clear();
                                  _clearAllInputs();
                                },
                                onPressed: () {
                                  _calculator.back();
                                  _clearAllInputs();
                                },
                                child: const Icon(Icons.backspace, size: 24),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _pushValue();
                                  _calculator.add();
                                },
                                child: const Text('+', style: buttonStyle),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _pushValue();
                                  _calculator.subtract();
                                },
                                child: const Text('-', style: buttonStyle),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                onPressed: () {
                                  _pushValue();
                                  _calculator.calculate();
                                },
                                child: const Text('=', style: buttonStyle),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
