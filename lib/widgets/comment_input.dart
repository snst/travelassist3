import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final int maxLines;

  const CommentInput({
    super.key,
    required this.controller,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    Future<void> copyText() async {
      await Clipboard.setData(ClipboardData(text: controller.text));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Info copied to clipboard')),
      );
    }

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: 'Info',
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.content_copy),
              tooltip: 'Copy info',
              onPressed: copyText,
            ),
            IconButton(
              icon: const Icon(Icons.open_in_full),
              tooltip: 'Show large text',
              onPressed: () {
                FocusScope.of(context).unfocus();
                final text = controller.text;
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) => Dialog.fullscreen(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: Scaffold(
                        body: SafeArea(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                text.isEmpty ? 'No info entered.' : text,
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
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
