import 'dart:io' show HttpHeaders;

/// Case-insensitive lookup for a header value.
String? headerValue(Map<String, String> headers, String name) {
  final target = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == target) return entry.value;
  }
  return null;
}

/// Returns true when [headers] already contains [name] (case-insensitive).
bool hasHeader(Map<String, String> headers, String name) =>
    headerValue(headers, name) != null;

/// Collapses a multi-value header map into a single-value map, joining values
/// with ", " which is the wire representation for most headers.
Map<String, String> flattenHeaders(Map<String, List<String>> headers) {
  final result = <String, String>{};
  headers.forEach((key, values) {
    result[key] = values.join(', ');
  });
  return result;
}

/// Same as [flattenHeaders] but for a `dart:io` `HttpHeaders`, which is not a
/// `Map` and exposes values through `forEach`.
Map<String, String> flattenHttpHeaders(HttpHeaders headers) {
  final result = <String, String>{};
  headers.forEach((name, values) => result[name] = values.join(', '));
  return result;
}
