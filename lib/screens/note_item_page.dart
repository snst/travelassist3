import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../database/database.dart';
import 'note_actions.dart';

class NoteItemPage extends StatefulWidget {
  final AppDatabase database;
  final Note? note;
  final List<String> initialTags;

  const NoteItemPage({
    super.key,
    required this.database,
    this.note,
    this.initialTags = const [],
  });

  @override
  State<NoteItemPage> createState() => _NoteItemPageState();
}

class _NoteItemPageState extends State<NoteItemPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _commentController;
  late final TextEditingController _linkController;
  late final TextEditingController _tagInputController;

  late List<String> _tags;
  List<String> _availableTags = [];

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _commentController = TextEditingController(text: note?.comment ?? '');
    _linkController = TextEditingController(text: note?.link ?? '');
    _tagInputController = TextEditingController();

    if (note != null) {
      _tags = note.tagList;
    } else {
      _tags = List.from(widget.initialTags);
    }

    _loadAvailableTags();
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
    _linkController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmed = tag.trim().replaceAll('#', '').toLowerCase();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() {
        _tags.add(trimmed);
        _tagInputController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _attachCurrentGpsLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
        return;
      }

      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Fetching current GPS location...'), duration: Duration(seconds: 1)),
      );

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _linkController.text = 'geo:${position.latitude},${position.longitude}';
      });
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('GPS location attached!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    }
  }

  void _showLargeDisplayDialog() {
    showNoteDialog(
      context,
      comment: _commentController.text.trim(),
      link: _linkController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.note == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Add Note' : 'Edit Note'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Large Display View',
            onPressed: _showLargeDisplayDialog,
          ),
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete Note',
              onPressed: _confirmDelete,
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
              // Tags Section
              const Text(
                'Tags',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ..._tags.map(
                    (tag) => Chip(
                      label: Text('#$tag'),
                      onDeleted: () => _removeTag(tag),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Autocomplete<String>(
                      optionsBuilder: (textValue) {
                        if (textValue.text.isEmpty) {
                          return _availableTags
                              .where((t) => !_tags.contains(t));
                        }
                        return _availableTags.where((t) =>
                            !_tags.contains(t) &&
                            t.toLowerCase().contains(
                                textValue.text.toLowerCase()));
                      },
                      onSelected: (selection) => _addTag(selection),
                      fieldViewBuilder:
                          (context, controller, focusNode, onEditingComplete) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            hintText: 'Add tag (e.g. hotel, map, important)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (value) {
                            _addTag(value);
                            controller.clear();
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      _addTag(_tagInputController.text);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Comment Section
              TextFormField(
                controller: _commentController,
                maxLines: 4,
                autofocus: isNew,
                decoration: const InputDecoration(
                  labelText: 'Note / Comment',
                  hintText: 'Enter hotel address, flight details, or travel note...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if ((value == null || value.trim().isEmpty) &&
                      _linkController.text.trim().isEmpty) {
                    return 'Please enter a note or link';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Link Section
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _linkController,
                      decoration: const InputDecoration(
                        labelText: 'Link / Location (optional)',
                        hintText: 'https://... or geo:lat,lng',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    icon: const Icon(Icons.open_in_new),
                    tooltip: 'Open Link',
                    onPressed: () =>
                        openNoteLink(context, _linkController.text),
                  ),
                  IconButton.outlined(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy Link',
                    onPressed: () =>
                        copyNoteText(context, _linkController.text, 'Link'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _attachCurrentGpsLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Attach Current GPS Location'),
              ),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      final link = _linkController.text.trim();

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
