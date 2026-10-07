import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/request_record.dart';
import '../utils/curl_builder.dart';

/// Shares [text] through the platform share sheet.
Future<void> shareText(String text, {String? subject}) =>
    Share.share(text, subject: subject);

/// Copies [text] to the clipboard and shows a confirmation snack bar.
Future<void> copyToClipboard(
  BuildContext context,
  String text, {
  String message = 'Copied to clipboard',
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
  );
}

/// Human readable log for a single record, mirroring Netfox's "simple log".
String buildSimpleLog(RequestRecord record) {
  final buffer = StringBuffer()
    ..writeln('${record.method} ${record.url}')
    ..writeln('Status: ${record.statusCode ?? '—'} '
        '(${record.status.name})')
    ..writeln('Duration: ${record.duration.inMilliseconds} ms')
    ..writeln('Response size: ${record.responseSizeBytes} bytes')
    ..writeln()
    ..writeln('--- Request headers ---');
  record.requestHeaders.forEach((k, v) => buffer.writeln('$k: $v'));
  if (record.requestBody != null) {
    buffer
      ..writeln()
      ..writeln('--- Request body ---')
      ..writeln(record.requestBody);
  }
  buffer
    ..writeln()
    ..writeln('--- Response headers ---');
  record.responseHeaders.forEach((k, v) => buffer.writeln('$k: $v'));
  if (record.responseBody != null) {
    buffer
      ..writeln()
      ..writeln('--- Response body ---')
      ..writeln(record.responseBody);
  }
  if (record.error != null) {
    buffer
      ..writeln()
      ..writeln('--- Error ---')
      ..writeln(record.error);
  }
  return buffer.toString();
}

/// Machine readable JSON log for a single record.
String buildJsonLog(RequestRecord record) =>
    const JsonEncoder.withIndent('  ').convert(record.toJson());

/// cURL command reproducing the request.
String buildCurlLog(RequestRecord record) => buildCurl(record);
