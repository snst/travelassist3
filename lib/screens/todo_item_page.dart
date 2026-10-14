import 'package:flutter/material.dart';
import '../database/database.dart';
import '../widgets/comment_input.dart';

class TodoItemPage extends StatefulWidget {
  final AppDatabase database;
  final TodoItem? item;

  const TodoItemPage({
    super.key,
    required this.database,
    this.item,
  });

  @override
  State<TodoItemPage> createState() => _TodoItemPageState();
}

class _TodoItemPageState extends State<TodoItemPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _commentController;

  late String _category;
  late int _quantity;
  late int _used;
  late int _state;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _commentController = TextEditingController(text: item?.comment ?? '');
    _category = item?.category ?? 'General';
    _quantity = item?.quantity ?? 1;
    _used = item?.used ?? 0;
    _state = item?.state ?? 0; // 0: open, 1: skipped, 2: done

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await widget.database.getAllCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.item == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Add Item' : 'Edit Item'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete Item',
              onPressed: _confirmDelete,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: isNew ? 'Add to Checklist' : 'Save Changes',
            onPressed: _saveItem,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16.0,
          16.0,
          16.0,
          16.0 + MediaQuery.of(context).padding.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: isNew,
                decoration: const InputDecoration(
                  labelText: 'Item',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _category),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _categories;
                  }
                  return _categories.where((cat) => cat
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (String selection) {
                  _category = selection;
                },
                fieldViewBuilder:
                    (context, textEditingController, focusNode, onEditingComplete) {
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    onChanged: (val) {
                      _category = val;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      hintText: 'e.g. Documents, Electronics, Clothing',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuantityCounter(
                        label: 'Used',
                        value: _used,
                        onChanged: (val) {
                          setState(() {
                            _used = val;
                          });
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildQuantityCounter(
                        label: 'Packed',
                        value: _quantity,
                        onChanged: (val) {
                          setState(() {
                            _quantity = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('Open'),
                    icon: Icon(Icons.check_box_outline_blank),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Skipped'),
                    icon: Icon(Icons.block, color: Colors.orange),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text('Done'),
                    icon: Icon(Icons.check_box, color: Colors.green),
                  ),
                ],
                selected: {_state},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() {
                    _state = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              CommentInput(
                controller: _commentController,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: _saveItem,
                icon: const Icon(Icons.save),
                label: Text(
                  isNew ? 'Add to Checklist' : 'Save Changes',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityCounter({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.outlined(
              icon: const Icon(Icons.remove, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                '$value',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton.outlined(
              icon: const Icon(Icons.add, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final category = _category.trim().isEmpty ? 'General' : _category.trim();
      final comment = _commentController.text.trim();

      if (widget.item == null) {
        await widget.database.addTodoItem(
          name: name,
          category: category,
          comment: comment,
          quantity: _quantity,
          used: _used,
          state: _state,
        );
      } else {
        final updated = widget.item!.copyWith(
          name: name,
          category: category,
          comment: comment,
          quantity: _quantity,
          used: _used,
          state: _state,
        );
        await widget.database.updateTodoItemEntry(updated);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${widget.item!.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await widget.database.deleteTodoItem(widget.item!.id);
              if (mounted) {
                navigator.pop(); // Close dialog
                navigator.pop(true); // Return to list
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
