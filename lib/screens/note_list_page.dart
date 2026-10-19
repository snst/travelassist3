import 'package:flutter/material.dart';

import '../database/database.dart';
import '../widgets/large_text_dialog.dart';
import '../widgets/tag_filter_bar.dart';
import 'note_item_page.dart';

class NoteListPage extends StatefulWidget {
  final AppDatabase database;
  final List<String> initialFilterTags;

  const NoteListPage({
    super.key,
    required this.database,
    this.initialFilterTags = const [],
  });

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  late List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.initialFilterTags);
  }

  void _toggleTagFilter(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedTags.clear();
    });
  }

  Future<void> _deleteNote(Note note) async {
    final messenger = ScaffoldMessenger.of(context);
    await widget.database.deleteNote(note.id);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Note deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => widget.database.restoreNote(note),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedTags.isEmpty
              ? 'Travel Notes'
              : 'Filter: ${_selectedTags.join(', ')}',
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_selectedTags.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear Filters',
              onPressed: _clearFilters,
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Note',
            onPressed: () => _openNotePage(null),
          ),
        ],
      ),
      body: StreamBuilder<List<Note>>(
        stream: widget.database.watchAllNotes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allNotes = snapshot.data ?? [];

          // Filter notes according to selected tags
          final filteredNotes = allNotes.where((note) {
            final noteTags = note.tagList;
            return _selectedTags.every(noteTags.contains);
          }).toList();

          // Offer only tags of the filtered notes (plus the active ones) to narrow down
          final tagSet = <String>{..._selectedTags};
          for (final note in filteredNotes) {
            tagSet.addAll(note.tagList);
          }
          final sortedTags = tagSet.toList()..sort();

          return Column(
            children: [
              Expanded(
                child: filteredNotes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.note_alt,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedTags.isEmpty
                                  ? 'No travel notes saved yet.'
                                  : 'No notes matching selected tags.',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          8,
                          12,
                          8 + MediaQuery.of(context).padding.bottom,
                        ),
                        itemCount: filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = filteredNotes[index];
                          final noteTags = note.tagList;

                          return Dismissible(
                            key: ValueKey(note.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              color: Colors.red,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (_) => _deleteNote(note),
                            child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                onTap: () => _openNotePage(note),
                                title: note.comment.isNotEmpty
                                    ? Text(
                                        note.comment,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ...note.linkList.map(
                                      (link) => Text(
                                        link,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.left,
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                        ),
                                      ),
                                    ),
                                    if (noteTags.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        children: noteTags.map((tag) {
                                          final isSelected = _selectedTags
                                              .contains(tag);
                                          return InkWell(
                                            onTap: () => _toggleTagFilter(tag),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? Theme.of(context)
                                                          .colorScheme
                                                          .primaryContainer
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainerHigh,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                tag,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                      : Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.visibility_outlined),
                                  tooltip: 'View Info',
                                  onPressed: () {
                                    showLargeTextDialog(
                                      context,
                                      note.comment,
                                      emptyMessage: 'No info entered.',
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              TagFilterBar(
                tags: sortedTags,
                selectedTags: _selectedTags,
                onTagSelected: _toggleTagFilter,
                onClear: _clearFilters,
              ),
            ],
          );
        },
      ),
    );
  }

  void _openNotePage(Note? note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NoteItemPage(
          database: widget.database,
          note: note,
          initialTags: _selectedTags,
        ),
      ),
    );
  }
}
