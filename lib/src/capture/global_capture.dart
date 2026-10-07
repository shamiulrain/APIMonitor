import 'dart:async';
import 'dart:convert' show Encoding;
import 'dart:io';
import 'dart:typed_data';

import '../core/api_monitor.dart';
import '../core/header_utils.dart';
import '../core/request_record.dart';
import 'capture_pipeline.dart';

/// Process-wide `HttpOverrides` installed by [ApiMonitor.start].
///
/// Every `HttpClient` created while installed is wrapped so requests and
/// responses can be recorded. This is what lets the SDK capture traffic from
/// `package:http`, Dio's default adapter, `Image.network` and any other library
/// built on `dart:io` without per-client wiring.
class MonitorHttpOverrides extends HttpOverrides {
  MonitorHttpOverrides(this.monitor, this.previous);

  final ApiMonitor monitor;
  final HttpOverrides? previous;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MonitoredHttpClient(_createInner(context), monitor.pipeline);
  }

  HttpClient _createInner(SecurityContext? context) {
    final saved = HttpOverrides.current;
    HttpOverrides.global = previous;
    try {
      if (previous != null) return previous!.createHttpClient(context);
      return HttpClient(context: context);
    } finally {
      HttpOverrides.global = saved ?? this;
    }
  }
}

/// A transparent [HttpClient] proxy that records every request it opens.
class MonitoredHttpClient implements HttpClient {
  MonitoredHttpClient(this._inner, this._pipeline);

  final HttpClient _inner;
  final CapturePipeline _pipeline;

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) =>
      _inner.authenticate = f;

  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)?
        f,
  ) =>
      _inner.authenticateProxy = f;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) =>
      _inner.badCertificateCallback = callback;

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )?
        f,
  ) =>
      _inner.connectionFactory = f;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = await _inner.openUrl(method, url);
    return MonitoredHttpClientRequest(request, _pipeline);
  }

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) =>
      openUrl(method, _hostUri(host, port, path));

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      openUrl('get', _hostUri(host, port, path));

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('get', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      openUrl('post', _hostUri(host, port, path));

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('post', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      openUrl('put', _hostUri(host, port, path));

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('put', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      openUrl('patch', _hostUri(host, port, path));

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('patch', url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      openUrl('delete', _hostUri(host, port, path));

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('delete', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      openUrl('head', _hostUri(host, port, path));

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('head', url);

  @override
  void close({bool force = false}) => _inner.close(force: force);

  /// Mirrors `_HttpClient.open`'s path/query handling so convenience methods
  /// produce the same URI as the underlying implementation.
  static Uri _hostUri(String host, int port, String path) {
    const int hashMark = 0x23;
    const int questionMark = 0x3f;
    var fragmentStart = path.length;
    var queryStart = path.length;
    for (var i = path.length - 1; i >= 0; i--) {
      final char = path.codeUnitAt(i);
      if (char == hashMark) {
        fragmentStart = i;
        queryStart = i;
      } else if (char == questionMark) {
        queryStart = i;
      }
    }
    String? query;
    if (queryStart < fragmentStart) {
      query = path.substring(queryStart + 1, fragmentStart);
      path = path.substring(0, queryStart);
    }
    return Uri(scheme: 'http', host: host, port: port, path: path, query: query);
  }
}

/// Wraps an [HttpClientRequest] to buffer the request body and start a record
/// when the request is sent.
class MonitoredHttpClientRequest implements HttpClientRequest {
  MonitoredHttpClientRequest(this._inner, this._pipeline);

  final HttpClientRequest _inner;
  final CapturePipeline _pipeline;

  final BytesBuilder _buffer = BytesBuilder(copy: false);
  RequestRecord? _record;
  Future<HttpClientResponse>? _responseFuture;
  bool _recordCreated = false;

  // --- properties ---------------------------------------------------------

  @override
  String get method => _inner.method;

  @override
  Uri get uri => _inner.uri;

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  bool get persistentConnection => _inner.persistentConnection;
  @override
  set persistentConnection(bool value) =>
      _inner.persistentConnection = value;

  @override
  bool get followRedirects => _inner.followRedirects;
  @override
  set followRedirects(bool value) => _inner.followRedirects = value;

  @override
  int get maxRedirects => _inner.maxRedirects;
  @override
  set maxRedirects(int value) => _inner.maxRedirects = value;

  @override
  int get contentLength => _inner.contentLength;
  @override
  set contentLength(int value) => _inner.contentLength = value;

  @override
  bool get bufferOutput => _inner.bufferOutput;
  @override
  set bufferOutput(bool value) => _inner.bufferOutput = value;

  // --- IOSink -------------------------------------------------------------

  @override
  Encoding get encoding => _inner.encoding;
  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  void add(List<int> data) {
    _capture(data);
    _inner.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => _inner.addStream(
        stream.map((chunk) {
          _capture(chunk);
          return chunk;
        }),
      );

  @override
  Future<void> flush() => _inner.flush();

  @override
  void write(Object? object) {
    _capture(_inner.encoding.encode('$object'));
    _inner.write(object);
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    _capture(_inner.encoding.encode(objects.join(separator)));
    _inner.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    _capture(_inner.encoding.encode(String.fromCharCode(charCode)));
    _inner.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = '']) {
    _capture(_inner.encoding.encode('$object\n'));
    _inner.writeln(object);
  }

  // --- lifecycle ----------------------------------------------------------

  @override
  Future<HttpClientResponse> close() => _responseFuture ??= _doClose();

  Future<HttpClientResponse> _doClose() async {
    final record = _beginRecord();
    try {
      final response = await _inner.close();
      return MonitoredHttpClientResponse(response, _pipeline, record);
    } catch (error) {
      if (record != null) {
        _pipeline.complete(record, error: error.toString());
      }
      rethrow;
    }
  }

  @override
  Future<HttpClientResponse> get done {
    final existing = _responseFuture;
    if (existing != null) return existing;
    return _inner.done.then(
      (response) => MonitoredHttpClientResponse(
        response,
        _pipeline,
        _beginRecord(),
      ),
    );
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) =>
      _inner.abort(exception, stackTrace);

  RequestRecord? _beginRecord() {
    if (_recordCreated) return _record;
    _recordCreated = true;
    final bytes = _buffer.isEmpty ? null : _buffer.takeBytes();
    _record = _pipeline.beginFromOverrides(
      method: method,
      url: uri,
      headers: flattenHttpHeaders(_inner.headers),
      bodyBytes: bytes,
    );
    return _record;
  }

  void _capture(List<int> data) {
    if (_buffer.length >= _pipeline.maxCapturedBytes) return;
    _buffer.add(data);
  }
}

/// Wraps an [HttpClientResponse] to buffer the response body and complete the
/// associated record once the stream finishes.
///
/// Extends [Stream] so the many `Stream` helpers keep their default behaviour
/// while only [listen] needs to be overridden to tee the bytes.
class MonitoredHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  MonitoredHttpClientResponse(this._inner, this._pipeline, this._record);

  final HttpClientResponse _inner;
  final CapturePipeline _pipeline;
  final RequestRecord? _record;

  final BytesBuilder _buffer = BytesBuilder(copy: false);
  bool _completed = false;

  @override
  int get statusCode => _inner.statusCode;

  @override
  String get reasonPhrase => _inner.reasonPhrase;

  @override
  int get contentLength => _inner.contentLength;

  @override
  HttpClientResponseCompressionState get compressionState =>
      _inner.compressionState;

  @override
  bool get persistentConnection => _inner.persistentConnection;

  @override
  bool get isRedirect => _inner.isRedirect;

  @override
  List<RedirectInfo> get redirects => _inner.redirects;

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  X509Certificate? get certificate => _inner.certificate;

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) =>
      _inner.redirect(method, url, followLoops);

  @override
  Future<Socket> detachSocket() => _inner.detachSocket();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _inner.listen(
      (data) {
        _capture(data);
        onData?.call(data);
      },
      onError: (Object error, StackTrace stackTrace) {
        _completeWithError(error);
        if (onError is void Function(Object, StackTrace)) {
          onError(error, stackTrace);
        } else if (onError is void Function(Object)) {
          onError(error);
        }
      },
      onDone: () {
        _completeSuccessfully();
        onDone?.call();
      },
      cancelOnError: cancelOnError,
    );
  }

  void _capture(List<int> data) {
    if (_buffer.length >= _pipeline.maxCapturedBytes) return;
    _buffer.add(data);
  }

  void _completeSuccessfully() {
    if (_completed) return;
    _completed = true;
    final record = _record;
    if (record == null) return;
    _pipeline.complete(
      record,
      statusCode: _inner.statusCode,
      headers: flattenHttpHeaders(_inner.headers),
      bodyBytes: _buffer.takeBytes(),
    );
  }

  void _completeWithError(Object error) {
    if (_completed) return;
    _completed = true;
    final record = _record;
    if (record == null) return;
    _pipeline.complete(
      record,
      statusCode: _inner.statusCode,
      headers: flattenHttpHeaders(_inner.headers),
      error: error.toString(),
    );
  }
}
