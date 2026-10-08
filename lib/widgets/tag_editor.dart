import 'package:flutter/material.dart';

class TagEditor extends StatefulWidget {
  final List<String> tags;
  final List<String> availableTags;
  final ValueChanged<String> onTagAdded;
  final ValueChanged<String> onTagRemoved;

  const TagEditor({
    super.key,
    required this.tags,
    required this.availableTags,
    required this.onTagAdded,
    required this.onTagRemoved,
  });

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  TextEditingController? _inputController;

  void _addTag(String tag) {
    widget.onTagAdded(tag);
    _inputController?.clear();
  }

  void _refreshOptions(FocusNode focusNode) {
    focusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && focusNode.context != null) {
        focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ...widget.tags.map(
              (tag) => Chip(
                label: Text('#$tag'),
                onDeleted: () => widget.onTagRemoved(tag),
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
                    return widget.availableTags
                        .where((tag) => !widget.tags.contains(tag));
                  }
                  return widget.availableTags.where(
                    (tag) =>
                        !widget.tags.contains(tag) &&
                        tag.toLowerCase().contains(
                              textValue.text.toLowerCase(),
                            ),
                  );
                },
                onSelected: _addTag,
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                  _inputController = controller;
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Add tag (e.g. hotel, map, important)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onTap: () {
                      if (controller.text.isEmpty && focusNode.hasFocus) {
                        _refreshOptions(focusNode);
                      }
                    },
                    onSubmitted: _addTag,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.add),
              onPressed: () {
                final controller = _inputController;
                if (controller != null) {
                  _addTag(controller.text);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
