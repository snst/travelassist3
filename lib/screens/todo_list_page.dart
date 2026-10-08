import 'package:flutter/material.dart';
import '../database/database.dart';
import 'todo_item_page.dart';

class TodoListPage extends StatefulWidget {
  final AppDatabase database;

  const TodoListPage({super.key, required this.database});

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  int _selectedState = 0; // 0: open, 1: skipped, 2: done

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Checklist'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<List<TodoItem>>(
        stream: widget.database.watchAllTodoItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allItems = snapshot.data ?? [];

          final filteredItems = allItems
              .where((item) => item.state == _selectedState)
              .toList();

          // Group items by category
          final grouped = <String, List<TodoItem>>{};
          for (final item in filteredItems) {
            grouped.putIfAbsent(item.category, () => []).add(item);
          }

          final sortedCategories = grouped.keys.toList()..sort();

          return Column(
            children: [
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedState == 0
                                  ? Icons.check_circle_outline
                                  : _selectedState == 1
                                      ? Icons.block
                                      : Icons.done_all,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedState == 0
                                  ? 'No open items in checklist!'
                                  : _selectedState == 1
                                      ? 'No skipped items.'
                                      : 'No completed items yet.',
                              style: const TextStyle(fontSize: 16),
                            ),
                            if (_selectedState == 0) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _openItemPage(null),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Item'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: sortedCategories.length,
                        itemBuilder: (context, catIndex) {
                          final category = sortedCategories[catIndex];
                          final categoryItems = grouped[category]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.folder_outlined,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...categoryItems.map((item) {
                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    onTap: () => _openItemPage(item),
                                    title: Text(
                                      item.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Packed: ${item.used} / ${item.quantity}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        if (item.comment.isNotEmpty)
                                          Text(
                                            item.comment,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: PopupMenuButton<int>(
                                      icon: const Icon(Icons.more_vert),
                                      tooltip: 'Change state',
                                      onSelected: (newState) async {
                                        await widget.database
                                            .setTodoItemState(item.id, newState);
                                      },
                                      itemBuilder: (context) => [
                                        if (item.state != 0)
                                          const PopupMenuItem(
                                            value: 0,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                    Icons
                                                        .check_box_outline_blank,
                                                    color: Colors.blue),
                                                SizedBox(width: 8),
                                                Text('Mark as Open'),
                                              ],
                                            ),
                                          ),
                                        if (item.state != 2)
                                          const PopupMenuItem(
                                            value: 2,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_box,
                                                    color: Colors.green),
                                                SizedBox(width: 8),
                                                Text('Mark as Done'),
                                              ],
                                            ),
                                          ),
                                        if (item.state != 1)
                                          const PopupMenuItem(
                                            value: 1,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.block,
                                                    color: Colors.orange),
                                                SizedBox(width: 8),
                                                Text('Mark as Skipped'),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedState,
        onDestinationSelected: (index) {
          setState(() {
            _selectedState = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.check_box_outline_blank),
            selectedIcon: Icon(Icons.check_box_outline_blank, color: Colors.blue),
            label: 'Open',
          ),
          NavigationDestination(
            icon: Icon(Icons.block),
            selectedIcon: Icon(Icons.block, color: Colors.orange),
            label: 'Skipped',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_box),
            selectedIcon: Icon(Icons.check_box, color: Colors.green),
            label: 'Done',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'todo_fab',
        onPressed: () => _openItemPage(null),
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openItemPage(TodoItem? item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TodoItemPage(
          database: widget.database,
          item: item,
        ),
      ),
    );
  }
}
