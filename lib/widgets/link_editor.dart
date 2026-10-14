import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../screens/note_actions.dart';

enum _LinkItemAction { copy, remove }

/// Holds the editable list of links shown by [LinkEditor].
class LinkListController extends ChangeNotifier {
  final List<TextEditingController> _fields = [];

  /// Starts with [initialLinks], or one empty field if there are none.
  LinkListController([List<String> initialLinks = const []]) {
    for (final link in initialLinks) {
      _fields.add(TextEditingController(text: link));
    }
    if (_fields.isEmpty) _fields.add(TextEditingController());
  }

  List<TextEditingController> get fields => List.unmodifiable(_fields);

  bool get hasLinks => _fields.any((c) => c.text.trim().isNotEmpty);

  /// The non-empty links, tab separated, as stored on a note.
  String get joined => _fields
      .map((c) => c.text.trim())
      .where((t) => t.isNotEmpty)
      .join('\t');

  void add([String text = '']) {
    _fields.add(TextEditingController(text: text));
    notifyListeners();
  }

  /// Fills empty fields first, then appends new ones.
  void addAll(Iterable<String> links) {
    for (final link in links) {
      final empty = _fields.indexWhere((c) => c.text.trim().isEmpty);
      if (empty != -1) {
        _fields[empty].text = link;
      } else {
        _fields.add(TextEditingController(text: link));
      }
    }
    notifyListeners();
  }

  void removeAt(int index) {
    final removed = _fields.removeAt(index);
    notifyListeners();
    // The field is still mounted until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }
}

/// Shows the links of [controller] and lets the user add (paste, new, GPS),
/// open, copy and remove them.
class LinkEditor extends StatelessWidget {
  final LinkListController controller;

  const LinkEditor({super.key, required this.controller});

  Future<void> _confirmRemove(BuildContext context, int index) async {
    final text = controller.fields[index].text.trim();
    if (text.isEmpty) {
      controller.removeAt(index);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Link'),
        content: Text('Are you sure you want to delete this link?\n\n$text'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) controller.removeAt(index);
  }

  Future<void> _pasteFromClipboard(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final newLinks = text
        .split(RegExp(r'[\t\r\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (newLinks.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Clipboard is empty or contains no text.'),
        ),
      );
      return;
    }

    controller.addAll(newLinks);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${newLinks.length} ${newLinks.length == 1 ? 'link' : 'links'} added from clipboard!',
        ),
      ),
    );
  }

  static Future<void> attachCurrentGpsLocation(
    BuildContext context,
    LinkListController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String message, {Duration? duration}) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration ?? const Duration(seconds: 4),
        ),
      );
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      say('Location services are disabled.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        say('Location permissions are denied.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      say('Location permissions are permanently denied.');
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    if (!context.mounted) return;
    controller.addAll(['geo:${position.latitude},${position.longitude}']);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final fields = controller.fields;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (fields.isEmpty)
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
                itemCount: fields.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final field = fields[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: field,
                          decoration: InputDecoration(
                            labelText: 'Link ${index + 1}',
                            hintText: 'https://... or geo:lat,lng',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Open Link',
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => openNoteLink(context, field.text),
                      ),
                      PopupMenuButton<_LinkItemAction>(
                        tooltip: 'Actions for Link ${index + 1}',
                        icon: const Icon(Icons.more_vert),
                        onSelected: (action) async {
                          switch (action) {
                            case _LinkItemAction.copy:
                              copyNoteText(context, field.text, 'Link');
                            case _LinkItemAction.remove:
                              await _confirmRemove(context, index);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _LinkItemAction.copy,
                            child: Row(
                              children: [
                                Icon(Icons.copy),
                                SizedBox(width: 12),
                                Text('Copy Link'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _LinkItemAction.remove,
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Remove Link'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pasteFromClipboard(context),
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('Paste'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.add,
                  icon: const Icon(Icons.add_link),
                  label: const Text('New'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      attachCurrentGpsLocation(context, controller),
                  icon: const Icon(Icons.my_location),
                  label: const Text('GPS'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
