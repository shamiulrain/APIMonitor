import '../core/request_record.dart';

/// Builds a copy/pasteable cURL command that reproduces [record].
String buildCurl(RequestRecord record) {
  final buffer = StringBuffer("curl -X ${record.method.toUpperCase()}");

  record.requestHeaders.forEach((key, value) {
    if (key.toLowerCase() == 'content-length') return;
    buffer.write(" \\\n  -H '${_escape(key)}: ${_escape(value)}'");
  });

  final body = record.requestBody;
  if (body != null && body.isNotEmpty) {
    buffer.write(" \\\n  --data-raw '${_escape(body)}'");
  }

  buffer.write(" \\\n  '${_escape(record.url)}'");
  return buffer.toString();
}

String _escape(String value) => value.replaceAll("'", r"'\''");
