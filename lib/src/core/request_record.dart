import 'dart:convert';
import 'dart:typed_data';

import 'capture_source.dart';
import 'header_utils.dart';
import 'request_status.dart';
import 'response_type.dart';

/// A single captured HTTP call.
///
/// The record is mutable: it is created when the request is sent (status
/// [RequestStatus.pending]) and enriched in place once the response arrives or
/// an error occurs.
class RequestRecord {
  RequestRecord({
    required this.id,
    required this.method,
    required this.url,
    required this.startTime,
    this.requestHeaders = const {},
    this.requestBody,
    this.requestBodyBytes,
    this.source = CaptureSource.httpOverrides,
  }) : uri = Uri.tryParse(url);

  /// Monotonically increasing identifier, unique within a session.
  final int id;

  final String method;
  final String url;
  final Uri? uri;
  final DateTime startTime;
  final CaptureSource source;

  Map<String, String> requestHeaders;
  String? requestBody;
  Uint8List? requestBodyBytes;

  DateTime? endTime;
  int? statusCode;
  Map<String, String> responseHeaders = const {};
  String? responseBody;
  Uint8List? responseBodyBytes;
  String? error;
  RequestStatus status = RequestStatus.pending;

  /// Elapsed time, or time so far for a request still in flight.
  Duration get duration =>
      (endTime ?? DateTime.now()).difference(startTime);

  bool get isPending => status == RequestStatus.pending;
  bool get isSuccess => status == RequestStatus.success;
  bool get isError => status == RequestStatus.error;

  String get host => uri?.host ?? url;
  String get scheme => uri?.scheme ?? '';
  bool get isSecure => scheme == 'https';

  String get path {
    final u = uri;
    if (u == null || u.path.isEmpty) return '/';
    return u.path;
  }

  /// `path` plus query string, for compact display.
  String get pathWithQuery {
    final u = uri;
    if (u == null) return url;
    return u.hasQuery ? '${u.path}?${u.query}' : path;
  }

  String? get contentType => headerValue(responseHeaders, 'content-type');

  ResponseType get responseType =>
      ResponseType.detect(contentType: contentType, body: responseBody);

  ResponseType get requestType => ResponseType.detect(
        contentType: headerValue(requestHeaders, 'content-type'),
        body: requestBody,
      );

  /// Size of the response payload in bytes (best effort).
  int get responseSizeBytes {
    if (responseBodyBytes != null) return responseBodyBytes!.length;
    if (responseBody != null) return utf8.encode(responseBody!).length;
    return 0;
  }

  /// Size of the request payload in bytes (best effort).
  int get requestSizeBytes {
    if (requestBodyBytes != null) return requestBodyBytes!.length;
    if (requestBody != null) return utf8.encode(requestBody!).length;
    return 0;
  }

  /// Stable identity for de-duplicating captures across integrations.
  String get signature => '${method.toUpperCase()} $url';

  /// JSON safe representation used by the log exporters.
  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'url': url,
        'source': source.label,
        'startTime': startTime.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'status': status.name,
        'statusCode': statusCode,
        'requestHeaders': requestHeaders,
        'requestBody': requestBody,
        'responseHeaders': responseHeaders,
        'responseBody': responseBody,
        'responseType': responseType.label,
        'responseSizeBytes': responseSizeBytes,
        'error': error,
      };
}
