import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final List<TextEditingController> _linkControllers = [];
  TextEditingController? _tagInputController;

  late List<String> _tags;
  List<String> _availableTags = [];

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _commentController = TextEditingController(text: note?.comment ?? '');

    final initialLinks = note?.linkList ?? [];
    if (initialLinks.isNotEmpty) {
      for (final link in initialLinks) {
        _linkControllers.add(TextEditingController(text: link));
      }
    } else {
      _linkControllers.add(TextEditingController());
    }

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
    for (final controller in _linkControllers) {
      controller.dispose();
    }
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

  void _addLink([String text = '']) {
    setState(() {
      _linkControllers.add(TextEditingController(text: text));
    });
  }

  void _removeLink(int index) {
    setState(() {
      final controller = _linkControllers.removeAt(index);
      controller.dispose();
    });
  }

  Future<void> _confirmDeleteLink(int index) async {
    final linkText = _linkControllers[index].text.trim();
    if (linkText.isEmpty) {
      _removeLink(index);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Link'),
        content: Text(
          'Are you sure you want to delete this link?\n\n$linkText',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _removeLink(index);
    }
  }

  Future<void> _addLinkFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text?.trim() ?? '';
    if (!mounted) return;

    if (text.isNotEmpty) {
      final newLinks = text
          .split(RegExp(r'[\t\r\n]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (newLinks.isNotEmpty) {
        setState(() {
          for (final linkText in newLinks) {
            final emptyIndex =
                _linkControllers.indexWhere((c) => c.text.trim().isEmpty);
            if (emptyIndex != -1) {
              _linkControllers[emptyIndex].text = linkText;
            } else {
              _linkControllers.add(TextEditingController(text: linkText));
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${newLinks.length} ${newLinks.length == 1 ? 'link' : 'links'} added from clipboard!',
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clipboard is empty or contains no text.'),
        ),
      );
    }
  }

  Future<void> _attachCurrentGpsLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (!mounted) return;
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied.')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fetching current GPS location...'),
        duration: Duration(seconds: 1),
      ),
    );

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    if (!mounted) return;
    final geoString = 'geo:${position.latitude},${position.longitude}';
    setState(() {
      final emptyIndex =
          _linkControllers.indexWhere((c) => c.text.trim().isEmpty);
      if (emptyIndex != -1) {
        _linkControllers[emptyIndex].text = geoString;
      } else {
        _linkControllers.add(TextEditingController(text: geoString));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GPS location attached!')),
    );
  }

  String _buildJoinedLinkString() {
    return _linkControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .join('\t');
  }

  void _showLargeDisplayDialog() {
    showNoteDialog(
      context,
      comment: _commentController.text.trim(),
      link: _buildJoinedLinkString(),
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
              /*const Text(
                'Tags',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),*/
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
                      onSelected: (selection) {
                        _addTag(selection);
                        _tagInputController?.clear();
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onEditingComplete) {
                        _tagInputController = controller;
                        focusNode.addListener(() {
                          if (focusNode.hasFocus && controller.text.isEmpty) {
                            controller.value = controller.value;
                          }
                        });
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            hintText: 'Add tag (e.g. hotel, map, important)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onTap: () {
                            if (controller.text.isEmpty) {
                              controller.value = controller.value;
                            }
                          },
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
                      if (_tagInputController != null) {
                        _addTag(_tagInputController!.text);
                        _tagInputController!.clear();
                      }
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
                  final commentText = value?.trim() ?? '';
                  final hasLinks =
                      _linkControllers.any((c) => c.text.trim().isNotEmpty);
                  if (commentText.isEmpty && !hasLinks) {
                    return 'Please enter a note or at least one link';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Links Section
             /* Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Links / Locations',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '${_linkControllers.length} ${_linkControllers.length == 1 ? 'link' : 'links'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),*/

              if (_linkControllers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'No links added yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _linkControllers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final controller = _linkControllers[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: controller,
                            decoration: InputDecoration(
                              labelText: 'Link ${index + 1}',
                              hintText: 'https://... or geo:lat,lng',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new),
                          tooltip: 'Open Link',
                          onPressed: () =>
                              openNoteLink(context, controller.text),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy Link',
                          onPressed: () => copyNoteText(
                            context,
                            controller.text,
                            'Link',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          tooltip: 'Remove Link',
                          onPressed: () => _confirmDeleteLink(index),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 12),

              // Link Action Buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _addLinkFromClipboard,
                    icon: const Icon(Icons.assignment_turned_in_outlined),
                    label: const Text('Paste'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _addLink(),
                    icon: const Icon(Icons.add_link),
                    label: const Text('New'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _attachCurrentGpsLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('GPS'),
                  ),
                ],
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
      final link = _buildJoinedLinkString();

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
