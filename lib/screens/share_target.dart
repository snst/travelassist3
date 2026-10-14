import 'package:flutter/material.dart';

import '../database/database.dart';
import '../utils/date_format.dart';
import '../utils/shared_content.dart';
import '../utils/transaction_kind.dart';
import 'note_item_page.dart';

enum _ShareTarget { newNote, existingNote, existingExpense }

/// Lets the user decide what to do with [content] received from the share sheet:
/// a new note, or added to an existing note or expense.
Future<void> handleSharedContent(
  BuildContext context,
  AppDatabase database,
  SharedContent content,
) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final target = await showDialog<_ShareTarget>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Save shared content'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Text(
            [if (content.comment.isNotEmpty) content.comment, ...content.links].join('\n'),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, _ShareTarget.newNote),
          child: const ListTile(
            leading: Icon(Icons.note_add),
            title: Text('New note'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, _ShareTarget.existingNote),
          child: const ListTile(
            leading: Icon(Icons.note_alt),
            title: Text('Add to existing note'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, _ShareTarget.existingExpense),
          child: const ListTile(
            leading: Icon(Icons.shopping_bag_outlined),
            title: Text('Add to existing expense'),
          ),
        ),
      ],
    ),
  );
  if (target == null) return;

  switch (target) {
    case _ShareTarget.newNote:
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => NoteItemPage(
            database: database,
            initialLinks: content.links,
            initialComment: content.comment,
          ),
        ),
      );
    case _ShareTarget.existingNote:
      final note = await navigator.push<Note>(
        MaterialPageRoute(
          builder: (_) => _PickerPage<Note>(
            title: 'Add to note',
            stream: database.watchAllNotes(),
            itemTitle: (n) => n.comment.isNotEmpty ? n.comment : n.shortLink(),
            subtitle: (n) => n.tagList.map((t) => '#$t').join(' '),
            icon: (_) => Icons.note_alt,
          ),
        ),
      );
      if (note == null) return;
      await database.updateNoteEntry(
        note.copyWith(
          comment: appendComment(note.comment, content.comment),
          link: appendLinks(note.link, content.links),
        ),
      );
      messenger.showSnackBar(const SnackBar(content: Text('Added to note')));
    case _ShareTarget.existingExpense:
      final transaction = await navigator.push<MoneyTransaction>(
        MaterialPageRoute(
          builder: (_) => _PickerPage<MoneyTransaction>(
            title: 'Add to expense',
            stream: database
                .watchAllTransactions()
                .map((list) => list.where((t) => t.isSpending).toList()),
            itemTitle: (t) =>
                '${t.comment.isNotEmpty ? '${t.comment} – ' : ''}'
                '${t.amount.toStringAsFixed(2)} ${t.currency}',
            subtitle: (t) => [
              formatDateTime(t.date),
              ...t.tagList.map((tag) => '#$tag'),
            ].join('  '),
            icon: (t) => transactionIcon(t.type),
          ),
        ),
      );
      if (transaction == null) return;
      await database.updateTransactionEntry(
        transaction.copyWith(
          comment: appendComment(transaction.comment, content.comment),
          link: appendLinks(transaction.link, content.links),
        ),
      );
      messenger.showSnackBar(const SnackBar(content: Text('Added to expense')));
  }
}

/// A searchable list from which one item is picked.
class _PickerPage<T> extends StatefulWidget {
  final String title;
  final Stream<List<T>> stream;
  final String Function(T item) itemTitle;
  final String Function(T item) subtitle;
  final IconData Function(T item) icon;

  const _PickerPage({
    required this.title,
    required this.stream,
    required this.itemTitle,
    required this.subtitle,
    required this.icon,
  });

  @override
  State<_PickerPage<T>> createState() => _PickerPageState<T>();
}

class _PickerPageState<T> extends State<_PickerPage<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<T>>(
              stream: widget.stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!.where((item) {
                  final text = '${widget.itemTitle(item)} ${widget.subtitle(item)}'.toLowerCase();
                  return text.contains(_query);
                }).toList();
                if (items.isEmpty) {
                  return const Center(child: Text('Nothing found'));
                }
                return ListView.builder(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final subtitle = widget.subtitle(item);
                    return ListTile(
                      leading: Icon(widget.icon(item)),
                      title: Text(
                        widget.itemTitle(item),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: subtitle.isEmpty ? null : Text(subtitle),
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
