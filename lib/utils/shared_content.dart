import 'package:flutter/services.dart';

/// Links and text received from the Android share sheet.
class SharedContent {
  /// Shared photo URIs and URLs found in the shared text.
  final List<String> links;

  /// Shared text without the URLs, e.g. the page title of a shared web page.
  final String comment;

  const SharedContent({this.links = const [], this.comment = ''});

  bool get isEmpty => links.isEmpty && comment.isEmpty;

  static final _urlPattern = RegExp(r'https?://\S+', caseSensitive: false);

  factory SharedContent.fromRaw({
    Iterable<String> texts = const [],
    Iterable<String> uris = const [],
  }) {
    final links = <String>[];
    final comments = <String>[];
    for (final text in texts) {
      links.addAll(_urlPattern.allMatches(text).map((m) => m.group(0)!));
      final rest = text.replaceAll(_urlPattern, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (rest.isNotEmpty) comments.add(rest);
    }
    links.addAll(uris.map((u) => u.trim()).where((u) => u.isNotEmpty));
    return SharedContent(
      links: links.toSet().toList(),
      comment: comments.join('\n'),
    );
  }

  static SharedContent? fromChannel(Object? arguments) {
    if (arguments is! Map) return null;
    final content = SharedContent.fromRaw(
      texts: (arguments['texts'] as List?)?.whereType<String>() ?? const [],
      uris: (arguments['uris'] as List?)?.whereType<String>() ?? const [],
    );
    return content.isEmpty ? null : content;
  }
}

/// [existing] tab separated links plus the not yet contained [added] ones.
String appendLinks(String existing, Iterable<String> added) {
  final links = existing
      .split('\t')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  for (final link in added) {
    if (!links.contains(link)) links.add(link);
  }
  return links.join('\t');
}

String appendComment(String existing, String added) {
  if (added.isEmpty || existing.contains(added)) return existing;
  return existing.trim().isEmpty ? added : '${existing.trimRight()}\n$added';
}

/// Bridge to the Android activity for incoming shares and opening content URIs.
class ShareChannel {
  static const _channel = MethodChannel('de.meek.travelassist3/share');

  /// Calls [onShare] for shares arriving while the app is running.
  static void listen(void Function(SharedContent content) onShare) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onShare') return;
      final content = SharedContent.fromChannel(call.arguments);
      if (content != null) onShare(content);
    });
  }

  /// The share that started the app, if any.
  static Future<SharedContent?> initialShare() async {
    try {
      return SharedContent.fromChannel(await _channel.invokeMethod('getInitialShare'));
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Opens a `content://` URI in the default viewer (the gallery for photos).
  static Future<bool> openUri(String uri) async {
    try {
      return await _channel.invokeMethod<bool>('openUri', uri) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
