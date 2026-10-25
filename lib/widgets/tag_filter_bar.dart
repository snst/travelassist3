import 'package:flutter/material.dart';

import '../database/database.dart';

class TagFilterBar extends StatelessWidget {
  final List<String> tags;
  final List<String> selectedTags;
  final ValueChanged<String> onTagSelected;
  final VoidCallback onClear;

  const TagFilterBar({
    super.key,
    required this.tags,
    required this.selectedTags,
    required this.onTagSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final orderedTags = [
      if (tags.contains(starTag)) starTag,
      if (tags.contains(positionTag)) positionTag,
      ...tags.where((tag) => tag != starTag && tag != positionTag),
    ];

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (selectedTags.isNotEmpty)
                InkWell(
                  onTap: onClear,
                  child: const Text(
                    'Clear filter',
                    style: TextStyle(fontSize: 12, color: Colors.blueAccent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: orderedTags.map((tag) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(tag),
                    selected: selectedTags.contains(tag),
                    onSelected: (_) => onTagSelected(tag),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
