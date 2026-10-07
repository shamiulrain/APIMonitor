/// APIMonitor — a Netfox-style in-app network inspector for Flutter.
///
/// Start capturing, wrap your app with [ApiMonitorOverlay], and shake (or tap
/// the bubble) to inspect every request your app makes.
library;

export 'src/capture/api_monitor_dio_interceptor.dart';
export 'src/capture/api_monitor_http_client.dart';
export 'src/core/api_monitor.dart';
export 'src/core/capture_source.dart';
export 'src/core/record_store.dart';
export 'src/core/request_record.dart';
export 'src/core/request_status.dart';
export 'src/core/response_type.dart';
export 'src/ui/api_monitor_overlay.dart';
export 'src/ui/api_monitor_theme.dart';
export 'src/ui/inspector_page.dart';
export 'src/ui/request_detail_screen.dart';
export 'src/ui/request_list_screen.dart';
export 'src/version.dart';
