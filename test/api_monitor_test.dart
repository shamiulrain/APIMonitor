import 'dart:typed_data';

import 'package:api_monitor/api_monitor.dart';
import 'package:api_monitor/src/utils/curl_builder.dart';
import 'package:api_monitor/src/utils/formatters.dart';
import 'package:dio/dio.dart' hide ResponseType;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

RequestRecord _record({
  int id = 1,
  String method = 'GET',
  String url = 'https://example.com/api/items?page=1',
  Map<String, String>? responseHeaders,
  String? responseBody,
  int? statusCode = 200,
  Uint8List? responseBytes,
}) {
  final record = RequestRecord(
    id: id,
    method: method,
    url: url,
    startTime: DateTime(2024, 1, 1, 12, 0, 0),
  );
  record.responseHeaders = responseHeaders ?? const {};
  record.responseBody = responseBody;
  record.responseBodyBytes = responseBytes;
  record.statusCode = statusCode;
  record.endTime = record.startTime.add(const Duration(milliseconds: 120));
  record.status = statusCode != null && statusCode >= 400
      ? RequestStatus.error
      : RequestStatus.success;
  return record;
}

void main() {
  group('ResponseType.detect', () {
    test('detects from content type', () {
      expect(
        ResponseType.detect(contentType: 'application/json'),
        ResponseType.json,
      );
      expect(
        ResponseType.detect(contentType: 'text/html; charset=utf-8'),
        ResponseType.html,
      );
      expect(
        ResponseType.detect(contentType: 'application/xml'),
        ResponseType.xml,
      );
      expect(
        ResponseType.detect(contentType: 'image/png'),
        ResponseType.image,
      );
      expect(
        ResponseType.detect(contentType: 'text/plain'),
        ResponseType.text,
      );
    });

    test('sniffs the body when the header is missing', () {
      expect(ResponseType.detect(body: '{"a":1}'), ResponseType.json);
      expect(ResponseType.detect(body: '[1,2,3]'), ResponseType.json);
      expect(
        ResponseType.detect(body: '<?xml version="1.0"?>'),
        ResponseType.xml,
      );
      expect(
        ResponseType.detect(body: '<!DOCTYPE html><html></html>'),
        ResponseType.html,
      );
    });
  });

  group('formatters', () {
    test('formatBytes', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2.0 KB');
      expect(formatBytes(3 * 1024 * 1024), '3.0 MB');
    });

    test('formatDuration', () {
      expect(formatDuration(const Duration(milliseconds: 500)), '500 ms');
      expect(formatDuration(const Duration(seconds: 2)), '2.00 s');
    });

    test('prettyJson', () {
      expect(prettyJson('{"a":1}'), contains('"a": 1'));
      expect(prettyJson('not json'), 'not json');
    });

    test('truncate', () {
      expect(truncate('abcdef', 3), contains('truncated'));
      expect(truncate('abc', 10), 'abc');
    });
  });

  group('RequestRecord', () {
    test('computes derived values', () {
      final record = _record(
        responseHeaders: {'content-type': 'application/json'},
        responseBody: '{"ok":true}',
      );
      expect(record.host, 'example.com');
      expect(record.pathWithQuery, '/api/items?page=1');
      expect(record.responseType, ResponseType.json);
      expect(record.isSuccess, isTrue);
      expect(record.responseSizeBytes, greaterThan(0));
    });
  });

  group('buildCurl', () {
    test('renders method, headers and body', () {
      final record = _record(method: 'POST');
      record.requestHeaders = {'content-type': 'application/json'};
      record.requestBody = '{"a":1}';
      final curl = buildCurl(record);
      expect(curl, contains('curl -X POST'));
      expect(curl, contains("-H 'content-type: application/json'"));
      expect(curl, contains('--data-raw'));
      expect(curl, contains('https://example.com/api/items?page=1'));
    });
  });

  group('RecordStore', () {
    test('adds newest first and evicts beyond maxRecords', () {
      final store = RecordStore()..maxRecords = 2;
      store.add(_record(id: 1, url: 'https://a.com/1'));
      store.add(_record(id: 2, url: 'https://a.com/2'));
      store.add(_record(id: 3, url: 'https://a.com/3'));
      expect(store.length, 2);
      expect(store.records.first.url, 'https://a.com/3');
    });

    test('query filters by text and type', () {
      final store = RecordStore();
      store.add(_record(
        id: 1,
        url: 'https://api.github.com/user',
        responseHeaders: {'content-type': 'application/json'},
        responseBody: '{"login":"x"}',
      ));
      store.add(_record(
        id: 2,
        url: 'https://cdn.example.com/logo.png',
        responseHeaders: {'content-type': 'image/png'},
      ));
      expect(store.query(search: 'github').length, 1);
      expect(store.query(types: {ResponseType.image}).length, 1);
      expect(
        store.query(types: {ResponseType.json, ResponseType.image}).length,
        2,
      );
    });

    test('computes statistics', () {
      final store = RecordStore();
      store.add(_record(id: 1, statusCode: 200));
      store.add(_record(id: 2, statusCode: 500));
      final stats = store.computeStats();
      expect(stats.total, 2);
      expect(stats.success, 1);
      expect(stats.failed, 1);
      expect(stats.averageDuration.inMilliseconds, 120);
    });
  });

  group('integrations', () {
    setUp(() {
      ApiMonitor.instance.clear();
      ApiMonitor.instance.clearIgnoredURLs();
      ApiMonitor.instance.enable();
    });

    test('package:http client captures request and response', () async {
      final client = ApiMonitor.instance.createHttpClient(
        inner: MockClient((request) async => http.Response(
              '{"ok":true}',
              201,
              headers: {'content-type': 'application/json'},
            )),
      );

      final response =
          await client.get(Uri.parse('https://example.com/ping?x=1'));
      expect(response.statusCode, 201);

      final record = ApiMonitor.instance.store.records.single;
      expect(record.method, 'GET');
      expect(record.statusCode, 201);
      expect(record.source, CaptureSource.http);
      expect(record.responseBody, contains('ok'));
      expect(record.isSuccess, isTrue);
    });

    test('dio interceptor captures request and response', () async {
      final dio = Dio()..httpClientAdapter = _FakeAdapter();
      dio.interceptors.add(ApiMonitor.instance.dioInterceptor);

      final response = await dio.get<dynamic>('https://example.com/thing');
      expect(response.statusCode, 200);

      final record = ApiMonitor.instance.store.records.single;
      expect(record.method, 'GET');
      expect(record.source, CaptureSource.dio);
      expect(record.statusCode, 200);
      expect(record.responseBody, contains('ok'));
    });

    test('ignored URLs are not captured', () async {
      ApiMonitor.instance.ignoreURL('https://ignored.com');
      final client = ApiMonitor.instance.createHttpClient(
        inner: MockClient((request) async => http.Response('nope', 200)),
      );
      await client.get(Uri.parse('https://ignored.com/secret'));
      expect(ApiMonitor.instance.store.records, isEmpty);

      await client.get(Uri.parse('https://kept.com/visible'));
      expect(ApiMonitor.instance.store.records.length, 1);
    });
  });
}

class _FakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
