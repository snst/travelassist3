import 'package:flutter/material.dart';
import '../database/database.dart';

class CurrencySettingsScreen extends StatefulWidget {
  final AppDatabase database;

  const CurrencySettingsScreen({super.key, required this.database});

  @override
  State<CurrencySettingsScreen> createState() => _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState extends State<CurrencySettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Settings'),
      ),
      body: StreamBuilder<List<Currency>>(
        stream: widget.database.watchAllCurrencies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading currencies: ${snapshot.error}'));
          }

          final currencies = snapshot.data ?? [];

          if (currencies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.currency_exchange, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No currencies found.', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCurrencyDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Currency'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: currencies.length,
            itemBuilder: (context, index) {
              final currency = currencies[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: currency.isHome
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Text(
                      currency.shortName.isNotEmpty
                          ? currency.shortName.substring(0, 1)
                          : '\$',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          currency.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Chip(
                        label: Text(
                          currency.shortName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      if (currency.isHome) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Text(
                            'HOME',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    'Exchange Rate: ${currency.rate.toStringAsFixed(4)}',
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Actions',
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _showEditCurrencyDialog(context, currency);
                      } else if (value == 'delete') {
                        _confirmDeleteCurrency(context, currency);
                      } else if (value == 'set_home') {
                        await widget.database.setHomeCurrency(currency.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${currency.name} set as home currency'),
                            ),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      if (!currency.isHome)
                        const PopupMenuItem(
                          value: 'set_home',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.home, color: Colors.green),
                              SizedBox(width: 8),
                              Flexible(child: Text('Set as Home')),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, color: Colors.blue),
                            SizedBox(width: 8),
                            Flexible(child: Text('Edit')),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Flexible(child: Text('Delete')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'currencies_fab',
        onPressed: () => _showAddCurrencyDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Currency'),
      ),
    );
  }

  void _showAddCurrencyDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final shortNameController = TextEditingController();
    final rateController = TextEditingController();
    bool isHome = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Currency'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: shortNameController,
                        decoration: const InputDecoration(
                          labelText: 'Short Name / Symbol (e.g. USD)',
                          hintText: 'USD',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a short name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Currency Name',
                          hintText: 'US Dollar',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter currency name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: rateController,
                        decoration: const InputDecoration(
                          labelText: 'Exchange Rate',
                          hintText: '1.0',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter exchange rate';
                          }
                          final rate = double.tryParse(value.trim());
                          if (rate == null || rate <= 0) {
                            return 'Please enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        title: const Text('Set as Home Currency'),
                        value: isHome,
                        onChanged: (val) {
                          setDialogState(() {
                            isHome = val ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final name = nameController.text.trim();
                      final shortName = shortNameController.text.trim().toUpperCase();
                      final rate = double.parse(rateController.text.trim());

                      await widget.database.addCurrency(
                        name: name,
                        shortName: shortName,
                        rate: rate,
                        isHome: isHome,
                      );

                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added $name ($shortName)')),
                        );
                      }
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditCurrencyDialog(BuildContext context, Currency currency) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: currency.name);
    final shortNameController = TextEditingController(text: currency.shortName);
    final rateController = TextEditingController(text: currency.rate.toString());
    bool isHome = currency.isHome;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Currency'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: shortNameController,
                        decoration: const InputDecoration(
                          labelText: 'Short Name / Symbol',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a short name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Currency Name',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter currency name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: rateController,
                        decoration: const InputDecoration(
                          labelText: 'Exchange Rate',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter exchange rate';
                          }
                          final rate = double.tryParse(value.trim());
                          if (rate == null || rate <= 0) {
                            return 'Please enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        title: const Text('Set as Home Currency'),
                        value: isHome,
                        onChanged: (val) {
                          setDialogState(() {
                            isHome = val ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final name = nameController.text.trim();
                      final shortName = shortNameController.text.trim().toUpperCase();
                      final rate = double.parse(rateController.text.trim());

                      if (isHome && !currency.isHome) {
                        await widget.database.setHomeCurrency(currency.id);
                      }

                      final updatedCurrency = currency.copyWith(
                        name: name,
                        shortName: shortName,
                        rate: rate,
                        isHome: isHome,
                      );

                      await widget.database.updateCurrencyEntry(updatedCurrency);

                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Updated $name ($shortName)')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCurrency(BuildContext context, Currency currency) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Currency'),
          content: Text(
            'Are you sure you want to delete ${currency.name} (${currency.shortName})?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await widget.database.deleteCurrency(currency.id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted ${currency.name}')),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
