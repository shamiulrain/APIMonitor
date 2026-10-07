import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/capture_source.dart';
import '../core/request_record.dart';
import 'capture_pipeline.dart';

/// Dio interceptor that feeds requests and responses into [CapturePipeline].
///
/// Add it with `dio.interceptors.add(ApiMonitor.instance.dioInterceptor)` or
/// `ApiMonitor.instance.attachDio(dio)`.
class ApiMonitorDioInterceptor extends Interceptor {
  ApiMonitorDioInterceptor(this.pipeline);

  final CapturePipeline pipeline;

  static const String _recordKey = '__api_monitor_record';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!pipeline.shouldCapture(options.uri.toString())) {
      return handler.next(options);
    }

    final captured = _encodeBody(options.data);
    final record = pipeline.begin(
      method: options.method,
      url: options.uri,
      source: CaptureSource.dio,
      headers: _stringifyHeaders(options.headers),
      body: captured.text,
      bodyBytes: captured.bytes,
    );
    options.extra[_recordKey] = record;
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final record = response.requestOptions.extra[_recordKey] as RequestRecord?;
    if (record != null) {
      final captured = _encodeBody(response.data);
      pipeline.complete(
        record,
        statusCode: response.statusCode,
        headers: _flattenHeaders(response.headers.map),
        body: captured.text,
        bodyBytes: captured.bytes,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final record = err.requestOptions.extra[_recordKey] as RequestRecord?;
    if (record != null) {
      final captured = _encodeBody(err.response?.data);
      pipeline.complete(
        record,
        statusCode: err.response?.statusCode,
        headers: _flattenHeaders(err.response?.headers.map ?? const {}),
        body: captured.text,
        bodyBytes: captured.bytes,
        error: _describeError(err),
      );
    }
    handler.next(err);
  }

  Map<String, String> _stringifyHeaders(Map<String, dynamic> headers) => headers
      .map((key, value) => MapEntry(key, value.toString()));

  Map<String, String> _flattenHeaders(Map<String, List<String>> headers) =>
      headers.map((key, value) => MapEntry(key, value.join(', ')));

  String _describeError(DioException err) {
    final message = err.message ?? err.type.name;
    return err.type == DioExceptionType.badResponse
        ? message
        : '${err.type.name}: $message';
  }

  _CapturedBody _encodeBody(dynamic data) {
    if (data == null) return const _CapturedBody();
    if (data is String) return _CapturedBody(text: data);
    if (data is Uint8List) return _CapturedBody(bytes: data);
    if (data is List<int>) return _CapturedBody(bytes: Uint8List.fromList(data));
    if (data is FormData) {
      final buffer = StringBuffer();
      for (final field in data.fields) {
        buffer.writeln('${field.key}=${field.value}');
      }
      for (final file in data.files) {
        buffer.writeln('${file.key}=<file:${file.value.filename ?? '(unnamed)'}>');
      }
      return _CapturedBody(text: buffer.toString().trimRight());
    }
    try {
      return _CapturedBody(text: const JsonEncoder.withIndent('  ').convert(data));
    } catch (_) {
      return _CapturedBody(text: data.toString());
    }
  }
}

class _CapturedBody {
  const _CapturedBody({this.text, this.bytes});

  final String? text;
  final Uint8List? bytes;
}
