import 'package:flutter/material.dart';

class TagEditor extends StatefulWidget {
  final List<String> tags;
  final List<String> availableTags;
  final ValueChanged<String> onTagAdded;
  final ValueChanged<String> onTagRemoved;
  final ValueChanged<String>? onInputChanged;
  final String? labelText;
  final String? hintText;
  final String initialInput;

  const TagEditor({
    super.key,
    required this.tags,
    required this.availableTags,
    required this.onTagAdded,
    required this.onTagRemoved,
    this.onInputChanged,
    this.labelText,
    this.hintText = 'Add tag',
    this.initialInput = '',
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

  void _refreshOptions(TextEditingController controller) {
    for (final tag in widget.availableTags) {
      if (!widget.tags.contains(tag)) {
        controller.value = TextEditingValue(
          text: tag,
          selection: TextSelection.collapsed(offset: tag.length),
        );
        controller.clear();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tag in widget.tags)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    label: Text('#$tag'),
                    onDeleted: () => widget.onTagRemoved(tag),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Autocomplete<String>(
                initialValue: TextEditingValue(text: widget.initialInput),
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
                    decoration: InputDecoration(
                      labelText: widget.labelText,
                      hintText: widget.hintText,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: widget.onInputChanged,
                    onTap: () {
                      if (controller.text.isEmpty && focusNode.hasFocus) {
                        _refreshOptions(controller);
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
