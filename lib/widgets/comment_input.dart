import 'package:flutter/material.dart';

class CommentInput extends StatelessWidget {
  final TextEditingController controller;

  const CommentInput({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'Comment',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }
}
