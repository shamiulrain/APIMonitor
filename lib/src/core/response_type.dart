/// The kind of payload a response carried. Used for the response-type filter
/// and for deciding how a body should be rendered.
enum ResponseType {
  json('JSON'),
  xml('XML'),
  html('HTML'),
  image('Image'),
  text('Text'),
  other('Other');

  const ResponseType(this.label);

  /// Human readable label shown in the UI.
  final String label;

  /// Whether the body can be shown as formatted text.
  bool get isTextual =>
      this == ResponseType.json ||
      this == ResponseType.xml ||
      this == ResponseType.html ||
      this == ResponseType.text;

  /// Detects the [ResponseType] from a `content-type` header, falling back to
  /// sniffing the first bytes of the body when the header is missing or vague.
  static ResponseType detect({String? contentType, String? body}) {
    final ct = (contentType ?? '').toLowerCase();

    if (ct.contains('json')) return ResponseType.json;
    if (ct.contains('xml')) return ResponseType.xml;
    if (ct.contains('html')) return ResponseType.html;
    if (ct.startsWith('image/') || ct.contains('image')) {
      return ResponseType.image;
    }
    if (ct.startsWith('audio/') || ct.startsWith('video/')) {
      return ResponseType.other;
    }
    if (ct.startsWith('text/') ||
        ct.contains('javascript') ||
        ct.contains('x-www-form-urlencoded')) {
      return ResponseType.text;
    }

    final trimmed = body?.trimLeft();
    if (trimmed != null && trimmed.isNotEmpty) {
      final first = trimmed.codeUnitAt(0);
      if (first == 0x7B /* { */ || first == 0x5B /* [ */) {
        return ResponseType.json;
      }
      if (trimmed.startsWith('<?xml')) return ResponseType.xml;
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('<!doctype') || lower.startsWith('<html')) {
        return ResponseType.html;
      }
    }

    return ResponseType.other;
  }
}
