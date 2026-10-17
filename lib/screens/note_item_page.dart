import 'dart:async';

import 'package:flutter/material.dart';

import '../database/database.dart';
import '../widgets/comment_input.dart';
import '../widgets/link_editor.dart';
import '../widgets/tag_editor.dart';

class NoteItemPage extends StatefulWidget {
  final AppDatabase database;
  final Note? note;
  final List<String> initialTags;
  final bool captureGpsLocation;

  /// Prefill for a new note, e.g. content received from the share sheet.
  final List<String> initialLinks;
  final String initialComment;

  const NoteItemPage({
    super.key,
    required this.database,
    this.note,
    this.initialTags = const [],
    this.captureGpsLocation = false,
    this.initialLinks = const [],
    this.initialComment = '',
  });

  @override
  State<NoteItemPage> createState() => _NoteItemPageState();
}

class _NoteItemPageState extends State<NoteItemPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _commentController;
  late final LinkListController _links;

  late List<String> _tags;
  List<String> _availableTags = [];
  bool _gpsCaptureStarted = false;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _commentController =
        TextEditingController(text: note?.comment ?? widget.initialComment);

    _links = LinkListController(note?.linkList ?? widget.initialLinks);

    if (note != null) {
      _tags = note.tagList;
    } else {
      _tags = List.from(widget.initialTags);
    }

    _loadAvailableTags();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.captureGpsLocation && !_gpsCaptureStarted) {
      _gpsCaptureStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_captureGpsLocation());
      });
    }
  }

  Future<void> _captureGpsLocation() async {
    try {
      await LinkEditor.attachCurrentGpsLocation(context, _links);
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get GPS location: $error')),
      );
    }
  }

  Future<void> _loadAvailableTags() async {
    final tags = await widget.database.getAllNoteTags();
    if (mounted) {
      setState(() {
        _availableTags = tags;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _links.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmed = tag.trim().replaceAll('#', '').toLowerCase();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() {
        _tags.add(trimmed);
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.note == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Add Note' : 'Edit Note'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete Note',
              onPressed: _confirmDelete,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: isNew ? 'Save Note' : 'Update Note',
            onPressed: _saveNote,
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
              TagEditor(
                tags: _tags,
                availableTags: _availableTags,
                onTagAdded: _addTag,
                onTagRemoved: _removeTag,
              ),
              // Comment Section
              CommentInput(
                controller: _commentController,
                maxLines: 4,
                autofocus: isNew,
                validator: (value) {
                  final commentText = value?.trim() ?? '';
                  final hasLinks = _links.hasLinks;
                  if (commentText.isEmpty && !hasLinks) {
                    return 'Please enter a note or at least one link';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              LinkEditor(controller: _links),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: _saveNote,
                icon: const Icon(Icons.save),
                label: Text(
                  isNew ? 'Save Note' : 'Update Note',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveNote() async {
    if (_formKey.currentState!.validate()) {
      final comment = _commentController.text.trim();
      final link = _links.joined;

      if (widget.note == null) {
        await widget.database.addNote(
          comment: comment,
          link: link,
          tags: _tags,
        );
      } else {
        final tagString = _tags.join(',');
        final updated = widget.note!.copyWith(
          comment: comment,
          link: link,
          tags: tagString,
        );
        await widget.database.updateNoteEntry(updated);
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
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await widget.database.deleteNote(widget.note!.id);
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
