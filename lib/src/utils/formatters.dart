import 'dart:convert';

/// Formats a byte count as B / KB / MB.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Formats a [Duration] as ms / s / m.
String formatDuration(Duration duration) {
  final ms = duration.inMilliseconds;
  if (ms < 1000) return '$ms ms';
  final seconds = ms / 1000;
  if (seconds < 60) return '${seconds.toStringAsFixed(2)} s';
  final minutes = seconds / 60;
  return '${minutes.toStringAsFixed(1)} min';
}

/// Formats a wall-clock time as `HH:mm:ss.SSS`.
String formatTime(DateTime time) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}'
      '.${time.millisecond.toString().padLeft(3, '0')}';
}

/// Pretty prints a JSON string. Returns the input unchanged when it is not
/// valid JSON.
String prettyJson(String input) {
  try {
    final decoded = jsonDecode(input);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return input;
  }
}

/// Indents an XML/HTML string one tag per line. Best effort — it does not try
/// to be a real parser.
String prettyMarkup(String input) {
  final normalized = input.replaceAll(RegExp(r'>\s*<'), '>\n<');
  final buffer = StringBuffer();
  var depth = 0;
  for (final rawLine in normalized.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final isClosing = line.startsWith('</');
    final isSelfClosing = line.endsWith('/>');
    final isDeclaration = line.startsWith('<?') || line.startsWith('<!');
    if (isClosing && depth > 0) depth--;
    buffer.writeln('${'  ' * depth}$line');
    final isOpening = line.startsWith('<') &&
        !isClosing &&
        !isSelfClosing &&
        !isDeclaration &&
        !line.contains('</');
    if (isOpening) depth++;
  }
  return buffer.toString().trimRight();
}

/// Truncates [body] to [maxLength] characters, appending a marker when cut.
String truncate(String body, int maxLength) {
  if (maxLength <= 0 || body.length <= maxLength) return body;
  final removed = body.length - maxLength;
  return '${body.substring(0, maxLength)}\n\n… [$removed characters truncated]';
}

/// Colour-independent short label for a status code.
String statusLabel(int? statusCode) {
  if (statusCode == null) return '—';
  return '$statusCode';
}
