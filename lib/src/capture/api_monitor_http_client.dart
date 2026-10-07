import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/capture_source.dart';
import 'capture_pipeline.dart';

/// A drop-in replacement for `http.Client` that records every request.
///
/// ```dart
/// final client = ApiMonitor.instance.createHttpClient();
/// final response = await client.get(Uri.parse('https://example.com'));
/// ```
///
/// The request body is captured for [http.Request] (the common case) and
/// multipart field/file names. Streaming request bodies are not buffered.
class ApiMonitorHttpClient extends http.BaseClient {
  ApiMonitorHttpClient({required this.pipeline, http.Client? inner})
      : _inner = inner ?? http.Client();

  final CapturePipeline pipeline;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url;
    if (!pipeline.shouldCapture(url.toString())) {
      return _inner.send(request);
    }

    final bytes = _requestBodyBytes(request);
    final record = pipeline.begin(
      method: request.method,
      url: url,
      source: CaptureSource.http,
      headers: request.headers,
      body: bytes == null ? _describeMultipart(request) : null,
      bodyBytes: bytes,
    );

    try {
      final streamed = await _inner.send(request);
      final responseBytes = await http.ByteStream(streamed.stream).toBytes();
      pipeline.complete(
        record,
        statusCode: streamed.statusCode,
        headers: streamed.headers,
        bodyBytes: responseBytes,
      );
      return http.StreamedResponse(
        http.ByteStream.fromBytes(responseBytes),
        streamed.statusCode,
        contentLength: responseBytes.length,
        request: streamed.request,
        headers: streamed.headers,
        isRedirect: streamed.isRedirect,
        persistentConnection: streamed.persistentConnection,
        reasonPhrase: streamed.reasonPhrase,
      );
    } catch (error) {
      pipeline.complete(record, error: error.toString());
      rethrow;
    }
  }

  @override
  void close() => _inner.close();

  Uint8List? _requestBodyBytes(http.BaseRequest request) {
    if (request is http.Request) {
      return request.bodyBytes.isEmpty ? null : request.bodyBytes;
    }
    return null;
  }

  String? _describeMultipart(http.BaseRequest request) {
    if (request is! http.MultipartRequest) return null;
    final buffer = StringBuffer();
    request.fields.forEach((key, value) => buffer.writeln('$key=$value'));
    for (final file in request.files) {
      buffer.writeln(
        '${file.field}=<file:${file.filename ?? '(unnamed)'}, '
        '${file.length} bytes>',
      );
    }
    return buffer.toString().trimRight();
  }
}
