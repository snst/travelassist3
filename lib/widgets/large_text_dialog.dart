import 'package:flutter/material.dart';

Future<void> showLargeTextDialog(
  BuildContext context,
  String text, {
  String emptyMessage = 'No text entered.',
  List<String> links = const [],
  Future<void> Function(BuildContext context, String link)? onOpenLink,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog.fullscreen(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        text.isEmpty ? emptyMessage : text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (links.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: links.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final link = links[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          link,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: onOpenLink == null
                            ? null
                            : IconButton(
                                tooltip: 'Open Link',
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () =>
                                    onOpenLink(dialogContext, link),
                              ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
