import 'dart:convert';
import 'dart:typed_data';

import '../core/api_monitor.dart';
import '../core/capture_source.dart';
import '../core/header_utils.dart';
import '../core/record_store.dart';
import '../core/request_record.dart';
import '../core/request_status.dart';
import '../core/response_type.dart';
import '../utils/formatters.dart';

/// Shared capture logic used by every integration (global `HttpOverrides`,
/// the Dio interceptor and the `package:http` client).
///
/// It owns body handling/truncation and the de-duplication that stops a request
/// from being logged twice when both an explicit integration and the global
/// interceptor are active.
class CapturePipeline {
  CapturePipeline(this.monitor);

  final ApiMonitor monitor;

  /// Signatures recently claimed by an explicit integration. The global
  /// interceptor skips matching requests so nothing is double logged.
  final Map<String, DateTime> _claims = <String, DateTime>{};
  static const Duration _claimTtl = Duration(seconds: 10);

  RecordStore get _store => monitor.store;

  /// Upper bound on bytes buffered from a single body while streaming.
  int get maxCapturedBytes => _store.maxBinaryBodyLength;

  /// Whether [url] is eligible for capture right now.
  bool shouldCapture(String url) => monitor.shouldCapture(url);

  String signatureOf(String method, Uri url) =>
      '${method.toUpperCase()} ${url.toString()}';

  /// True when an explicit integration already claimed this request.
  bool isClaimed(String method, Uri url) {
    _pruneClaims();
    return _claims.containsKey(signatureOf(method, url));
  }

  /// Creates and stores a new record in [CaptureSource.pending] state.
  RequestRecord begin({
    required String method,
    required Uri url,
    required CaptureSource source,
    Map<String, String>? headers,
    String? body,
    Uint8List? bodyBytes,
    bool claim = true,
  }) {
    if (claim && source != CaptureSource.httpOverrides) {
      _claims[signatureOf(method, url)] = DateTime.now();
    }

    final record = RequestRecord(
      id: _store.nextId(),
      method: method.toUpperCase(),
      url: url.toString(),
      startTime: DateTime.now(),
      requestHeaders: headers ?? const <String, String>{},
      source: source,
    );

    if (_store.captureBodies) {
      if (bodyBytes != null && bodyBytes.isNotEmpty) {
        if (_looksTextual(headers)) {
          record.requestBody = truncate(_decode(bodyBytes), _store.maxBodyLength);
        } else {
          record.requestBodyBytes = _clampBytes(bodyBytes);
        }
      } else if (body != null && body.isNotEmpty) {
        record.requestBody = truncate(body, _store.maxBodyLength);
      }
    }

    _store.add(record);
    _log('→ ${record.method} ${record.url}');
    monitor.notifyRecord(record);
    return record;
  }

  /// Convenience wrapper for the global interceptor that respects de-dup.
  RequestRecord? beginFromOverrides({
    required String method,
    required Uri url,
    Map<String, String>? headers,
    String? body,
    Uint8List? bodyBytes,
  }) {
    if (!shouldCapture(url.toString())) return null;
    if (isClaimed(method, url)) return null;
    return begin(
      method: method,
      url: url,
      source: CaptureSource.httpOverrides,
      headers: headers,
      body: body,
      bodyBytes: bodyBytes,
      claim: false,
    );
  }

  /// Marks [record] as completed with the response (or an error).
  void complete(
    RequestRecord record, {
    int? statusCode,
    Map<String, String>? headers,
    String? body,
    Uint8List? bodyBytes,
    String? error,
  }) {
    record.endTime = DateTime.now();
    if (headers != null) record.responseHeaders = headers;
    record.statusCode = statusCode;
    if (error != null) record.error = error;

    if (statusCode != null) {
      record.status =
          statusCode >= 400 ? RequestStatus.error : RequestStatus.success;
    } else {
      record.status =
          error != null ? RequestStatus.error : RequestStatus.success;
    }

    if (_store.captureBodies) {
      final type = ResponseType.detect(
        contentType: headerValue(record.responseHeaders, 'content-type'),
        body: body,
      );
      if (bodyBytes != null && bodyBytes.isNotEmpty) {
        if (type.isTextual) {
          record.responseBody =
              truncate(_decode(bodyBytes), _store.maxBodyLength);
        } else {
          record.responseBodyBytes = _clampBytes(bodyBytes);
        }
      } else if (body != null && body.isNotEmpty) {
        record.responseBody = truncate(body, _store.maxBodyLength);
      }
    }

    _store.touch(record);
    if (record.isError) {
      _log('✗ ${record.method} ${record.url} '
          '(${statusLabel(record.statusCode)}, ${formatDuration(record.duration)})'
          '${error != null ? ' $error' : ''}');
    } else {
      _log('← ${record.method} ${record.url} '
          '${statusLabel(record.statusCode)} '
          '(${formatDuration(record.duration)}, '
          '${formatBytes(record.responseSizeBytes)})');
    }
    monitor.notifyRecord(record);
  }

  // --- helpers ------------------------------------------------------------

  bool _looksTextual(Map<String, String>? headers) {
    final ct = headerValue(headers ?? const {}, 'content-type')?.toLowerCase();
    if (ct == null) return true;
    return !(ct.startsWith('image/') ||
        ct.startsWith('audio/') ||
        ct.startsWith('video/') ||
        ct.contains('octet-stream') ||
        ct.contains('protobuf'));
  }

  Uint8List _clampBytes(Uint8List bytes) {
    final limit = _store.maxBinaryBodyLength;
    if (limit <= 0 || bytes.length <= limit) return bytes;
    return Uint8List.sublistView(bytes, 0, limit);
  }

  String _decode(Uint8List bytes) => utf8.decode(bytes, allowMalformed: true);

  void _pruneClaims() {
    if (_claims.isEmpty) return;
    final now = DateTime.now();
    _claims.removeWhere((_, time) => now.difference(time) > _claimTtl);
  }

  void _log(String message) => monitor.log(message);
}
