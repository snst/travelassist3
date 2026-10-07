import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Uri? _toUri(String text) {
  final lower = text.toLowerCase();
  if (lower.startsWith('geo:')) {
    final pos = text.substring(4);
    return pos.contains('?') ? Uri.tryParse(text) : Uri.tryParse('geo:$pos?q=$pos(Here)');
  }
  if (text.startsWith('/')) return Uri.file(text);
  return Uri.tryParse(text);
}

// Fallback for platforms without a geo: handler (desktop, web).
Uri? _openStreetMapUri(String geo) {
  final parts = geo.substring(4).split('?').first.split(',');
  if (parts.length < 2) return null;
  final lat = double.tryParse(parts[0]);
  final lon = double.tryParse(parts[1]);
  if (lat == null || lon == null) return null;
  return Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=16/$lat/$lon');
}

Future<bool> _tryLaunch(Uri? uri) async {
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<void> openNoteLink(BuildContext context, String link) async {
  final text = link.trim();
  if (text.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);

  var launched = await _tryLaunch(_toUri(text));
  if (!launched && text.toLowerCase().startsWith('geo:')) {
    launched = await _tryLaunch(_openStreetMapUri(text));
  }
  if (!launched) {
    messenger.showSnackBar(SnackBar(content: Text('Could not open $text')));
  }
}

void copyNoteText(BuildContext context, String text, String label) {
  if (text.trim().isEmpty) return;
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label copied to clipboard')),
  );
}

Future<void> showNoteDialog(
  BuildContext context, {
  required String comment,
  required String link,
}) {
  final links = link
      .split('\t')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Note View'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (comment.isNotEmpty) ...[
              const Text(
                'Comment / Note:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              SelectableText(
                comment,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
            ],
            if (links.isNotEmpty) ...[
              Text(
                links.length > 1 ? 'Links / Locations:' : 'Link / Location:',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              for (final l in links) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          l,
                          style: const TextStyle(fontSize: 20, color: Colors.blueAccent),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: 'Copy Link',
                        onPressed: () => copyNoteText(context, l, 'Link'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new),
                        tooltip: 'Open Link',
                        onPressed: () => openNoteLink(context, l),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (comment.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Note',
            onPressed: () => copyNoteText(context, comment, 'Note'),
          ),
        if (links.length == 1)
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open Link',
            onPressed: () => openNoteLink(context, links.first),
          ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
