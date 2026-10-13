import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:travelassist3/widgets/large_text_dialog.dart';

class CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final int maxLines;
  final bool autofocus;
  final String labelText;
  final String? hintText;
  final String? Function(String?)? validator;

  const CommentInput({
    super.key,
    required this.controller,
    this.maxLines = 2,
    this.autofocus = false,
    this.labelText = 'Info',
    this.hintText,
    this.validator,
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
      autofocus: autofocus,
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
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
                showLargeTextDialog(
                  context,
                  controller.text,
                  emptyMessage: 'No info entered.',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
