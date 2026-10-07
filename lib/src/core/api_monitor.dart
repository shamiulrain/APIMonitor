import 'dart:io' show HttpOverrides;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../capture/api_monitor_dio_interceptor.dart';
import '../capture/api_monitor_http_client.dart';
import '../capture/capture_pipeline.dart';
import '../capture/global_capture.dart';
import '../ui/api_monitor_theme.dart';
import '../ui/inspector_host.dart';
import '../ui/inspector_page.dart';
import 'record_store.dart';
import 'request_record.dart';

/// Entry point of the SDK. A single process-wide instance lives at
/// [ApiMonitor.instance].
///
/// ```dart
/// void main() {
///   ApiMonitor.instance.start();
///   runApp(const MyApp());
/// }
/// ```
class ApiMonitor {
  ApiMonitor._() {
    _pipeline = CapturePipeline(this);
  }

  /// The shared instance.
  static final ApiMonitor instance = ApiMonitor._();

  /// Holds every captured call.
  final RecordStore store = RecordStore();

  /// Notifies the overlay whether the inspector should be visible.
  final ValueNotifier<bool> isOpen = ValueNotifier<bool>(false);

  /// Assign to `MaterialApp.navigatorKey` to let [show] open the inspector even
  /// when [ApiMonitorOverlay] is not installed.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  late final CapturePipeline _pipeline;

  /// The capture pipeline shared by every integration.
  CapturePipeline get pipeline => _pipeline;

  /// Active colour palette.
  ApiMonitorTheme theme = const ApiMonitorTheme.light();

  final Set<String> _ignoredUrls = <String>{};
  HttpOverrides? _previousOverrides;
  InspectorHost? _host;
  bool _started = false;
  bool _globalCapture = false;
  bool _shakeToOpen = true;
  bool _showFloatingButton = true;
  bool _logToConsole = false;
  bool _enabled = true;
  void Function(String message)? _logger;
  void Function(RequestRecord record)? onRecord;

  bool get isStarted => _started;
  bool get isEnabled => _enabled;
  bool get isCaptureEnabled => _enabled;
  bool get isGlobalCaptureEnabled => _globalCapture;
  bool get shakeToOpen => _shakeToOpen;
  bool get showFloatingButton => _showFloatingButton;
  Set<String> get ignoredUrls => Set.unmodifiable(_ignoredUrls);

  /// Whether a request for [url] should currently be captured.
  bool shouldCapture(String url) {
    if (!_enabled) return false;
    return !_isIgnored(url);
  }

  /// Starts capturing. Call once during app startup (usually `main`).
  ///
  /// [globalCapture] installs a process-wide `HttpOverrides` that records every
  /// request made through `dart:io` — including `package:http`, Dio's default
  /// adapter and `Image.network`. Turn it off if you prefer explicit
  /// integrations only.
  void start({
    bool globalCapture = true,
    bool shakeToOpen = true,
    bool showFloatingButton = true,
    bool logToConsole = false,
    ApiMonitorTheme? theme,
  }) {
    _shakeToOpen = shakeToOpen;
    _showFloatingButton = showFloatingButton;
    _logToConsole = logToConsole;
    if (theme != null) this.theme = theme;
    if (globalCapture) _installGlobalCapture();
    _started = true;
    _log('ApiMonitor started '
        '(globalCapture: $globalCapture, shakeToOpen: $shakeToOpen)');
  }

  /// Stops capturing. Restores the previous `HttpOverrides` and, when [clear]
  /// is true (the default), wipes all saved data — matching Netfox's `stop()`.
  void stop({bool clear = true}) {
    if (_globalCapture) {
      HttpOverrides.global = _previousOverrides;
      _globalCapture = false;
    }
    isOpen.value = false;
    _started = false;
    if (clear) store.clear();
    _log('ApiMonitor stopped');
  }

  /// Enables / disables capturing without tearing down the interceptor.
  void setEnabled(bool value) {
    _enabled = value;
    store.enabled = value;
    _log('ApiMonitor ${value ? 'enabled' : 'disabled'}');
  }

  void enable() => setEnabled(true);

  void disable() => setEnabled(false);

  /// Removes every captured record.
  void clear() {
    store.clear();
    _log('ApiMonitor cleared');
  }

  /// Prevents requests whose URL matches [url] from being logged.
  ///
  /// Pass a host (e.g. `https://analytics.example.com`) to ignore every path on
  /// it, or a full URL to ignore a single endpoint.
  void ignoreURL(String url) => _ignoredUrls.add(url);

  void unignoreURL(String url) => _ignoredUrls.remove(url);

  void clearIgnoredURLs() => _ignoredUrls.clear();

  /// Maximum number of records kept in memory.
  set maxRecords(int value) => store.maxRecords = value;

  /// Records longer than this are truncated when stored.
  set maxBodyLength(int value) => store.maxBodyLength = value;

  /// Whether request/response bodies should be captured.
  set captureBodies(bool value) => store.captureBodies = value;

  /// Custom log sink (defaults to [debugPrint] when `logToConsole` is on).
  set logger(void Function(String message)? value) => _logger = value;

  /// Shows the inspector. Prefers the installed `ApiMonitorOverlay`; otherwise
  /// falls back to pushing a route on [navigatorKey] / [context].
  void show({BuildContext? context}) {
    final host = _host;
    if (host != null) {
      host.open();
      return;
    }
    final navigator =
        context != null ? Navigator.maybeOf(context) : navigatorKey.currentState;
    if (navigator != null) {
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const ApiMonitorInspectorPage()),
      );
      _log('ApiMonitor opened via navigator (no overlay installed)');
      return;
    }
    _log('ApiMonitor.show() called but no ApiMonitorOverlay is installed and '
        'no navigator is available. Wrap your app with ApiMonitorOverlay.');
  }

  /// Hides the inspector.
  void hide() {
    final host = _host;
    if (host != null) {
      host.close();
      return;
    }
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    } else {
      isOpen.value = false;
    }
  }

  /// Opens the inspector when hidden, hides it when open.
  void toggle() {
    final host = _host;
    if (host != null) {
      host.toggle();
    } else {
      isOpen.value = !isOpen.value;
    }
  }

  // --- Integrations -------------------------------------------------------

  /// A Dio interceptor that captures dio requests/responses.
  ///
  /// ```dart
  /// dio.interceptors.add(ApiMonitor.instance.dioInterceptor);
  /// ```
  Interceptor get dioInterceptor => ApiMonitorDioInterceptor(_pipeline);

  /// Adds [dioInterceptor] to [dio] and returns it for chaining.
  Dio attachDio(Dio dio) {
    dio.interceptors.add(dioInterceptor);
    return dio;
  }

  /// A `package:http` client that captures requests/responses.
  ///
  /// ```dart
  /// final client = ApiMonitor.instance.createHttpClient();
  /// ```
  ApiMonitorHttpClient createHttpClient({http.Client? inner}) =>
      ApiMonitorHttpClient(pipeline: _pipeline, inner: inner);

  // --- Overlay plumbing (internal) ----------------------------------------

  void registerHost(InspectorHost host) => _host = host;

  void unregisterHost(InspectorHost host) {
    if (identical(_host, host)) _host = null;
  }

  void _installGlobalCapture() {
    if (_globalCapture) return;
    _previousOverrides = HttpOverrides.current;
    HttpOverrides.global = MonitorHttpOverrides(this, _previousOverrides);
    _globalCapture = true;
  }

  bool _isIgnored(String url) {
    if (_ignoredUrls.isEmpty) return false;
    for (final pattern in _ignoredUrls) {
      if (url == pattern || url.startsWith(pattern)) return true;
      final host = Uri.tryParse(url)?.host ?? '';
      final patternHost =
          pattern.contains('://') ? (Uri.tryParse(pattern)?.host ?? pattern) : pattern;
      if (patternHost.isNotEmpty &&
          (host == patternHost || host.endsWith('.$patternHost'))) {
        return true;
      }
    }
    return false;
  }

  void log(String message) => _log(message);

  void _log(String message) {
    final logger = _logger;
    if (logger != null) {
      logger(message);
    } else if (_logToConsole) {
      debugPrint('[ApiMonitor] $message');
    }
  }

  void notifyRecord(RequestRecord record) => onRecord?.call(record);
}
