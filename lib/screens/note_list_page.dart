import 'package:flutter/material.dart';
import '../database/database.dart';
import '../widgets/tag_filter_bar.dart';
import 'note_actions.dart';
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

  void _openNote(Note note) {
    final links = note.linkList;
    if (links.isEmpty) {
      showNoteDialog(context, comment: note.comment, link: note.link);
    } else if (links.length == 1) {
      openNoteLink(context, links.first);
    } else {
      showNoteDialog(context, comment: note.comment, link: note.link);
    }
  }

  IconData _getNoteIcon(Note note) {
    if (note.isGeo || note.tagList.contains('map')) {
      return Icons.map_outlined;
    } else if (note.isLink || note.isFile) {
      return Icons.link;
    } else {
      return Icons.note_alt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedTags.isEmpty ? 'Travel Notes' : 'Filter: #${_selectedTags.join(', #')}',
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_selectedTags.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear Filters',
              onPressed: _clearFilters,
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
                            const Icon(Icons.note_alt, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _selectedTags.isEmpty
                                  ? 'No travel notes saved yet.'
                                  : 'No notes matching selected tags.',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _openNotePage(null),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Note'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          8,
                          12,
                          88 + MediaQuery.of(context).padding.bottom,
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
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) => _deleteNote(note),
                            child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              onTap: () => _openNotePage(note),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHigh,
                                child: Icon(_getNoteIcon(note)),
                              ),
                              title: Text(
                                note.comment.isNotEmpty
                                    ? note.comment
                                    : note.shortLink(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (note.comment.isNotEmpty &&
                                      note.linkList.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        note.linksSummary(),
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.blueAccent),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (noteTags.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 2,
                                      children: noteTags.map((tag) {
                                        final isSelected =
                                            _selectedTags.contains(tag);
                                        return InkWell(
                                          onTap: () => _toggleTagFilter(tag),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
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
                                              '#$tag',
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
                                icon: Icon(note.linkList.isNotEmpty
                                    ? (note.linkList.length == 1
                                        ? Icons.open_in_new
                                        : Icons.list_alt)
                                    : Icons.visibility_outlined),
                                tooltip: note.linkList.isNotEmpty
                                    ? (note.linkList.length == 1
                                        ? 'Open Link'
                                        : 'View Links')
                                    : 'View',
                                onPressed: () => _openNote(note),
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton(
          heroTag: 'notes_fab',
          onPressed: () => _openNotePage(null),
          tooltip: 'Add Note',
          child: const Icon(Icons.add),
        ),
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
